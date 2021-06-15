#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#define RADIX 256
#define NUM_DIGITS 8 // At base/radix 256 a 64 bit number can hold 8 digits

int radix_sort(uint64_t *arr, size_t arr_len);
void c_radix_sort(uint64_t *arr, size_t arr_len);
void print_arr(uint64_t *arr, size_t arr_len);
uint64_t *generate_random_array(size_t arr_size);
int cmpfunc(const void *a, const void *b);
void benchmark_c_radix(size_t arr_size);
void benchmark_qsort(size_t arr_size);
void benchmark_asm_radix(size_t arr_size);

char usage[] = "Usage %s: %s < array size > < number of times to repeat >";

int main(int argc, char *argv[])
{
#ifdef DEBUG
    uint64_t test_arr1[] = {1111, 2, 3, 44, 5, 666, 0, 0, 7};
    printf("Unsorted array: ");
    print_arr(test_arr1, sizeof(test_arr1) / sizeof(test_arr1[0]));
    radix_sort(test_arr1, sizeof(test_arr1) / sizeof(test_arr1[0]));
    printf("Sorted array:   ");
    print_arr(test_arr1, sizeof(test_arr1) / sizeof(test_arr1[0]));
#else
    if (argc != 3)
    {
        fprintf(stderr, usage, argv[0], argv[0]);
        return 1;
    }
    size_t random_arr_size = strtol(argv[1], NULL, 10);
    uint64_t num_times = strtol(argv[2], NULL, 10);

    printf("%ld elements in the array\n", random_arr_size);
    printf("   C Radix  |  Quicksort  |  ASM Radix  |\n");

    for (uint64_t i = 0; i < num_times; i++)
    {
        benchmark_c_radix(random_arr_size);
        benchmark_qsort(random_arr_size);
        benchmark_asm_radix(random_arr_size);
        printf("\n");
    }
#endif
    return 0;
}

void benchmark_c_radix(size_t arr_size)
{
    // 514 mb res memory
    clock_t start, end;
    double cpu_time_used;
    uint64_t *random_arr = generate_random_array(arr_size);
    if (random_arr == NULL)
    {
        fprintf(stderr, "Unable to allocate array!\n");
        return;
    }
    start = clock();
    c_radix_sort(random_arr, arr_size);
    end = clock();
    cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    free(random_arr);
    if ((cpu_time_used * 1000) / 1 < 5)
        printf("%8.0f us | ", (cpu_time_used * 1000000) / 1);
    else
        printf("%8.0f ms | ", (cpu_time_used * 1000) / 1);
}

void benchmark_asm_radix(size_t arr_size)
{
    clock_t start, end;
    double cpu_time_used;
    uint64_t *random_arr = generate_random_array(arr_size);
    if (random_arr == NULL)
    {
        fprintf(stderr, "Unable to allocate array!\n");
        return;
    }
    start = clock();
    radix_sort(random_arr, arr_size);
    end = clock();
    cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    free(random_arr);
    if ((cpu_time_used * 1000) / 1 < 5)
        printf("%8.0f us | ", (cpu_time_used * 1000000) / 1);
    else
        printf("%8.0f ms | ", (cpu_time_used * 1000) / 1);
}

void benchmark_qsort(size_t arr_size)
{
    clock_t start, end;
    double cpu_time_used;
    uint64_t *random_arr = generate_random_array(arr_size);
    if (random_arr == NULL)
    {
        fprintf(stderr, "Unable to allocate array!\n");
        return;
    }
    start = clock();
    qsort(random_arr, arr_size, sizeof(uint64_t), cmpfunc);
    end = clock();
    cpu_time_used = ((double)(end - start)) / CLOCKS_PER_SEC;
    free(random_arr);
    if ((cpu_time_used * 1000) / 1 < 5)
        printf("%8.0f us | ", (cpu_time_used * 1000000) / 1);
    else
        printf("%8.0f ms | ", (cpu_time_used * 1000) / 1);
}

int cmpfunc(const void *a, const void *b)
{
    return (*((uint64_t *)a) > *((uint64_t *)b)) -
           (*((uint64_t *)a) < *((uint64_t *)b));
}

void c_radix_sort(uint64_t *arr, size_t arr_len)
{
    /* 
    Radix sort with counting sort
    */
    // Buckets to hold all of our digit counts
    // Store the array temporary in between passes
    uint64_t *intermediate_arr = malloc(sizeof(uint64_t) * arr_len);

    // We will count the number of each digit
    // Then reorder the input list
    for (uint64_t cur_digit = 0; cur_digit < NUM_DIGITS; cur_digit++)
    {
        // This is basically count sort
        size_t digit_counts[RADIX] = {0};
        for (size_t i = 0; i < arr_len; i++)
        {
            uint64_t count_index = (arr[i] >> (8 * cur_digit)) & (RADIX - 1);
            digit_counts[count_index]++;
        }

        // Do a cum sum of the digit_counts
        for (uint16_t digit = 1; digit < 256; digit++)
        {
            digit_counts[digit] += digit_counts[digit - 1];
        }

        for (size_t i = arr_len; i > 0; i--)
        {
            uint64_t count_index = (arr[i - 1] >> (8 * cur_digit)) & (RADIX - 1);
            intermediate_arr[--digit_counts[count_index]] = arr[i - 1];
        }

        // Now switch the pointers
        uint64_t *temp = arr;
        arr = intermediate_arr;
        intermediate_arr = temp;
    }
    free(intermediate_arr);
}

void print_arr(uint64_t *arr, size_t arr_len)
{
    for (size_t i = 0; i < arr_len; i++)
    {
        printf("%ld ", arr[i]);
    }
    printf("\n");
}

uint64_t *generate_random_array(size_t arr_size)
{
    /*
    Generates a random array of uint64_t that has arr_size elements
    */
    uint64_t *stream = malloc(sizeof(uint64_t) * arr_size);
    FILE *urandom = fopen("/dev/urandom", "rb");
    if (urandom == NULL)
    {
        perror("Unable to open /dev/urandom: ");
        fclose(urandom);
        return 0;
    }
    int num_items_read = fread(stream, sizeof(uint64_t), arr_size, urandom);
    if ((size_t)num_items_read != arr_size)
    {
        fprintf(stderr, "Unable to generate random array\n");
        fclose(urandom);
        return 0;
    }
    fclose(urandom);

    return stream;
}
