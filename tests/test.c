#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#if defined(_WIN32)
#include <windows.h> // Include 'GetSystemInfo'
#endif
#if defined(__unix__) || defined(__APPLE__)
#include <unistd.h> // Include 'sysconf' || 'getpagesize'
#endif
#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h>
#endif

#include "../src/memory.h"

int numero_de_testes = 0, acertos = 0, falhas = 0;

size_t count_utf8_code_points(const char *s) {
    size_t count = 0;
    while (*s) {
        count += (*s++ & 0xC0) != 0x80;
    }
    return count;
}

void assert(char *descricao, bool valor){
  char pontos[72], *s = descricao;
  size_t tamanho_string = 0;
  int i;
  while(*s)
    tamanho_string += (*s++ & 0xC0) != 0x80;
  pontos[0] = ' ';
  for(i = 1; i < 71 - tamanho_string; i ++)
    pontos[i] = '.';
  pontos[i] = '\0';
  numero_de_testes ++;
  printf("%s%s", descricao, pontos);
  if(valor){
#if defined(__unix__)
    printf("\e[32m[OK]\033[0m\n");
#else
    printf("[OK]\n");
#endif
    acertos ++;
  }
  else{
#if defined(__unix__)
    printf("\033[0;31m[FAIL]\033[0m\n");
#else
    printf("[FAIL]\n");
#endif
    falhas ++;
  }
}

void imprime_resultado(void){
  printf("\n%d tests: %d sucess, %d fails\n\n",
	 numero_de_testes, acertos, falhas);
}

/* Globais */
size_t page_size;
static void set_page_size(void){
#if defined(__unix__)
  page_size = sysconf(_SC_PAGESIZE);
#endif
#if defined(__APPLE__)
  page_size = getpagesize();
#endif
#if defined(_WIN32)
  {
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    page_size = info.dwPageSize;
  }
#endif
  printf("Page size: %d\n", (int) page_size);
}


/* Início dos Testes */
struct arena_header{
  #if defined(__unix__) || defined(__APPLE__)
  pthread_mutex_t mutex;
#endif
#if defined(_WIN32)
  CRITICAL_SECTION mutex;
#endif
  void *left_free, *right_free;
  void *left_point, *right_point;
  size_t remaining_space, total_size, right_allocations, left_allocations;
#if defined(W_DEBUG_MEMORY)
  size_t smallest_remaining_space;
#endif
};

void test_Wcreate_arena(void){
  size_t size_header = sizeof(struct arena_header);
  void *arena1, *arena2, *arena3;
  size_t real_size1, real_size2;
  struct arena_header *header1, *header2;
  arena1 = Wcreate_arena(0);
  arena2 = Wcreate_arena(10 * page_size - 1);
  arena3 = Wcreate_arena(8);
  header1 = (struct arena_header *) arena1;
  header2 = (struct arena_header *) arena2;
  real_size1 = header1 -> remaining_space + size_header;
  real_size2 = header2 -> remaining_space + size_header;
  assert("Arena size is consistent",
	 header1 -> total_size == real_size1 &&
	 header2 -> total_size == real_size2);
  assert("Arena minimal size is >= header size and multiple of page size",
	 arena1 != NULL &&
	 real_size1 >= size_header &&
	 real_size1  %  page_size == 0);
  assert("Arena size is always multiple of page size",
	 arena2 != NULL &&
	 real_size2 == 10 * page_size);
  assert("Arena has pointers to free space initialized",
	 header2 -> right_free == (void *)
	 (((char *) arena2) + real_size2 - 1) &&
	 header1 -> right_free == (void *)
	 (((char *) arena1) + real_size1 - 1) &&
	 header2 -> left_free == (void *)
	 ((char *) arena2 + size_header) &&
	 header1 -> left_free == (void *)
	 ((char *) arena1 + size_header) &&
	 header1 -> left_point == NULL &&
	 header2 -> left_point == NULL &&
	 header1 -> right_point == NULL &&
	 header2 -> right_point == NULL);
  assert("No memory leak in creation and destruction of arena",
	 Wdestroy_arena(arena3));
  Wdestroy_arena(arena1);
  Wdestroy_arena(arena2);
}

