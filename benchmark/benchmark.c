#include <stdio.h>
#include <math.h>
#include "../src/memory.h"

#ifdef _WIN32
#include <windows.h>
#define TIMER_START() { struct timespec t1, f1, t2, f2;		\
  QueryPerformanceCounter(&t1); QueryPerformanceFrequency(&f1);
#define TIMER_END() QueryPerformanceCounter(&t2); QueryPerformanceFrequency(&f2); \
  elapsed = ((double)t2.QuadPart/(double)f2.QuadPart) - \
    ((double)t2.QuadPart/(double)f2.QuadPart); }
#elif defined(__unix__)
#include <time.h>
#define TIMER_START() { struct timespec t1, t2;	\
  clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t1);
#define TIMER_END() clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t2);	\
  elapsed = t2.tv_sec + t2.tv_nsec*1e-9 - t1.tv_sec - t1.tv_nsec*1e-9; }
#else
#include <sys/time.h>
#include <sys/resource.h>
#define TIMER_START() { struct timeval t1, t2; gettimeofday(&t1, NULL);
#define TIMER_END()  gettimeofday(&t2, NULL);				\
  elapsed = t2.tv_sec + t2.tv_usec*1e-6 - t1.tv_sec - t1.tv_usec*1e-6; }
#endif

#define ALLOC_SIZE 5*1024
#define N 100000
double measures[N];
double mean;
double standard_deviation;
void *malloc_data[N];

void measure_walloc(void){
  void *arena = Wcreate_arena(ALLOC_SIZE * N + 1024);
  int i;
  double elapsed, sum = 0, dif_squared = 0;
  for(i = 0; i < N; i ++){
    TIMER_START();
    Walloc(arena, 0, 0, ALLOC_SIZE);
    TIMER_END();
    measures[i] = elapsed;
  }
  for(i = 0; i < N; i ++)
    sum += measures[i];
  mean = sum / N;
  for(i = 0; i < N; i ++)
    dif_squared += (measures[i] - mean) * (measures[i] - mean);
  standard_deviation = sqrt(dif_squared / (N - 1));
  printf("Walloc: %f seconds ± %f seconds\n", mean, standard_deviation);
}

void measure_malloc(void){
  int i;
  double elapsed, sum = 0, dif_squared = 0;
  for(i = 0; i < N; i ++){
    TIMER_START();
    malloc_data[i] = malloc(ALLOC_SIZE);
    TIMER_END();
    measures[i] = elapsed;
  }
  for(i = 0; i < N; i ++)
    sum += measures[i];
  mean = sum / N;
  for(i = 0; i < N; i ++)
    dif_squared += (measures[i] - mean) * (measures[i] - mean);
  standard_deviation = sqrt(dif_squared / (N - 1));
  printf("Malloc: %f seconds ± %f seconds\n", mean, standard_deviation);
}

void measure_free(void){
  int i;
  double elapsed, sum = 0, dif_squared = 0;
  for(i = 0; i < N; i ++){
    TIMER_START();
    free(malloc_data[i]);
    TIMER_END();
    measures[i] = elapsed;
  }
  for(i = 0; i < N; i ++)
    sum += measures[i];
  mean = sum / N;
  for(i = 0; i < N; i ++)
    dif_squared += (measures[i] - mean) * (measures[i] - mean);
  standard_deviation = sqrt(dif_squared / (N - 1));
  printf("Free: %f seconds ± %f seconds\n", mean, standard_deviation);
}

void measure_wmempoint_wtrash(void){
  void *arena = Wcreate_arena(ALLOC_SIZE * N + 1024);
  int i;
  double elapsed, sum = 0, dif_squared = 0;
  for(i = 0; i < N; i ++){
    TIMER_START();
    Wmempoint(arena, 0, 0);
    TIMER_END();
    measures[i] = elapsed;
  }
  for(i = 0; i < N; i ++)
    sum += measures[i];
  mean = sum / N;
  for(i = 0; i < N; i ++)
    dif_squared += (measures[i] - mean) * (measures[i] - mean);
  standard_deviation = sqrt(dif_squared / (N - 1));
  printf("Wmempoint: %f seconds ± %f seconds\n", mean, standard_deviation);
  sum = 0;
  dif_squared = 0;
  for(i = 0; i < N; i ++){
    TIMER_START();
    Wtrash(arena, 0);
    TIMER_END();
    measures[i] = elapsed;
  }
  for(i = 0; i < N; i ++)
    sum += measures[i];
  mean = sum / N;
  for(i = 0; i < N; i ++)
    dif_squared += (measures[i] - mean) * (measures[i] - mean);
  standard_deviation = sqrt(dif_squared / (N - 1));
  printf("Wtrash: %f seconds ± %f seconds\n", mean, standard_deviation);
}

int main(int argc, char **argv){
  measure_malloc();
  measure_free();
  measure_walloc();
  measure_wmempoint_wtrash();
  return 0;
}
