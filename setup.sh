#!/bin/bash

set -euo pipefail

install=0
clean=0
spechls_target=${SPECHLS_TARGET:-all}
cmake_build_type="Debug"
llvm_cmake_build_type="RelWithDebInfo"
use_local_llvm=0

while getopts "h?ilrRc" opt; do
  case "$opt" in
  h | \?)
    echo -e "Usage: $0 [-ilrRc]\n\nOptions:\n    -i    Install to prefix\n    -l    Use the local LLVM/MLIR installation (LLVM_PREFIX)\n    -r    Build spechls-circt in release mode\n    -R    Build LLVM without debug information\n    -c    Clean intermediate build files"
    exit 0
    ;;
  i)
    install=1
    ;;
  l)
    use_local_llvm=1
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

for submodule in circt spechls-circt; do
  if [ -e "$submodule/.git" ] && [ -n "$(git -C "$submodule" status --porcelain)" ]; then
    echo "Skipping dirty submodule $submodule"
    continue
  fi
  git submodule update --progress --init --recursive --remote "$submodule"
done

mkdir -p prefix
export PREFIX=${PREFIX:-"$PWD/prefix"}
export ROOT_DIR="$PWD"

LOCAL_PREFIX=${LOCAL_PREFIX:-"$HOME/.local"}
LLVM_PREFIX=${LLVM_PREFIX:-"$LOCAL_PREFIX/llvm22"}
CIRCT_PREFIX=${CIRCT_PREFIX:-}
llvm_compiler_args=()
local_linker_flags=""
if [ -d "$LOCAL_PREFIX" ]; then
  if [ -d "$LOCAL_PREFIX/lib/pkgconfig" ]; then
    export PKG_CONFIG_PATH="$LOCAL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  fi
  if [ -d "$LOCAL_PREFIX/lib" ]; then
    export LD_LIBRARY_PATH="$LOCAL_PREFIX/lib:${LD_LIBRARY_PATH:-}"
    export LIBRARY_PATH="$LOCAL_PREFIX/lib:${LIBRARY_PATH:-}"
    local_linker_flags="-L$LOCAL_PREFIX/lib -Wl,-rpath-link,$LOCAL_PREFIX/lib -Wl,-rpath,$LOCAL_PREFIX/lib"
  fi
  if [ -d "$LOCAL_PREFIX/include" ]; then
    export CPATH="$LOCAL_PREFIX/include:${CPATH:-}"
  fi
fi

# Build Yosys
make -C yosys -j$(nproc)
make -C yosys install PREFIX="$PREFIX"

if [ "$use_local_llvm" -eq 1 ]; then
  if [ ! -f "$LLVM_PREFIX/lib/cmake/llvm/LLVMConfig.cmake" ] || \
     [ ! -f "$LLVM_PREFIX/lib/cmake/mlir/MLIRConfig.cmake" ] || \
     [ ! -x "$LLVM_PREFIX/bin/clang" ] || [ ! -x "$LLVM_PREFIX/bin/clang++" ]; then
    echo "LLVM_PREFIX does not contain LLVM/MLIR CMake packages: $LLVM_PREFIX" >&2
    exit 1
  fi
  llvm_cmake_dir="$LLVM_PREFIX/lib/cmake/llvm"
  mlir_cmake_dir="$LLVM_PREFIX/lib/cmake/mlir"
  llvm_c_compiler="$LLVM_PREFIX/bin/clang"
  llvm_cxx_compiler="$LLVM_PREFIX/bin/clang++"
  llvm_compiler_args=("-DCMAKE_C_COMPILER=$llvm_c_compiler" "-DCMAKE_CXX_COMPILER=$llvm_cxx_compiler")
  export PATH="$LLVM_PREFIX/bin:$PATH"
  if [ -x "$LLVM_PREFIX/bin/llvm-lit" ]; then
    llvm_lit="$LLVM_PREFIX/bin/llvm-lit"
  elif command -v lit >/dev/null 2>&1; then
    llvm_lit="$(command -v lit)"
  else
    echo "Could not find llvm-lit or lit for the local LLVM installation" >&2
    exit 1
  fi
  export LD_LIBRARY_PATH="$LLVM_PREFIX/lib:${LD_LIBRARY_PATH:-}"
  export LLVM_CONFIG="$LLVM_PREFIX/bin/llvm-config"
