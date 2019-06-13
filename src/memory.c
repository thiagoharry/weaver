/*31:*/
#line 819 "./weaver-memory-manager.tex"

/*7:*/
#line 310 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h> 
#endif
/*:7*//*12:*/
#line 388 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>   
#include <memoryapi.h>  
#endif
/*:12*//*15:*/
#line 442 "./weaver-memory-manager.tex"

#if defined(__APPLE__) || defined(__unix__)
#include <unistd.h> 
#endif
/*:15*//*17:*/
#line 470 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>  
#endif
/*:17*//*19:*/
#line 523 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h> 
#endif
/*:19*/
#line 820 "./weaver-memory-manager.tex"

#include "memory.h"
/*25:*/
#line 629 "./weaver-memory-manager.tex"

struct arena_header{
/*20:*/
#line 533 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_t mutex;
#endif
#if defined(_WIN32)
CRITICAL_SECTION mutex;
#endif
/*:20*/
#line 631 "./weaver-memory-manager.tex"

void*left_free,*right_free;
size_t remaining_space;
#if defined(W_DEBUG_MEMORY)
size_t total_size,smallest_remaining_space;
#endif
};
/*:25*/
#line 822 "./weaver-memory-manager.tex"

/*27:*/
#line 697 "./weaver-memory-manager.tex"

void*Wcreate_arena(size_t t){
bool error= false;
void*arena;
size_t p,M,header_size= sizeof(struct arena_header);

/*13:*/
#line 416 "./weaver-memory-manager.tex"

#if defined(__unix__)
p= sysconf(_SC_PAGESIZE);
#endif
/*:13*//*14:*/
#line 431 "./weaver-memory-manager.tex"

#if defined(__APPLE__)
p= getpagesize();
#endif
/*:14*//*16:*/
#line 455 "./weaver-memory-manager.tex"

#if defined(_WIN32)
{
SYSTEM_INFO info;
GetSystemInfo(&info);
p= info.dwPageSize;
}
#endif
/*:16*//*18:*/
#line 487 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__)
p= 64*1024;
#endif
/*:18*/
#line 703 "./weaver-memory-manager.tex"


M= (((t-1)/p)+1)*p;
if(M<header_size)
M= (((header_size-1)/p)+1)*p;

/*8:*/
#line 323 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
arena= mmap(NULL,M,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,
-1,0);
#endif
/*:8*//*10:*/
#line 359 "./weaver-memory-manager.tex"

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
/*:10*/
#line 709 "./weaver-memory-manager.tex"


/*26:*/
#line 653 "./weaver-memory-manager.tex"

{
struct arena_header*header= (struct arena_header*)arena;
header->right_free= ((char*)header)+M-1;
header->left_free= ((char*)header)+sizeof(struct arena_header);
header->remaining_space= M-sizeof(struct arena_header);
#if defined(W_DEBUG_MEMORY)
header->total_size= M;
header->smallest_remaining_space= header->remaining_space;
#endif
{
void*mutex= &(header->mutex);
/*21:*/
#line 551 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
error= pthread_mutex_init((pthread_mutex_t*)mutex,NULL);
#endif
#if defined(_WIN32)
InitializeCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:21*/
#line 665 "./weaver-memory-manager.tex"

}
}
/*:26*/
#line 711 "./weaver-memory-manager.tex"


if(error)return NULL;
return arena;
}
/*:27*/
#line 823 "./weaver-memory-manager.tex"

/*:31*/
