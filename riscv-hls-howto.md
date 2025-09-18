# RISC-V HLS & Embench IOT

This document gives instruction on how to compile and run Embench IOT together with the RISC-V HLS benchmark for SpecHLS.

**Note:** The following assumes that you are working in a directory denoted by the `$WORKING_DIR` environment variable, and that you can install programs to the `$PREFIX` directory.

## Setting a RISC-V cross-compilation toolchain

We will use `riscv-gnu-toolchain` as our cross-compiler. We need to set it up for the RV32I ISA, as follows:

```sh
cd "$WORKING_DIR"
git clone git@github.com:riscv-collab/riscv-gnu-toolchain.git
cd riscv-gnu-toolchain
./configure --prefix="$PREFIX" --with-arch=rv32i --with-abi=ilp32
make && make install
export PATH="$PREFIX:$PATH"
```

## Building Embench IOT

First, we need to get the Embench IOT code:

```sh
cd "$WORKING_DIR"
git clone --branch embench-1.0 git@github.com:embench/embench-iot.git
cd embench-iot
/build_all.py --arch riscv32 --chip generic --board ri5cyverilator --cc riscv32-unknown-elf-gcc --cflags="-c -O2 -ffunction-sections -march=rv32i_zicsr -mabi=ilp32" --ldflags="-Wl,-gc-sections" --user-libs="-lm"
```

## Running the RISCV-HLS Gecos benchmark

Add the following line to your test runner:

```java
this.registerTest(new RISCVHLS("/path/to/your/riscv-elf-file"))
```

You can point the path to any RV32I ELF file, including the Embench IOT binaries. The latter are located in

```sh
embench-iot/bd/src/"$BENCHMARK"/"$BENCHMARK"
```

where `$BENCHMARK` denotes the benchmark name.
