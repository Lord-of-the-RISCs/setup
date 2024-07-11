.PHONY: all yosys llvm circt specHLS-circt gecos-hls init test

pwd = $(PWD)

all: yosys llvm circt specHLS-circt gecos-hls

yosys:
	sed -i -e 's|ENABLE_LIBYOSYS := 0|ENABLE_LIBYOSYS := 1|g' yosys/Makefile
	$(MAKE) -C yosys

llvm-init:
	mkdir -p $(PWD)/circt/llvm/build
	cd $(PWD)/circt/llvm/build ; cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS=mlir -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_INSTALL_UTILS=ON -DLLVM_PARALLEL_LINK_JOBS=2 -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/" -DLLVM_BUILD_LLVM_DYLIB=ON
	echo "llvm ok"

llvm: llvm-init
	cd $(PWD)/circt/llvm/build/; cmake --build . --target install

circt-init:
	mkdir -p $(PWD)/circt/build
	cd $(PWD)/circt/build; cmake -G Ninja .. -DMLIR_DIR="$(PWD)/circt/llvm/build/lib/cmake/mlir" -DLLVM_DIR="$(PWD)/circt/llvm/build/lib/cmake/llvm" -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/"

circt: circt-init
	cd $(PWD)/circt/build; cmake --build . --target install

specHLS-circt-init:
	mkdir -p $(PWD)/spechls-circt/build
	cd $(PWD)/spechls-circt/build; cmake -G Ninja .. -DYOSYS_LIBRARY_DIR="$(PWD)/yosys" -DYOSYS_INCLUDE_DIR="$(PWD)/yosys/share/include" -DMLIR_DIR="$(PWD)/prefix/lib/cmake/mlir" -DCIRCT_DIR="$(PWD)/prefix/lib/cmake/circt" -DLLVM_EXTERNAL_LIT="$(PWD)/circt/llvm/build/bin/llvm-lit" -DLLVM_ENABLE_LLD=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX="$(PWD)/prefix/"

specHLS-circt: specHLS-circt-init
	cd $(PWD)/spechls-circt/build;	cmake --build . --target install

gecos-hls:
	git clone https://gitlab.inria.fr/gecos/gecos-hls.git
	bash install-eclipse-dependency.sh $(PWD)

init:
	mkdir -p prefix
	git submodule update --init --recursive
