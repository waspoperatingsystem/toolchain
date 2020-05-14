#!/bin/bash
#

set -e

export BINUTILS_VER=2.34
export GCC_VER=10.1.0
export GMP_VER=6.2.0
export MPFR_VER=4.0.2
export MPC_VER=1.1.0
export ISL_VER=0.22.1
export NEWLIB_VER=3.3.0

export BARCH="$1"
export OUT="$2"
export TOPDIR="$PWD"
export SRC="$OUT/src"
export TOOLS="$OUT/tools"
export SYSROOT="$OUT/sysroot"
export JOBS="$(expr $(nproc) + 1)"

[ -z "$BARCH" ] && exit 1
[ -z "$OUT" ] && exit 1

case $BARCH in
	aarch64) export TARGET="aarch64-unknown-wasp" ;;
	ppc64) export TARGET="powerpc64-unknown-wasp" ;;
	x86_64) export TARGET="x86_64-unknown-wasp" ;;
	*) exit 1 ;;
esac

rm -rf "$SRC"
mkdir -p "$SRC" "$TOOLS" "$SYSROOT"

export PATH="$TOOLS/bin:$PATH"

cd "$SRC"
echo "Downloading and unpacking binutils $BINUTILS_VER"
curl -C - -L -O http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VER.tar.xz
bsdtar -xvf binutils-$BINUTILS_VER.tar.xz
cd binutils-$BINUTILS_VER
patch -Np1 -i "$TOPDIR"/binutils-add-support-for-waspOS.patch
mkdir build
cd build
../configure \
	--prefix="$TOOLS" \
	--target=$TARGET \
	--with-sysroot="$SYSROOT" \
	--with-pic \
	--with-system-zlib \
	--enable-64-bit-bfd \
	--enable-gold \
	--enable-ld=default \
	--enable-lto \
	--enable-plugins \
	--enable-relro \
	--enable-tls \
	--disable-multilib \
	--disable-nls \
	--disable-shared \
	--disable-werror
make -j$JOBS MAKEINFO="true" configure-host
make -j$JOBS MAKEINFO="true"
make -j$JOBS MAKEINFO="true" install

cd "$SRC"
echo "Downloading and unpacking gmp $GMP_VER"
curl -C - -L -O https://gmplib.org/download/gmp/gmp-$GMP_VER.tar.xz
bsdtar -xvf gmp-$GMP_VER.tar.xz
echo "Downloading and unpacking mpfr $MPFR_VER"
curl -C - -L -O http://www.mpfr.org/mpfr-$MPFR_VER/mpfr-$MPFR_VER.tar.xz
bsdtar -xvf mpfr-$MPFR_VER.tar.xz
echo "Downloading and unpacking mpc $MPC_VER"
curl -C - -L -O http://ftp.gnu.org/gnu/mpc/mpc-$MPC_VER.tar.gz
bsdtar -xvf mpc-$MPC_VER.tar.gz
echo "Downloading and unpacking isl $ISL_VER"
curl -C - -L -O http://isl.gforge.inria.fr/isl-$ISL_VER.tar.xz
bsdtar -xvf isl-$ISL_VER.tar.xz
echo "Downloading and unpacking gcc $GCC_VER"
curl -C - -L -O http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VER/gcc-$GCC_VER.tar.xz
bsdtar -xvf gcc-$GCC_VER.tar.xz
cd gcc-$GCC_VER
sed -i 's@\./fixinc\.sh@-c true@' gcc/Makefile.in
sed -i '/m64=/s/lib64/lib/' gcc/config/i386/t-linux64
sed -i '/m64=/s/lib64/lib/' gcc/config/aarch64/t-aarch64-linux
sed -i 's/lib64/lib/' gcc/config/rs6000/linux64.h
patch -Np1 -i "$TOPDIR"/gcc-add-support-for-waspOS.patch
patch -Np1 -i "$TOPDIR"/gcc-cet.patch
patch -Np1 -i "$TOPDIR"/gcc-libgcc_eh.patch
mv ../gmp-$GMP_VER gmp
mv ../mpfr-$MPFR_VER mpfr
mv ../mpc-$MPC_VER mpc
mv ../isl-$ISL_VER isl
mkdir build
cd build
AR=ar \
../configure \
	--prefix="$TOOLS" \
	--libdir="$TOOLS/lib" \
	--libexecdir="$TOOLS/lib" \
	--build=$(cc -dumpmachine) \
	--host=$(cc -dumpmachine) \
	--target=$TARGET \
	--with-sysroot="$SYSROOT" \
	--with-isl \
	--with-newlib \
	--with-system-zlib \
	--with-zstd \
	--without-headers \
	--enable-checking=release \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-languages=c,c++,go,lto \
	--enable-lto \
	--enable-threads=posix \
	--enable-tls \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libssp \
	--disable-multilib \
	--disable-nls \
	--disable-shared \
	--disable-symvers \
	--disable-werror
make -j$JOBS all-gcc
make -j1 install-gcc
mkdir -p "$SYSROOT/usr/include"
cp ../gcc/ginclude/stddef.h "$SYSROOT/usr/include"
cp ../gcc/ginclude/stdarg.h "$SYSROOT/usr/include"
cp ../gcc/ginclude/float.h "$SYSROOT/usr/include"

cd "$SRC"
echo "Downloading and unpacking newlib $NEWLIB_VER"
curl -C - -L -O http://sourceware.org/pub/newlib/newlib-$NEWLIB_VER.tar.gz
bsdtar -xvf newlib-$NEWLIB_VER.tar.gz
cd newlib-$NEWLIB_VER
patch -Np1 -i "$TOPDIR"/newlib-add-support-for-waspOS.patch
mkdir build
cd build
../configure \
	--prefix=/usr \
	--target=$TARGET \
	--enable-lto \
	--enable-newlib-hw-fp \
	--enable-newlib-io-c99-formats \
	--enable-newlib-multithread \
	--disable-multilib \
	--disable-shared
make -j$JOBS all-target-newlib
make -j$JOBS DESTDIR="$SYSROOT" install-target-newlib

cd "$SRC"
echo "Recompiling gcc"
cd gcc-$GCC_VER
rm -rvf build
mkdir build
cd build
AR=ar \
../configure \
	--prefix="$TOOLS" \
	--libdir="$TOOLS/lib" \
	--libexecdir="$TOOLS/lib" \
	--build=$(cc -dumpmachine) \
	--host=$(cc -dumpmachine) \
	--target=$TARGET \
	--with-sysroot="$SYSROOT" \
	--with-isl \
	--with-newlib \
	--with-system-zlib \
	--with-zstd \
	--enable-checking=release \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-languages=c,c++,go,lto \
	--enable-lto \
	--enable-threads=posix \
	--enable-tls \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libssp \
	--disable-multilib \
	--disable-nls \
	--disable-shared \
	--disable-symvers \
	--disable-werror
make -j$JOBS
make -j1 install
