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
  void *internal_free, *external_free;
  void *internal_last, *external_last;
  unsigned long array[1024];
  int internal_index, external_index;
  size_t total_size, remaining_space;
#if defined(W_DEBUG_MEMORY)
  size_t smallest_remaining_space;
#endif
};

void test_Wcreate_arena(void){
  size_t size_header = sizeof(struct arena_header);
  void *arena1, *arena2;
  arena1 = Wcreate_arena(0);
  arena2 = Wcreate_arena(10 * page_size - 1);
  assert("Arena minimal size is >= header size and multiple of page size",
	 arena1 != NULL &&
	 ((struct arena_header *) arena1) -> total_size >= size_header &&
	 ((struct arena_header *) arena1) -> total_size % page_size == 0);
  assert("Arena size is always multiple of page size",
	 arena2 != NULL &&
	 ((struct arena_header *) arena2) -> total_size == 10 * page_size);
  assert("Arena size information is consistent",
	 ((struct arena_header *) arena2) -> remaining_space + size_header ==
	 ((struct arena_header *) arena2) -> total_size &&
	 ((struct arena_header *) arena1) -> remaining_space + size_header ==
	 ((struct arena_header *) arena1) -> total_size);
  assert("Arena has pointers to previously allocated data initialized",
	 ((struct arena_header *) arena2) -> internal_last == NULL &&
	 ((struct arena_header *) arena2) -> external_last == NULL  &&
	 ((struct arena_header *) arena1) -> internal_last == NULL &&
	 ((struct arena_header *) arena1) -> external_last ==  NULL);
  assert("Arena has pointers to free space initialized",
	 ((struct arena_header *) arena2) -> internal_free == (void *)
	 ((char *) arena2) + ((struct arena_header *) arena2) -> total_size
	 - 1 &&
	 ((struct arena_header *) arena1) -> internal_free == (void *)
	 ((char *) arena1) + ((struct arena_header *) arena1) -> total_size
	 - 1 &&
	 ((struct arena_header *) arena2) -> external_free == (void *)
	 ((char *) arena2 + size_header) &&
	 ((struct arena_header *) arena1) -> external_free == (void *)
	 ((char *) arena1 + size_header));
  assert("Arena has space to small alocations initialized",
	 ((struct arena_header *) arena1) -> external_index == 0 &&
	 ((struct arena_header *) arena2) -> external_index == 0 &&
	 ((struct arena_header *) arena1) -> internal_index == 1023 &&
	 ((struct arena_header *) arena2) -> internal_index == 1023);
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

  imprime_resultado();
  return 0;
}
