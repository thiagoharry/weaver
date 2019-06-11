/*31:*/
#line 856 "./weaver-memory-manager.tex"

/*8:*/
#line 346 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h> 
#endif
/*:8*//*13:*/
#line 424 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>   
#include <memoryapi.h>  
#endif
/*:13*//*16:*/
#line 478 "./weaver-memory-manager.tex"

#if defined(__APPLE__) || defined(__unix__)
#include <unistd.h> 
#endif
/*:16*//*18:*/
#line 506 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>  
#endif
/*:18*//*20:*/
#line 559 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h> 
#endif
/*:20*/
#line 857 "./weaver-memory-manager.tex"

#include "memory.h"
/*29:*/
#line 793 "./weaver-memory-manager.tex"

#define ALLOCATION 0x01010101
#define HOLE       0x02020202
/*:29*/
#line 859 "./weaver-memory-manager.tex"

/*26:*/
#line 680 "./weaver-memory-manager.tex"

struct arena_header{
/*21:*/
#line 569 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_t mutex;
#endif
#if defined(_WIN32)
CRITICAL_SECTION mutex;
#endif
/*:21*/
#line 682 "./weaver-memory-manager.tex"

void*internal_free,*external_free;
void*internal_last,*external_last;
unsigned long array[1024];
int internal_index,external_index;
size_t total_size,remaining_space;
#if defined(W_DEBUG_MEMORY)
size_t smallest_remaining_space;
#endif
};
/*:26*//*30:*/
#line 833 "./weaver-memory-manager.tex"

struct alloc_header{
unsigned long type;
void*last_element;
struct arena_header*arena;

size_t size;
#if defined(W_DEBUG_MEMORY)
char file[32];
unsigned long line;
#endif
};
/*:30*/
#line 860 "./weaver-memory-manager.tex"

/*28:*/
#line 754 "./weaver-memory-manager.tex"

void*Wcreate_arena(size_t t){
bool error= false;
void*arena;
size_t p,M,header_size= sizeof(struct arena_header);

/*14:*/
#line 452 "./weaver-memory-manager.tex"

#if defined(__unix__)
p= sysconf(_SC_PAGESIZE);
#endif
/*:14*//*15:*/
#line 467 "./weaver-memory-manager.tex"

#if defined(__APPLE__)
p= getpagesize();
#endif
/*:15*//*17:*/
#line 491 "./weaver-memory-manager.tex"

#if defined(_WIN32)
{
SYSTEM_INFO info;
GetSystemInfo(&info);
p= info.dwPageSize;
}
#endif
/*:17*//*19:*/
#line 523 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__)
p= 64*1024;
#endif
/*:19*/
#line 760 "./weaver-memory-manager.tex"


M= (((t-1)/p)+1)*p;
if(M<header_size)
M= (((header_size-1)/p)+1)*p;

/*9:*/
#line 359 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
arena= mmap(NULL,M,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,
-1,0);
#endif
/*:9*//*11:*/
#line 395 "./weaver-memory-manager.tex"

#if defined(_WIN32)
{
HANDLE handle;
handle= CreateFileMappingA(INVALID_HANDLE_VALUE,NULL,
PAGE_READWRITE,
(DWORD)((DWORDLONG)M)/((DWORDLONG)4294967296),
(DWORD)((DWORDLONG)M)%((DWORDLONG)4294967296),
NULL);
arena= MapViewOfFile(handle,FILE_MAP_READ|FILE_MAP_WRITE,0,0,0);
CloseHandle(handle);
}
#endif
/*:11*/
#line 766 "./weaver-memory-manager.tex"


/*27:*/
#line 707 "./weaver-memory-manager.tex"

{
struct arena_header*header= (struct arena_header*)arena;
header->internal_free= ((char*)header)+M-1;
header->external_free= ((char*)header)+sizeof(struct arena_header);
header->internal_last= header->external_last= NULL;
header->internal_index= 1023;
header->external_index= 0;
header->remaining_space= M-sizeof(struct arena_header);
header->total_size= M;
#if defined(W_DEBUG_MEMORY)
header->smallest_remaining_space= header->remaining_space;
#endif
{
void*mutex= &(header->mutex);
/*22:*/
#line 587 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
error= pthread_mutex_init((pthread_mutex_t*)mutex,NULL);
#endif
#if defined(_WIN32)
InitializeCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:22*/
#line 722 "./weaver-memory-manager.tex"

}
}
/*:27*/
#line 768 "./weaver-memory-manager.tex"


if(error)return NULL;
return arena;
}
/*:28*/
#line 861 "./weaver-memory-manager.tex"

/*:31*/
