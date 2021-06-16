CC = gcc
AS = nasm
CFLAGS = -g -Wall -Wextra -pedantic -Werror -O2
ASFLAGS = -felf64 -g -F dwarf -w+all

.PHONY: all
all: sort_bench
	./sort_bench 4096 5

sort_bench: radix.o sort_bench.c
	$(CC) $(CFLAGS) -o sort_bench sort_bench.c radix.o

radix.o: radix.s
	$(AS) $(ASFLAGS) -l radix.lst -o radix.o radix.s

.PHONY: clean
clean:
	rm radix.o radix.lst sort_bench

