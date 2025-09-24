#!/bin/bash

set -euo pipefail

install=0
clean=0
cmake_build_type="Debug"
llvm_cmake_build_type="RelWithDebInfo"

while getopts "h?irRc" opt; do
  case "$opt" in
  h | \?)
    echo -e "Usage: $0 [-irRc]\n\nOptions:\n    -i    Install to prefix\n    -r    Build spechls-circt in release mode\n    -R    Build LLVM without debug information\n    -c    Clean intermediate build files"
    exit 0
    ;;
  i)
    install=1
    ;;
  r)
    cmake_build_type="Release"
    ;;
  R)
    llvm_cmake_build_type="Release"
    ;;
  c)
    clean=1
    ;;
  esac
done

git submodule update --progress --init --recursive
git submodule update --remote

mkdir -p prefix
export PREFIX=${PREFIX:-"$PWD/prefix"}
export ROOT_DIR="$PWD"

# Build Yosys
make -C yosys -j$(nproc)
make -C yosys install PREFIX="$PREFIX"

# Build LLVM
mkdir -p circt/llvm/build && cd circt/llvm/build
cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir -DCMAKE_BUILD_TYPE="$llvm_cmake_build_type" -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_TARGETS_TO_BUILD="host" -DLLVM_BUILD_EXAMPLES=OFF -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_PARALLEL_LINK_JOBS=2 -DCMAKE_INSTALL_PREFIX="$PREFIX" -DLLVM_BUILD_LLVM_DYLIB=ON -DMLIR_BUILD_MLIR_C_DYLIB=ON -DLLVM_ENABLE_OCAMLDOC=OFF -DLLVM_ENABLE_BINDINGS=OFF
cmake --build .
if [ "$install" -eq 1 ]; then
  cmake --build . --target install
fi
cd "$ROOT_DIR"

# Build CIRCT
mkdir -p circt/build && cd circt/build
cmake -G Ninja .. -DMLIR_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/mlir" -DLLVM_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/llvm" -DCMAKE_BUILD_TYPE="$llvm_cmake_build_type" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCIRCT_SLANG_FRONTEND_ENABLED=ON
cmake --build .
if [ "$install" -eq 1 ]; then
  cmake --build . --target install
fi
cd "$ROOT_DIR"

# Build spechls-circt
mkdir -p spechls-circt/build && cd spechls-circt/build
cmake -G Ninja .. -DCMAKE_BUILD_TYPE="$cmake_build_type" -DYosys_LIBRARY="$ROOT_DIR/yosys/libyosys.so" -DYosys_INCLUDE_DIR="$ROOT_DIR/yosys" -DMLIR_DIR="$ROOT_DIR/circt/llvm/build/lib/cmake/mlir" -DCIRCT_DIR="$ROOT_DIR/circt/build/lib/cmake/circt" -DLLVM_EXTERNAL_LIT="$ROOT_DIR/circt/llvm/build/bin/llvm-lit" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DUSE_ALTERNATE_LINKER=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build .
if [ "$install" -eq 1 ]; then
  cmake --build . --target install
fi
cd "$ROOT_DIR"

if [ "$clean" -eq 1 ]; then
  cd circt/llvm/build
  cmake --build . --target clean
  cd "$ROOT_DIR"
  cd circt/build
  cmake --build . --target clean
  cd "$ROOT_DIR"
  cd spechls-circt/build
  cmake --build . --target clean
  cd "$ROOT_DIR"
fi
