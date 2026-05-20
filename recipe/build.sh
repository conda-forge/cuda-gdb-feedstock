#!/bin/bash

# Copy of https://github.com/conda-forge/gdb-feedstock/blob/main/recipe/build.sh

# Get an updated config.sub and config.guess
cp "$BUILD_PREFIX"/share/gnuconfig/config.* ./readline/readline/support
cp "$BUILD_PREFIX"/share/gnuconfig/config.* .

set -eux

# Download the right script to debug python processes.
# This is an useful script provided by CPython project to help debugging
# crashes in Python processes.
# See https://devguide.python.org/gdb for some
# examples on how to use it.
#
# Normally someone needs to download this script manually and properly
# setup gdb to load it (if you are lucky gdb was compiled with python
# support).
#
# Providing this in conda-forge's gdb makes the experience much smoother,
# avoiding all the hassles someone can find when trying to configure gdb
# for that.
curl -SL "https://raw.githubusercontent.com/python/cpython/$PY_VER/Tools/gdb/libpython.py" \
    > "$SP_DIR/gdb_libpython.py"

# Install a gdbinit file that will be automatically loaded
mkdir -p "$PREFIX/etc"
echo '
python
import gdb
import sys
import os
def setup_python(event):
    import gdb_libpython
gdb.events.new_objfile.connect(setup_python)
end
' >> "$PREFIX/etc/gdbinit"

export CPPFLAGS="$CPPFLAGS -I$PREFIX/include -I${SRC_DIR}/include"
export CXXFLAGS="${CXXFLAGS} -std=gnu++17"

# Setting /usr/lib/debug as debug dir makes it possible to debug the system's
# python on most Linux distributions

mkdir build
cd build

# --with-gdb-datadir is given to not conflict with gdb conda package
#
# --enable-targets=m68k-linux-gnu is required: cuda-gdb re-uses bfd_arch_m68k as the CUDA
# architecture (see gdb/arch-utils.c around the NVIDIA_CUDA_GDB block), so libbfd must
# include m68k cpu support or cuda-gdb aborts at startup with "Attempt to register unknown
# architecture (2)". As of June 2026, only x86 and ARM platforms are supported host
# platforms for CUDA, so we don't need to build for others.
#
# shellcheck disable=SC2016  # $debugdir/$datadir are literal gdb runtime tokens
"$SRC_DIR"/configure \
    --build="$BUILD" --host="$HOST" --target="$HOST" \
    --disable-binutils \
    --disable-gas \
    --disable-gold \
    --disable-gprof \
    --disable-gprofng \
    --disable-ld \
    --disable-nls \
    --disable-sim \
    --disable-source-highlight \
    --disable-werror \
    --enable-cuda \
    --enable-targets="x86_64-linux-gnu,aarch64-linux-gnu,m68k-linux-gnu" \
    --enable-tui \
    --prefix="$PREFIX" \
    --program-prefix="cuda-" \
    --with-auto-load-dir='$debugdir:$datadir/auto-load:/usr/share/gdb/auto-load' \
    --with-curses \
    --with-expat=yes \
    --with-gdb-datadir="$PREFIX/share/cuda-gdb" \
    --with-gmp="$PREFIX" \
    --with-libiconv-prefix="$PREFIX" \
    --with-lzma --with-liblzma-prefix="$PREFIX" \
    --with-mpfr="$PREFIX" \
    --with-pkgversion="conda-forge cuda-gdb" \
    --with-python="$PYTHON" \
    --with-separate-debug-dir="$PREFIX/lib/debug:/usr/lib/debug" \
    --with-system-readline \
    --with-system-gdbinit="$PREFIX/etc/gdbinit" \
    --with-system-zlib \
    --with-zstd=yes \
    --without-guile \
    || (cat config.log && exit 1)

make -j"${CPU_COUNT}" VERBOSE=1
make install install-gdbserver
