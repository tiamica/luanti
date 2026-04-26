# syntax=docker/dockerfile:1
# check=error=true

ARG DOCKER_IMAGE=alpine:3.23
FROM $DOCKER_IMAGE AS dev

ENV LUAJIT_VERSION=v2.1

RUN apk add --no-cache git build-base cmake curl-dev zlib-dev zstd-dev \
		sqlite-dev postgresql-dev hiredis-dev leveldb-dev \
		gmp-dev jsoncpp-dev ninja

WORKDIR /usr/src/

RUN git clone --recurse-submodules --branch master https://github.com/jupp0r/prometheus-cpp.git /usr/src/prometheus-cpp && \
    git clone --recurse-submodules --branch main https://github.com/libspatialindex/libspatialindex.git /usr/src/libspatialindex && \
    git clone --recurse-submodules --branch ${LUAJIT_VERSION} https://luajit.org/git/luajit.git /usr/src/luajit
	
# ADD https://github.com/jupp0r/prometheus-cpp.git?branch=master /usr/src/prometheus-cpp
# ADD https://github.com/libspatialindex/libspatialindex.git?branch=main /usr/src/libsp/atialindex
# ADD --keep-git-dir https://luajit.org/git/luajit.git?branch=${LUAJIT_VERSION} /usr/src/luajit

RUN cd prometheus-cpp && \
		cmake -B build \
			-DCMAKE_INSTALL_PREFIX=/usr/local \
			-DCMAKE_BUILD_TYPE=Release \
			-DENABLE_TESTING=0 \
			-GNinja && \
		cmake --build build && \
		cmake --install build && \
		cd /usr/src/ && \
	cd libspatialindex && \
		cmake -B build \
			-DCMAKE_INSTALL_PREFIX=/usr/local && \
		cmake --build build && \
		cmake --install build && \
		cd /usr/src/ && \
	cd luajit && \
		make amalg && make install && \
	cd /usr/src/

FROM dev AS builder

COPY .git /usr/src/luanti/.git
COPY CMakeLists.txt /usr/src/luanti/CMakeLists.txt
COPY README.md /usr/src/luanti/README.md
COPY minetest.conf.example /usr/src/luanti/minetest.conf.example
COPY builtin /usr/src/luanti/builtin
COPY cmake /usr/src/luanti/cmake
COPY doc /usr/src/luanti/doc
COPY fonts /usr/src/luanti/fonts
COPY lib /usr/src/luanti/lib
COPY misc /usr/src/luanti/misc
COPY po /usr/src/luanti/po
COPY src /usr/src/luanti/src
COPY irr /usr/src/luanti/irr
COPY textures /usr/src/luanti/textures

WORKDIR /usr/src/luanti
RUN cmake -B build \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SERVER=TRUE \
		-DENABLE_PROMETHEUS=TRUE \
		-DBUILD_UNITTESTS=FALSE -DBUILD_BENCHMARKS=FALSE \
		-DBUILD_CLIENT=FALSE \
		-GNinja && \
	cmake --build build && \
	cmake --install build

FROM $DOCKER_IMAGE AS runtime

# 1. This block MUST come first to install curl and create the user
RUN apk add --no-cache curl gmp libstdc++ libgcc libpq jsoncpp zstd-libs \
 sqlite-libs postgresql hiredis leveldb && \
 adduser -D minetest --uid 30000 -h /var/lib/minetest && \
 chown -R minetest:minetest /var/lib/minetest

WORKDIR /var/lib/minetest

# 2. NOW you can download the game because curl and the user exist
RUN mkdir -p /var/lib/minetest/.minetest/games && \
    cd /var/lib/minetest/.minetest/games && \
    curl -sL https://github.com/minetest/minetest_game/archive/master.tar.gz | tar -xz && \
    mv minetest_game-master minetest_game && \
    chown -R minetest:minetest /var/lib/minetest/.minetest

# 3. Then copy in the built server files
COPY --from=builder /usr/local/share/luanti /usr/local/share/luanti
COPY --from=builder /usr/local/bin/luantiserver /usr/local/bin/luantiserver
COPY --from=builder /usr/local/share/doc/luanti/minetest.conf.example /etc/minetest/minetest.conf
COPY --from=builder /usr/local/lib/libspatialindex\* /usr/local/lib/
COPY --from=builder /usr/local/lib/libluajit\* /usr/local/lib/

# 4. Finally, switch to the user and start the server
USER minetest:minetest

EXPOSE 30000/udp 30000/tcp
VOLUME /var/lib/minetest/ /etc/minetest/

ENTRYPOINT ["/usr/local/bin/luantiserver"]
CMD ["--config", "/etc/minetest/minetest.conf"]FROM $DOCKER_IMAGE AS runtime

# 1. This block MUST come first to install curl and create the user
RUN apk add --no-cache curl gmp libstdc++ libgcc libpq jsoncpp zstd-libs \
 sqlite-libs postgresql hiredis leveldb && \
 adduser -D minetest --uid 30000 -h /var/lib/minetest && \
 chown -R minetest:minetest /var/lib/minetest

WORKDIR /var/lib/minetest

# 2. NOW you can download the game because curl and the user exist
RUN mkdir -p /var/lib/minetest/.minetest/games && \
    cd /var/lib/minetest/.minetest/games && \
    curl -sL https://github.com/minetest/minetest_game/archive/master.tar.gz | tar -xz && \
    mv minetest_game-master minetest_game && \
    chown -R minetest:minetest /var/lib/minetest/.minetest

# 3. Then copy in the built server files
COPY --from=builder /usr/local/share/luanti /usr/local/share/luanti
COPY --from=builder /usr/local/bin/luantiserver /usr/local/bin/luantiserver
COPY --from=builder /usr/local/share/doc/luanti/minetest.conf.example /etc/minetest/minetest.conf
COPY --from=builder /usr/local/lib/libspatialindex\* /usr/local/lib/
COPY --from=builder /usr/local/lib/libluajit\* /usr/local/lib/

# 4. Finally, switch to the user and start the server
USER minetest:minetest

EXPOSE 30000/udp 30000/tcp
VOLUME /var/lib/minetest/ /etc/minetest/

ENTRYPOINT ["/usr/local/bin/luantiserver"]
CMD ["--config", "/etc/minetest/minetest.conf"]