else
  # Build LLVM
  mkdir -p circt/llvm/build && cd circt/llvm/build
  cmake -G Ninja ../llvm \
    "-DLLVM_ENABLE_PROJECTS=clang;polly;mlir" \
    -DCMAKE_BUILD_TYPE="$llvm_cmake_build_type" \
    -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_TARGETS_TO_BUILD="host" \
    -DLLVM_BUILD_EXAMPLES=OFF -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_INSTALL_UTILS=ON -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DMLIR_BUILD_MLIR_C_DYLIB=ON -DLLVM_ENABLE_OCAMLDOC=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF
  cmake --build .
  if [ "$install" -eq 1 ]; then
    cmake --build . --target install
  fi
  llvm_cmake_dir="$ROOT_DIR/circt/llvm/build/lib/cmake/llvm"
  mlir_cmake_dir="$ROOT_DIR/circt/llvm/build/lib/cmake/mlir"
  llvm_c_compiler=""
  llvm_cxx_compiler=""
  llvm_lit="$ROOT_DIR/circt/llvm/build/bin/llvm-lit"
  cd "$ROOT_DIR"
fi

if [ "$use_local_llvm" -eq 1 ] && [ -z "$CIRCT_PREFIX" ] && \
   [ -f "$LOCAL_PREFIX/lib/cmake/circt/CIRCTConfig.cmake" ]; then
  CIRCT_PREFIX="$LOCAL_PREFIX"
fi

if [ -n "$CIRCT_PREFIX" ]; then
  if [ ! -f "$CIRCT_PREFIX/lib/cmake/circt/CIRCTConfig.cmake" ]; then
    echo "CIRCT_PREFIX does not contain a CIRCT CMake package: $CIRCT_PREFIX" >&2
    exit 1
  fi
  circt_cmake_dir="$CIRCT_PREFIX/lib/cmake/circt"
else
  # Build CIRCT against the selected LLVM/MLIR installation.
  mkdir -p circt/build && cd circt/build
  cmake -G Ninja .. -DMLIR_DIR="$mlir_cmake_dir" -DLLVM_DIR="$llvm_cmake_dir" "${llvm_compiler_args[@]}" -DLLVM_EXTERNAL_LIT="$llvm_lit" -DVERILATOR_DISABLE=ON -DCMAKE_BUILD_TYPE="$llvm_cmake_build_type" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCIRCT_SLANG_FRONTEND_ENABLED=ON
  cmake --build .
  if [ "$install" -eq 1 ]; then
    cmake --build . --target install
  fi
  circt_cmake_dir="$ROOT_DIR/circt/build/lib/cmake/circt"
  cd "$ROOT_DIR"
fi

# Build spechls-circt
mkdir -p spechls-circt/build && cd spechls-circt/build
cmake -G Ninja .. -DCMAKE_BUILD_TYPE="$cmake_build_type" -DYosys_LIBRARY="$PREFIX/lib/yosys/libyosys.so" -DYosys_INCLUDE_DIR="$ROOT_DIR/yosys" -DMLIR_DIR="$mlir_cmake_dir" -DLLVM_DIR="$llvm_cmake_dir" -DCIRCT_DIR="$circt_cmake_dir" "${llvm_compiler_args[@]}" -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_EXTERNAL_LIT="$llvm_lit" -DCMAKE_INSTALL_PREFIX="$PREFIX" -DUSE_ALTERNATE_LINKER=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_EXE_LINKER_FLAGS="$local_linker_flags" -DCMAKE_SHARED_LINKER_FLAGS="$local_linker_flags" -DSPECHLS_DISABLE_VERILOG_IMPORT=OFF
cmake --build . --target "$spechls_target"
if [ "$install" -eq 1 ]; then
  cmake --build . --target install
fi
cd "$ROOT_DIR"

if [ "$clean" -eq 1 ]; then
  if [ "$use_local_llvm" -eq 0 ]; then
    cd circt/llvm/build
    cmake --build . --target clean
    cd "$ROOT_DIR"
  fi
  if [ -z "$CIRCT_PREFIX" ]; then
    cd circt/build
    cmake --build . --target clean
    cd "$ROOT_DIR"
  fi
  cd spechls-circt/build
  cmake --build . --target clean
  cd "$ROOT_DIR"
fi