void test_using_arena(void){
  bool error = false;
  void *arena = Wcreate_arena(10 * page_size);
  int i;
  for(i = sizeof(struct arena_header); i < 10 * page_size; i ++)
    ((char *) arena)[i] = 'A';
  for(i = sizeof(struct arena_header); i < 10 * page_size; i ++)
    if(((char *) arena)[i] != 'A')
      error = true;
  assert("Write and read data in arena", !error);
  Wdestroy_arena(arena);
}

void test_alignment(void){
  int i, align = 1;
  void *arena = Wcreate_arena(2048);
  long long a[14];
  for(i = 0; i < 7; i ++){
    align *= 2;
    a[i] = (long long) Walloc(arena, align, 0, 4);
  }
  align  = 1;
  for(i = 7; i < 14; i ++){
    align *= 2;
    a[i] = (long long) Walloc(arena, align, 1, 4);
  }
  assert("Testing left memory alignment",
	 a[0] % 2 == 0 && a[1] % 4 == 0 && a[2] % 8 == 0 && a[3] % 16 == 0 &&
	 a[4] % 32 == 0 && a[5] % 64 == 0 && a[6] % 128 == 0);
  assert("Testing right memory alignment",
	 a[7] % 2 == 0 && a[8] % 4 == 0 && a[9] % 8 == 0 && a[10] % 16 == 0 &&
	 a[11] % 32 == 0 && a[12] % 64 == 0 && a[13] % 128 == 0);
  Wdestroy_arena(arena);
}

void test_allocation(void){
  int i, j;
  bool allocations_inside_arena = true, can_read_write = true,
    success_in_allocation = true, correct_address = true;
  char *a[20];
  void *arena = Wcreate_arena(16 * 20 + sizeof(struct arena_header *));
  void *arena2 = Wcreate_arena(page_size);
  void *p = Walloc(arena, 0, 1, page_size + 1);
  char write = 'a';
  struct arena_header *header = (struct arena_header *) arena;
  size_t size = header -> remaining_space;
  for(i = 0; i < 10; i ++){
    a[i] = (char *) Walloc(arena, 0, 0, 16);
    if(a[i] == NULL)
      success_in_allocation = false;
    if(i > 0 && ((char *) a[i] != (char *) a[i-1] + 16)){
      correct_address = false;
    }
    size -= 16;
  }
  for(i = 10; i < 20; i ++){
    a[i] = (char *) Walloc(arena, 0, 1, 16);
    if(a[i] == NULL)
      success_in_allocation = false;
    if(i > 10 && ((char *) a[i] != (char *) a[i-1] - 16)){
      correct_address = false;
    }
    size -= 16;
  }
  for(i = 0; i < 20; i ++){
    if((char *) a[i] < ((char *) arena + sizeof(struct arena_header)) ||
       (char *) a[i] + 15 >= (char *) arena + header -> total_size)
      allocations_inside_arena = false;
    for(j = 0; j < 16; j ++)
      a[i][j] = write;
    write ++;
  }
  write = 'a';
  for(i = 0; i < 20; i ++){
    for(j = 0; j < 16; j ++)
      if(a[i][j] != write){
	can_read_write = false;
      }
    write ++;
  }
  assert("Sequential allocations are successful", success_in_allocation);
  assert("Arena keeps the remaining space size updated",
	 header -> remaining_space == size);
  assert("Allocation returns correct addresses", correct_address);
  assert("Allocated arena is inside arena boundaries",
	 allocations_inside_arena);
  assert("Can read and write in allocated memory", can_read_write);
  assert("Impossible allocations return NULL", p == NULL);
  assert("Impossible allocations don't leak memory",
	 Wdestroy_arena(arena2));
  assert("Memory leaks are detectable",	!Wdestroy_arena(arena));
}

struct memory_point{
  size_t allocations; // Left or right
  struct memory_point *last_memory_point;
};

void test_memorypoint(void){
  void *arena = Wcreate_arena(10 * page_size);
  struct arena_header *header = (struct arena_header *) arena;
  bool pointers_ok = true;
  Wmemorypoint(arena, 0, 0);
  Wmemorypoint(arena, 0, 1);
  pointers_ok = pointers_ok &&  header -> right_point != NULL;
  pointers_ok = pointers_ok &&  header -> left_point != NULL;
  Wtrash(arena, 0);
  Wtrash(arena, 1);
  assert("Testing trashable heap", pointers_ok && Wdestroy_arena(arena));
}

