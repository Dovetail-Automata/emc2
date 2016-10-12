#!/bin/sh -ex

# Verbose build
if ${MK_BUILD_VERBOSE}; then
    VERBOSE="V=1"
fi

cd ${MACHINEKIT_PATH}/src
./autogen.sh
./configure \
     --with-posix \
     --without-rt-preempt \
     --without-xenomai \
     --without-xenomai-kernel \
     --without-rtai-kernel
make -j${JOBS} ${VERBOSE}

ccache -s

useradd -m -s /bin/bash mk
chown -R mk:mk ../
make setuid ${VERBOSE}
