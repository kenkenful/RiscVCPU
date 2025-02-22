riscv32-unknown-elf-gcc -march=rv32i  -c start.S -o start.o
riscv32-unknown-elf-gcc -march=rv32i  -c test.c -o test.o
riscv32-unknown-elf-ld -L /opt/riscv/lib/gcc/riscv32-unknown-elf/14.2.0 -lgcc -lgcov -L /opt/riscv/riscv32-unknown-elf/lib -lm  start.o test.o -T link.ld -static -o test.elf
riscv32-unknown-elf-objcopy -O binary test.elf test.bin
od -An -tx4 -w4 -v test.bin > test.hex
riscv32-unknown-elf-objdump -D test.elf > test.dump


#riscv32-unknown-elf-gcc -march=rv32i -fno-zero-initialized-in-bss -ffreestanding -fno-builtin -nostdlib -nodefaultlibs -nostartfiles -mstrict-align -c start.S -o start.o
#riscv32-unknown-elf-gcc -march=rv32i -fno-zero-initialized-in-bss -ffreestanding -fno-builtin -nostdlib -nodefaultlibs -nostartfiles -mstrict-align -c test.c -o test.o
