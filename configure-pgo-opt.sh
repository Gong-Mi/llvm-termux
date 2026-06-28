#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_ROOT="/data/data/com.termux/files/home/llvm-termux"
BUILD="$PROJECT_ROOT/build-pgo-opt"
PREFIX="/data/data/com.termux/files/usr"
ANDROID_TRIPLE="aarch64-unknown-linux-android24"
PROFDATA="$PROJECT_ROOT/pgo-training/merged.profdata"

rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"

export CCACHE_MAXSIZE=30G
export CCACHE_DIR="$PROJECT_ROOT/.ccache"

C_FLAGS="-fPIC -march=armv9-a+sve2p1+bf16+i8mm \
  --target=$ANDROID_TRIPLE \
  --sysroot=$PREFIX \
  -D_LIBCPP_DISABLE_AVAILABILITY \
  -D_GNU_SOURCE \
  -O3 \
  -I$PREFIX/include \
  -I$PREFIX/include/aarch64-linux-android"

CXX_FLAGS="$C_FLAGS -stdlib=libc++ -Wno-unused-command-line-argument"

LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -L$PREFIX/lib"

cmake -G Ninja \
  -DCMAKE_C_COMPILER="$PREFIX/bin/clang-23" \
  -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++" \
  -DCMAKE_C_FLAGS="$C_FLAGS" \
  -DCMAKE_CXX_FLAGS="$CXX_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$LINKER_FLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="$LINKER_FLAGS" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="$ANDROID_TRIPLE" \
  -DLLVM_HOST_TRIPLE="$ANDROID_TRIPLE" \
  -DLLVM_ENABLE_LIBCXX=ON \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF \
  -DCLANG_DEFAULT_LINKER="lld" \
  -DCLANG_DEFAULT_RTLIB="compiler-rt" \
  -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DCLANG_LINK_CLANG_DYLIB=ON \
  -DLLVM_PARALLEL_LINK_JOBS=2 \
  -DCMAKE_C_COMPILER_LAUNCHER="ccache" \
  -DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
  -DCMAKE_SYSROOT="$PREFIX" \
  -DDEFAULT_SYSROOT="$PREFIX" \
  -DLLVM_ENABLE_SPHINX=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DHAVE_CXX_ATOMICS_WITHOUT_LIB=1 \
  -DHAVE_CXX_ATOMICS64_WITHOUT_LIB=1 \
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
  -DLLVM_PROFDATA_FILE="$PROFDATA" \
  "$PROJECT_ROOT/llvm"

echo "=== PGO Optimized configure done ==="