void test_memorypoint2(void){
  void *arena = Wcreate_arena(10 * page_size), *p1, *p2, *p3, *p4;
  struct arena_header *header = (struct arena_header *) arena;
  size_t space = header -> remaining_space;
  // Left arena
  p1 = Walloc(arena, 0, 0, 8 * page_size);
  Wtrash(arena, 0);
  p1 = Walloc(arena, 0, 0, 8 * page_size);
  Wtrash(arena, 0);
  p2 = Walloc(arena, 0, 0, 4 * page_size);
  Wmemorypoint(arena, 0, 0);
  p2 = Walloc(arena, 0, 0, 4 * page_size);
  Wtrash(arena, 0);
  p2 = Walloc(arena, 0, 0, 4 * page_size);
  Wtrash(arena, 0);
  // Right arena
  p3 = Walloc(arena, 0, 1, 8 * page_size);
  Wtrash(arena, 1);
  p3 = Walloc(arena, 0, 1, 8 * page_size);
  Wtrash(arena, 1);
  p4 = Walloc(arena, 0, 1, 4 * page_size);
  Wmemorypoint(arena, 0, 1);
  p4 = Walloc(arena, 0, 1, 4 * page_size);
  Wtrash(arena, 1);
  p4 = Walloc(arena, 0, 1, 4 * page_size);
  Wtrash(arena, 1);
  assert("Trash function freeing space", p1 != NULL && p2 != NULL &&
	 p3 != NULL && p4 != NULL);
  assert("Memory is cleaned after trash function",
	 header -> remaining_space == space &&
	 header -> left_allocations == 0 &&
	 header -> right_allocations == 0 &&
	 header -> right_point == NULL &&
	 header -> left_point == NULL);
  Wdestroy_arena(arena);
}

void test_memorypoint3(void){
  void *arena = Wcreate_arena(10 * page_size);
  char *p1, *p2, *p3, *p4;
  bool integrity_ok = true;
  int i;
  // Left memory
  Wmemorypoint(arena, 4, 0);
  p1 = (char *) Walloc(arena, 4, 0, 16);
  for(i = 0; i < 16; i ++)
    p1[i] = 'A';
  Wmemorypoint(arena, 4, 0);
  p2 = Walloc(arena, 4, 0, 16);
  for(i = 0; i < 16; i ++)
    p2[i] = 'B';
  Wtrash(arena, 0);
  p2 = Walloc(arena, 4, 0, 16);
  for(i = 0; i < 16; i ++)
    p2[i] = 'C';
  for(i = 0; i < 16; i ++)
    if(p1[i] != 'A')
      integrity_ok = false;
  for(i = 0; i < 16; i ++)
    if(p2[i] != 'C')
      integrity_ok = false;
  Wtrash(arena, 0);
  // Right memory
  Wmemorypoint(arena, 4, 1);
  p3 = (char *) Walloc(arena, 4, 1, 16);
  for(i = 0; i < 16; i ++)
    p3[i] = 'A';
  Wmemorypoint(arena, 4, 1);
  p4 = Walloc(arena, 4, 1, 16);
  for(i = 0; i < 16; i ++)
    p4[i] = 'B';
  Wtrash(arena, 1);
  p4 = Walloc(arena, 4, 1, 16);
  for(i = 0; i < 16; i ++)
    p4[i] = 'C';
  for(i = 0; i < 16; i ++)
    if(p3[i] != 'A')
      integrity_ok = false;
  for(i = 0; i < 16; i ++)
    if(p4[i] != 'C')
      integrity_ok = false;
  Wtrash(arena, 1);
  assert("Testing integrity with memory points", integrity_ok &&
	 Wdestroy_arena(arena));

}

int main(int argc, char **argv){
  int semente;
  if(argc > 1)
    semente = atoi(argv[1]);
  else
    semente = time(NULL);
  srand(semente);
  printf("Starting tests. Seed: %d\n", semente);
  set_page_size();
  test_Wcreate_arena();
  test_using_arena();
  test_alignment();
  test_allocation();
  test_memorypoint();
  test_memorypoint2();
  test_memorypoint3();
  imprime_resultado();
  return 0;
}
