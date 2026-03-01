#!/bin/bash
set -e

# ================= 配置路径 =================
PROJECT_ROOT="/data/data/com.termux/files/home/llvm-project"
BUILD_DIR="/data/data/com.termux/files/home/llvm-build-dynamic"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
INSTALL_PREFIX="/data/data/com.termux/files/usr/llvm-so"
ANDROID_TRIPLE="aarch64-unknown-linux-android35"

# 使用现有安装的工具链（如果存在则使用新路径，否则回退）
NEW_CLANG="$INSTALL_PREFIX/bin/clang"
NEW_CLANGXX="$INSTALL_PREFIX/bin/clang++"
NEW_LIB_DIR="$INSTALL_PREFIX/lib"

# 找到母体编译器的运行时库，解决自举符号缺失
# 注意：这里路径根据 LLVM 23 的实际结构可能需要调整，暂时保留逻辑
MOTHER_RT="/data/data/com.termux/files/usr/llvm/lib/clang/23/lib/linux/libclang_rt.builtins-aarch64-android.a"

# ================= 编译参数 =================
# 64KB 页面对齐 + 硬编码运行时库路径 + 注入静态 builtins
LDFLAGS_FIX="-Wl,-z,max-page-size=65536 -Wl,-z,common-page-size=65536 -Wl,-z,separate-loadable-segments -L$TERMUX_PREFIX/lib -L$NEW_LIB_DIR -Wl,-rpath,$TERMUX_PREFIX/lib -Wl,-rpath,$INSTALL_PREFIX/lib $MOTHER_RT"

# CPU 优化：针对 Cortex-X925，开启 RTTI 支持 Vulkan 工具链
CPU_FLAGS="-fPIC --target=$ANDROID_TRIPLE -stdlib=libc++ -D_LIBCPP_DISABLE_AVAILABILITY -mcpu=cortex-x925 -Os -D_GNU_SOURCE -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -I$TERMUX_PREFIX/include -I$TERMUX_PREFIX/include/aarch64-linux-android"

echo ">>> 1. 环境准备与补丁..."
cd "$PROJECT_ROOT"
mkdir -p "$BUILD_DIR/lib"
mkdir -p "$BUILD_DIR/bin"

# 解决 libc++ 依赖问题的物理副本补丁
SYSLIB="$TERMUX_PREFIX/lib/libc++_shared.so"
for target_dir in "$BUILD_DIR/bin" "$BUILD_DIR/lib"; do
    rm -f "$target_dir/libc++.so.1" "$target_dir/libc++abi.so.1" "$target_dir/libc++_shared.so"
    cp "$SYSLIB" "$target_dir/libc++.so.1"
    cp "$SYSLIB" "$target_dir/libc++abi.so.1"
    cp "$SYSLIB" "$target_dir/libc++_shared.so"
done

echo ">>> 2. 准备构建目录..."
cd "$BUILD_DIR"
rm -f CMakeCache.txt # 强制重新配置以清除旧的缓存项

echo ">>> 3. 开始全环境 (含 SPIR-V/Vulkan) 优先级优化配置..."
# 【核心：RPATH 优先级调整】确保构建目录在最前面
cmake -G Ninja \
    -DCMAKE_C_COMPILER="$NEW_CLANG" \
    -DCMAKE_CXX_COMPILER="$NEW_CLANGXX" \
    -DCMAKE_ASM_COMPILER="$NEW_CLANG" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DLLVM_ENABLE_PIC=ON \
    -DCMAKE_SYSROOT="/data/data/com.termux/files" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF \
    -DCMAKE_BUILD_RPATH="$BUILD_DIR/lib" \
    -DCMAKE_INSTALL_RPATH="$INSTALL_PREFIX/lib" \
    -DLLVM_HOST_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_DEFAULT_TARGET_TRIPLE="$ANDROID_TRIPLE" \
    -DLLVM_TARGETS_TO_BUILD="all" \
    -DLLVM_ENABLE_PROJECTS="clang;lld;mlir;polly;bolt;clang-tools-extra;lldb" \
    -DPython3_INCLUDE_DIR="/data/data/com.termux/files/usr/include/python3.12" \
    -DPython3_LIBRARY="/data/data/com.termux/files/usr/lib/libpython3.12.so" \
    -DPython3_EXECUTABLE="/data/data/com.termux/files/usr/bin/python3" \
    -DLLDB_ENABLE_PYTHON=ON \
    -DLLDB_ENABLE_LIBEDIT=ON \
    -DLLDB_ENABLE_CURSES=ON \
    -DLLDB_PYTHON_EXE_RELATIVE_PATH="bin/python3" \
    -DLibEdit_INCLUDE_DIRS="/data/data/com.termux/files/usr/include" \
    -DLibEdit_LIBRARIES="/data/data/com.termux/files/usr/lib/libedit.so" \
    -DZLIB_INCLUDE_DIR="/data/data/com.termux/files/usr/include" \
    -DZLIB_LIBRARY="/data/data/com.termux/files/usr/lib/libz.so" \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind;openmp;libclc" \
    -DLLVM_RUNTIME_TARGETS="$ANDROID_TRIPLE" \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DCLANG_LINK_CLANG_DYLIB=ON \
    -DLLVM_ENABLE_LIBCXX=ON \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_INSTALL_UTILS=ON \
    -DCLANG_DEFAULT_LINKER="lld" \
    -DCLANG_DEFAULT_RTLIB="compiler-rt" \
    -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
    -DCMAKE_C_FLAGS="$CPU_FLAGS" \
    -DCMAKE_CXX_FLAGS="$CPU_FLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DCMAKE_MODULE_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_C_FLAGS="$CPU_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_CXX_FLAGS="$CPU_FLAGS -funwind-tables" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SYSROOT="/data/data/com.termux/files" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$BUILD_DIR/lib -L$TERMUX_PREFIX/lib" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath,$BUILD_DIR/lib -L$TERMUX_PREFIX/lib" \
    -DRUNTIMES_${ANDROID_TRIPLE}_CMAKE_REQUIRED_LIBRARIES="-L$TERMUX_PREFIX/lib;-lc++_shared" \
    -DLIBCLC_TARGETS_TO_BUILD="all" \
    -DBUILTINS_CMAKE_ARGS="-DCMAKE_C_FLAGS=$CPU_FLAGS;-DCMAKE_CXX_FLAGS=$CPU_FLAGS;-DCMAKE_ASM_FLAGS=$CPU_FLAGS;-DCOMPILER_RT_HAS_VISIBILITY_HIDDEN_FLAG=OFF" \
    -DLLVM_PARALLEL_COMPILE_JOBS=8 \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    "$PROJECT_ROOT/llvm"

echo ">>> 配置阶段结束。请检查输出是否显示检测通过。"
