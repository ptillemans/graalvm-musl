FROM ghcr.io/graalvm/graalvm-ce:21.3.0
RUN gu install native-image
RUN curl --output musl.tar.gz https://musl.libc.org/releases/musl-1.2.2.tar.gz
RUN tar -xzvf musl.tar.gz
RUN cd musl-1.2.2 && ./configure && make && make install
RUN cd ..
RUN curl --output zlib.tar.gz https://zlib.net/zlib-1.2.11.tar.gz
RUN tar -xzvf zlib.tar.gz
RUN cd zlib-1.2.11 && ./configure && make && make install
RUN cd ..
RUN cp /usr/lib/gcc/x86_64-redhat-linux/8/libstdc++.a /usr/local/musl/lib
RUN cp zlib-1.2.11/libz.a /usr/local/musl/lib/
RUN ln -s /usr/local/musl/bin/musl-gcc /usr/local/bin/x86_64-linux-musl-gcc
FROM ghcr.io/graalvm/graalvm-ce:21.3.0
COPY --from=0 /usr/local/musl /usr/local
RUN microdnf install maven

