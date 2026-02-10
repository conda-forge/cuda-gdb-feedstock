#!/bin/bash

# Copy of https://github.com/conda-forge/gdb-feedstock/blob/main/recipe/build.sh

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./readline/readline/support
cp $BUILD_PREFIX/share/gnuconfig/config.* .

set -eux

export CPPFLAGS="$CPPFLAGS -I$PREFIX/include -I$SRC_DIR/binary/extras/Debugger/include/"
export CXXFLAGS="${CXXFLAGS} -std=gnu++17"

# Setting /usr/lib/debug as debug dir makes it possible to debug the system's
# python on most Linux distributions

mkdir build
cd build

# --with-gdb-datadir is given to not conflict with gdb conda package
$SRC_DIR/configure \
    --prefix="$PREFIX" \
    --with-separate-debug-dir="$PREFIX/lib/debug:/usr/lib/debug" \
    --with-python=${PYTHON} \
    --with-system-gdbinit="$PREFIX/etc/gdbinit" \
    --with-system-zlib \
    --with-zstd=yes \
    --with-libiconv-prefix=$PREFIX \
    --program-prefix="cuda-" \
    --with-gdb-datadir="$PREFIX/share/cuda-gdb" \
    --enable-cuda \
    || (cat config.log && exit 1)

make -j${CPU_COUNT} VERBOSE=1
make install install-gdbserver

# remove bfd includes and static libraries as they are statically linked in
cd $PREFIX
rm -rf include
rm -rf lib/lib*.a
rm -rf $CONDA_TOOLCHAIN_HOST/bin
rm -rf $CONDA_TOOLCHAIN_HOST/lib
rm -rf share/locale
rm -rf share/info
rm -rf etc/gprofng.rc
rm -rf lib/bfd-plugins
rm -rf lib/gprofng
rm -rf lib/libinproctrace*
