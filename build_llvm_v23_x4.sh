#!/bin/bash
set -e

# 配置路径
PROJECT_ROOT="/data/data/com.termux/files/home/llvm-project"
BUILD_DIR="/data/data/com.termux/files/home/llvm-build-dynamic"
COMPILER_BIN="/data/data/com.termux/files/usr/llvm/bin"

# 16KB 对齐参数 (解决 Android TLS 对齐报错)
LDFLAGS_FIX="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

echo ">>> 1. 进入源码目录 (跳过所有 Git 状态检查)..."
cd "$PROJECT_ROOT"

echo ">>> 2. 准备构建目录..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ">>> 3. 开始 CMake 配置 (开启 CCACHE & 16KB 对齐 & 禁用版本探测)..."
cmake -G Ninja \
    -DCMAKE_C_COMPILER="$COMPILER_BIN/clang" \
    -DCMAKE_CXX_COMPILER="$COMPILER_BIN/clang++" \
    -DCMAKE_ASM_COMPILER="$COMPILER_BIN/clang" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DLLVM_ENABLE_PROJECTS="clang;lld;lldb;mlir;polly;flang;bolt" \
    -DLLVM_ENABLE_RUNTIMES="openmp" \
    -DCMAKE_C_FLAGS="-mcpu=cortex-x4" \
    -DCMAKE_CXX_FLAGS="-mcpu=cortex-x4" \
    -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DCMAKE_MODULE_LINKER_FLAGS="$LDFLAGS_FIX" \
    -DLLVM_PARALLEL_COMPILE_JOBS=8 \
    -DLLVM_PARALLEL_LINK_JOBS=3 \
    -DLLVM_DEFAULT_TARGET_TRIPLE="aarch64-linux-android" \
    -DLLVM_TARGETS_TO_BUILD="AArch64" \
    "$PROJECT_ROOT/llvm"

