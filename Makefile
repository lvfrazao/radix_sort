CC = gcc
AS = nasm
CFLAGS = -g -Wall -Wextra -pedantic -Werror -flto
ASFLAGS = -felf64 -g -F dwarf -w+all
ARRAY_LEN = 1048576
REPEAT = 10

.PHONY: all
all: sort_bench sort_bench-o0 sort_bench-o3
	./sort_bench-o0 $(ARRAY_LEN) $(REPEAT)
	./sort_bench $(ARRAY_LEN) $(REPEAT)
	./sort_bench-o3 $(ARRAY_LEN) $(REPEAT)

sort_bench-o3: radix.o sort_bench.c
	$(CC) $(CFLAGS) -O3 -o sort_bench-o3 sort_bench.c radix.o

sort_bench: radix.o sort_bench.c
	$(CC) $(CFLAGS) -O2 -o sort_bench sort_bench.c radix.o

sort_bench-o0: radix.o sort_bench.c
	$(CC) $(CFLAGS) -O0 -o sort_bench-o0 sort_bench.c radix.o

radix.o: radix.s
	$(AS) $(ASFLAGS) -l radix.lst -o radix.o radix.s

.PHONY: clean
clean:
	rm radix.o radix.lst sort_bench sort_bench-o0 sort_bench-o3

