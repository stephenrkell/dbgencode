#!/bin/bash

# Some test cases are regression tests that we run specially;
# others are stress tests, a.k.a. found codebases supporting a "./configure && make" workflow
# that let us set CFLAGS at configure time. gnu-hello and tar are these for now...
# How do we vendor these without bloating our repo?
# One idea is to keep a list of download URLs and sha1sums here
# and grab them on demand.

declare -a urls
declare -a sha1sums
sources=([gnu-hello]="https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz" \
         [tar]="https://ftp.gnu.org/gnu/tar/tar-1.35.tar.gz" )
sha1sums=([gnu-hello]=336b8ae5d6e72383c53ebd0d3e62d41e8266ba8b \
          [tar]=92848830c920cbaa44abc3ab70e02b0ce8f1e212)

make -C .. config.sh && source ../config.sh || exit 1

echo "TOOLSUB: $TOOLSUB" 1>&2
echo "CIL_INSTALL: $CIL_INSTALL" 1>&2
our_cflags="`${TOOLSUB}/cilpp/bin/cilpp-cflags`\
 -save-temps \
 -Wp,-save-temps \
 -Wp,-plugin,${CIL_INSTALL}/cil/liveness.cmxs \
 -Wp,-plugin,`pwd`/../src/dbgencode.cmxs \
 -Wp,-fpass-dbgencode"
echo "our cflags: $our_cflags" 1>&2

cc $our_cflags -o hello hello.c && ./hello && \
for t in ${TESTS:-gnu-hello tar}; do
	({ cd "$t" || \
      { wget -O "$t".tar.gz "${sources[$test]}" && \
        test "$(sha1sum <"$t".tar.gz | tr -cd '[0-9a-f]' )" == ${sha1sums[$test]} && \
        mkdir "$t" && cd "$t" && tar --strip-components=1 -xzf ../"$t".tar.gz; }; } &&  \
    { test -e config.status && make clean || CFLAGS="$our_cflags" ./configure; } && make V=1 || break)
done
