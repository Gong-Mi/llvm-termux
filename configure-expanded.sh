#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_ROOT="/data/data/com.termux/files/home/llvm-termux"
BUILD_DIR="$PROJECT_ROOT/build-expanded-fallback"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
ANDROID_TRIPLE="aarch64-unknown-linux-android24"

# CPU & OS flags (no _LIBCPP_ABI_NAMESPACE — now set via __config_site as __ndk1)
CPU_FLAGS="-fPIC -march=armv9-a+sve2+bf16+i8mm --target=$ANDROID_TRIPLE --sysroot=/data/data/com.termux/files -stdlib=libc++ -D_LIBCPP_DISABLE_AVAILABILITY -D_LIBCPP_NO_ABI_TAG -D_LIBCPP_ABI_NAMESPACE=__ndk1 -D_GNU_SOURCE -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -O3 -I$BUILD_DIR/include-fix -I$TERMUX_PREFIX/include -I$TERMUX_PREFIX/include/aarch64-linux-android"

# Linker flags — 64K page alignment + system rpath only (build rpath handled by cmake BUILD_RPATH)
LINKER_FLAGS="-Wl,-z,max-page-size=65536 -Wl,-z,common-page-size=65536 -Wl,-z,separate-loadable-segments -L$TERMUX_PREFIX/lib -Wl,-rpath,$TERMUX_PREFIX/lib /data/data/com.termux/files/home/tmp/20260613/libhash_stub.a"
BUILD_RPATH="$TERMUX_PREFIX/lib"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ">>> Configuring LLVM 23 (expanded targets, CLANG_LINK_CLANG_DYLIB=ON)..."

cmake -G Ninja \
    -DCMAKE_C_COMPILER="$TERMUX_PREFIX/bin/clang" \
    -DCMAKE_CXX_COMPILER="$TERMUX_PREFIX/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$TERMUX_PREFIX/bin/clang" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$TERMUX_PREFIX" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DLLVM_ENABLE_PIC=ON \
    -DCMAKE_SYSROOT="/data/data/com.termux/files" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF \
    -DCMAKE_BUILD_RPATH="$BUILD_RPATH" \
    -DCMAKE_INSTALL_RPATH="$TERMUX_PREFIX/lib" \
    -DLLVM_HOST_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;AMDGPU;ARM;AVR;BPF;Hexagon;Lanai;LoongArch;MSP430;Mips;NVPTX;PowerPC;RISCV;SPIRV;Sparc;SystemZ;VE;WebAssembly;X86;XCore" \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld" \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind;openmp" \
    -DLLVM_RUNTIME_TARGETS="$ANDROID_TRIPLE" \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DCLANG_LINK_CLANG_DYLIB=ON \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_ENABLE_RTTI=OFF \
    -DLLVM_ENABLE_EH=OFF \
    -DLLVM_INSTALL_UTILS=ON \
    -DCLANG_DEFAULT_LINKER="lld" \
    -DCLANG_DEFAULT_RTLIB="compiler-rt" \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DDEFAULT_SYSROOT="/data/data/com.termux/files" \
    -DCMAKE_C_FLAGS="$CPU_FLAGS" \
    -DCMAKE_CXX_FLAGS="$CPU_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LINKER_FLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LINKER_FLAGS" \
    -DCMAKE_MODULE_LINKER_FLAGS="$LINKER_FLAGS" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_C_FLAGS="$CPU_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_CXX_FLAGS="$CPU_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SYSROOT="/data/data/com.termux/files" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_EXE_LINKER_FLAGS="-L$TERMUX_PREFIX/lib /data/data/com.termux/files/home/tmp/20260613/libhash_stub.a" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SHARED_LINKER_FLAGS="-L$TERMUX_PREFIX/lib /data/data/com.termux/files/home/tmp/20260613/libhash_stub.a" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_REQUIRED_LIBRARIES="-L$TERMUX_PREFIX/lib;-lc++_shared" \
    -DRUNTIMES_${ANDROID_TRIPLE}_COMPILER_RT_INCLUDE_TESTS:BOOL=OFF \
    -DLLVM_PARALLEL_COMPILE_JOBS=8 \
    -DLLVM_PARALLEL_LINK_JOBS=1 \
    "$PROJECT_ROOT/llvm"

echo ">>> Configure done."
echo "Build dir: $BUILD_DIR"
echo "Run: ninja -C $BUILD_DIR -j8"
