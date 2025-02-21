#!/bin/bash

set -euo pipefail

git submodule update --progress --init --recursive
git submodule update --remote

mkdir -p prefix
export PREFIX="$PWD/prefix"
export ROOT_DIR="$PWD"

# Build Yosys
make -C yosys -j$(nproc)

# Build LLVM
mkdir -p circt/llvm/build && cd circt/llvm/build
cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_BUILD_EXAMPLES=OFF -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_PARALLEL_LINK_JOBS=2 -DCMAKE_INSTALL_PREFIX="$PREFIX" -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_ENABLE_OCAMLDOC=OFF -DLLVM_ENABLE_BINDINGS=OFF
cmake --build .
cd "$ROOT_DIR"

# Build CIRCT
mkdir -p circt/build && cd circt/build
cmake -G Ninja .. -DMLIR_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/mlir" -DLLVM_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/llvm" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build .
cd "$ROOT_DIR"

# Build spechls-circt
mkdir -p spechls-circt/build && cd spechls-circt/build
cmake -G Ninja .. -DYosys_LIBRARY="$ROOT_DIR/yosys/libyosys.so" -DYosys_INCLUDE_DIR="$ROOT_DIR/yosys" -DMLIR_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/mlir" -DCIRCT_DIR="$ROOT_DIR/circt/build/lib/cmake/circt" -DLLVM_EXTERNAL_LIT="$ROOT_DIR/circt/llvm/build/bin/llvm-lit" -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$PREFIX" -DUSE_ALTERNATE_LINKER=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build .
