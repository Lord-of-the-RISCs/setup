.PHONY: all yosys llvm circt specHLS-circt init

pwd = $(PWD)

all: yosys llvm circt specHLS-circt

yosys: init
	$(MAKE) -C yosys -j`nproc`

llvm-init: init
	mkdir -p $(PWD)/circt/llvm/build
	cd $(PWD)/circt/llvm/build ; cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_PARALLEL_LINK_JOBS=2 -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/" -DLLVM_BUILD_LLVM_DYLIB=ON

llvm: llvm-init
	cd $(PWD)/circt/llvm/build/; cmake --build . --target install

circt-init: init llvm
	mkdir -p $(PWD)/circt/build
	cd $(PWD)/circt/build; cmake -G Ninja .. -DMLIR_DIR="$(PWD)/circt/llvm/build/lib/cmake/mlir" -DLLVM_DIR="$(PWD)/circt/llvm/build/lib/cmake/llvm" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/"

circt: circt-init
	cd $(PWD)/circt/build; cmake --build . --target install

specHLS-circt-init: init circt
	mkdir -p $(PWD)/spechls-circt/build
	cd $(PWD)/spechls-circt/build; cmake -G Ninja .. -DYosys_LIBRARY="$(PWD)/yosys/libyosys.so" -DYosys_INCLUDE_DIR="$(PWD)/yosys" -DMLIR_DIR="$(PWD)/prefix/lib/cmake/mlir" -DCIRCT_DIR="$(PWD)/prefix/lib/cmake/circt" -DLLVM_EXTERNAL_LIT="$(PWD)/circt/llvm/build/bin/llvm-lit" -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/" -DUSE_ALTERNATE_LINKER=mold

specHLS-circt: specHLS-circt-init
	cd $(PWD)/spechls-circt/build;	cmake --build . --target install

init:
	mkdir -p prefix
	git submodule update --progress --init --recursive
