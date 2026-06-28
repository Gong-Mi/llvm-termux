#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_ROOT="/data/data/com.termux/files/home/llvm-termux"
BUILD_DIR="$PROJECT_ROOT/build-expanded-fallback"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
ANDROID_TRIPLE="aarch64-unknown-linux-android24"

# CPU flags — C only, no -stdlib=libc++
C_FLAGS="-fPIC -march=armv9-a+sve2p1+bf16+i8mm --target=$ANDROID_TRIPLE --sysroot=/data/data/com.termux/files -D_LIBCPP_DISABLE_AVAILABILITY -D_LIBCPP_NO_ABI_TAG -D_GNU_SOURCE -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -O3 -I$BUILD_DIR/include-fix -I$TERMUX_PREFIX/include -I$TERMUX_PREFIX/include/aarch64-linux-android"
CXX_FLAGS="$C_FLAGS -stdlib=libc++ -Wno-unused-command-line-argument"

# Linker flags — NO -lc++_shared. LLVM links its own libc++ from runtimes.
LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 -L$TERMUX_PREFIX/lib"

# Build RPATH: build/lib first (for in-build private libc++), then system
BUILD_RPATH="$BUILD_DIR/lib:$TERMUX_PREFIX/lib"

# Install RPATH: private llvm-termux lib dir + system lib
INSTALL_RPATH="$TERMUX_PREFIX/lib/llvm-termux:$TERMUX_PREFIX/lib"

# ccache
export CCACHE_MAXSIZE=30G
export CCACHE_DIR="$PROJECT_ROOT/.ccache"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ">>> Patching LLVM source for SVE optimizations..."
# Enable wide lane mask by default for SVE predicated loops
if grep -q 'cl::init(false)' "$PROJECT_ROOT/llvm/lib/Transforms/Vectorize/LoopVectorize.cpp" 2>/dev/null; then
    sed -i 's/"enable-wide-lane-mask", cl::init(false)/"enable-wide-lane-mask", cl::init(true)/' "$PROJECT_ROOT/llvm/lib/Transforms/Vectorize/LoopVectorize.cpp"
    echo "    EnableWideActiveLaneMask: false -> true"
else
    echo "    EnableWideActiveLaneMask already patched or not found"
fi

# Enable interleaved memory accesses by default
if grep -q 'cl::init(false)' "$PROJECT_ROOT/llvm/lib/Transforms/Vectorize/LoopVectorize.cpp" 2>/dev/null | grep -q EnableInterleavedMemAccesses; then
    sed -i 's/"enable-interleaved-mem-accesses", cl::init(false)/"enable-interleaved-mem-accesses", cl::init(true)/' "$PROJECT_ROOT/llvm/lib/Transforms/Vectorize/LoopVectorize.cpp"
    echo "    EnableInterleavedMemAccesses: false -> true"
fi

echo ">>> Re-configuring LLVM 23 (private libc++, ABI=__ndk1)..."

cmake -G Ninja \
    -DCMAKE_C_COMPILER="$TERMUX_PREFIX/bin/clang-23" \
    -DCMAKE_CXX_COMPILER="$TERMUX_PREFIX/bin/clang++" \
    -DCMAKE_ASM_COMPILER="$TERMUX_PREFIX/bin/clang-23" \
    -DCMAKE_C_COMPILER_LAUNCHER="ccache" \
    -DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$TERMUX_PREFIX" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DLLVM_ENABLE_PIC=ON \
    -DCMAKE_SYSROOT="/data/data/com.termux/files" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF \
    -DCMAKE_BUILD_RPATH="$BUILD_RPATH" \
    -DCMAKE_INSTALL_RPATH="$INSTALL_RPATH" \
    -DLLVM_HOST_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_TARGETS_TO_BUILD="AArch64;AMDGPU;ARM;AVR;BPF;Hexagon;Lanai;LoongArch;MSP430;Mips;NVPTX;PowerPC;RISCV;SPIRV;Sparc;SystemZ;VE;WebAssembly;X86;XCore" \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb;polly;mlir;flang" \
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
    -DCMAKE_C_FLAGS="$C_FLAGS" \
    -DCMAKE_CXX_FLAGS="$CXX_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LINKER_FLAGS -lm" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LINKER_FLAGS -lm" \
    -DCMAKE_MODULE_LINKER_FLAGS="$LINKER_FLAGS -lm" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_C_FLAGS="$C_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_CXX_FLAGS="$CXX_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SYSROOT="/data/data/com.termux/files" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_EXE_LINKER_FLAGS="-L$TERMUX_PREFIX/lib" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SHARED_LINKER_FLAGS="-L$TERMUX_PREFIX/lib" \
    -DRUNTIMES_${ANDROID_TRIPLE}_LIBCXX_ABI_NAMESPACE="__ndk1" \
    -DRUNTIMES_${ANDROID_TRIPLE}_LIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY=ON \
    -DRUNTIMES_${ANDROID_TRIPLE}_LIBCXXABI_STATICALLY_LINK_UNWINDER_IN_SHARED_LIBRARY=ON \
    -DRUNTIMES_${ANDROID_TRIPLE}_COMPILER_RT_INCLUDE_TESTS:BOOL=OFF \
    -DHAVE_CXX_ATOMICS_WITHOUT_LIB=1 \
    -DHAVE_CXX_ATOMICS64_WITHOUT_LIB=1 \
    -DLLVM_PARALLEL_COMPILE_JOBS=8 \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    "$PROJECT_ROOT/llvm"

echo ">>> Configure done."
echo "Build dir: $BUILD_DIR"
echo "Next: ninja -C $BUILD_DIR -j8"
