/*34:*/
#line 905 "./weaver-memory-manager.tex"

/*7:*/
#line 311 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h> 
#endif
/*:7*//*12:*/
#line 389 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>   
#include <memoryapi.h>  
#endif
/*:12*//*15:*/
#line 443 "./weaver-memory-manager.tex"

#if defined(__APPLE__) || defined(__unix__)
#include <unistd.h> 
#endif
/*:15*//*17:*/
#line 471 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>  
#endif
/*:17*//*19:*/
#line 524 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h> 
#endif
/*:19*//*29:*/
#line 762 "./weaver-memory-manager.tex"

#if defined(W_DEBUG_MEMORY)
#include <stdio.h> 
#endif
/*:29*/
#line 906 "./weaver-memory-manager.tex"

#include "memory.h"
/*25:*/
#line 628 "./weaver-memory-manager.tex"

struct arena_header{
/*20:*/
#line 534 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_t mutex;
#endif
#if defined(_WIN32)
CRITICAL_SECTION mutex;
#endif
/*:20*/
#line 630 "./weaver-memory-manager.tex"

void*left_free,*right_free;
size_t remaining_space,total_size;
#if defined(W_DEBUG_MEMORY)
size_t smallest_remaining_space;
#endif
};
/*:25*/
#line 908 "./weaver-memory-manager.tex"

/*27:*/
#line 696 "./weaver-memory-manager.tex"

void*Wcreate_arena(size_t t){
bool error= false;
void*arena;
size_t p,M,header_size= sizeof(struct arena_header);

/*13:*/
#line 417 "./weaver-memory-manager.tex"

#if defined(__unix__)
p= sysconf(_SC_PAGESIZE);
#endif
/*:13*//*14:*/
#line 432 "./weaver-memory-manager.tex"

#if defined(__APPLE__)
p= getpagesize();
#endif
/*:14*//*16:*/
#line 456 "./weaver-memory-manager.tex"

#if defined(_WIN32)
{
SYSTEM_INFO info;
GetSystemInfo(&info);
p= info.dwPageSize;
}
#endif
/*:16*//*18:*/
#line 488 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__)
p= 64*1024;
#endif
/*:18*/
#line 702 "./weaver-memory-manager.tex"


M= (((t-1)/p)+1)*p;
if(M<header_size)
M= (((header_size-1)/p)+1)*p;

/*8:*/
#line 324 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
arena= mmap(NULL,M,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,
-1,0);
#endif
/*:8*//*10:*/
#line 360 "./weaver-memory-manager.tex"

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
#line 708 "./weaver-memory-manager.tex"


/*26:*/
#line 652 "./weaver-memory-manager.tex"

{
struct arena_header*header= (struct arena_header*)arena;
header->right_free= ((char*)header)+M-1;
header->left_free= ((char*)header)+sizeof(struct arena_header);
header->remaining_space= M-sizeof(struct arena_header);
header->total_size= M;
#if defined(W_DEBUG_MEMORY)
header->smallest_remaining_space= header->remaining_space;
#endif
{
void*mutex= &(header->mutex);
/*21:*/
#line 552 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
error= pthread_mutex_init((pthread_mutex_t*)mutex,NULL);
#endif
#if defined(_WIN32)
InitializeCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:21*/
#line 664 "./weaver-memory-manager.tex"

}
}
/*:26*/
#line 710 "./weaver-memory-manager.tex"


if(error)return NULL;
return arena;
}
/*:27*/
#line 909 "./weaver-memory-manager.tex"

/*28:*/
#line 736 "./weaver-memory-manager.tex"

bool Wdestroy_arena(void*arena){
struct arena_header*header= (struct arena_header*)arena;
void*mutex= (void*)&(header->mutex);
size_t M= header->total_size;
bool ret= true;
/*22:*/
#line 566 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_destroy((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
DeleteCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:22*/
#line 742 "./weaver-memory-manager.tex"

if(header->total_size!=header->remaining_space+
sizeof(struct arena_header))
ret= false;
#if defined(W_DEBUG_MEMORY)
printf("Unused memory: %zu/%zu (%f%%)\n",
header->smallest_remaining_space,header->total_size,
100.0*
((float)header->smallest_remaining_space)/header->total_size);
#endif
/*9:*/
#line 341 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
munmap(arena,M);
#endif
/*:9*//*11:*/
#line 379 "./weaver-memory-manager.tex"

#if defined(_WIN32)
UnmapViewOfFile(arena);
#endif
/*:11*/
#line 752 "./weaver-memory-manager.tex"

return ret;
}
/*:28*/
#line 910 "./weaver-memory-manager.tex"

/*33:*/
#line 883 "./weaver-memory-manager.tex"

void*Walloc(void*arena,unsigned a,int right,size_t t){
struct arena_header*header= (struct arena_header*)arena;
void*mutex= (void*)&(header->mutex);
void*p= NULL;
/*23:*/
#line 579 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_lock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
EnterCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:23*/
#line 888 "./weaver-memory-manager.tex"

/*32:*/
#line 843 "./weaver-memory-manager.tex"

{
int offset;
struct arena_header*header= (struct arena_header*)arena;
if(header->remaining_space>=t+((a==0)?(0):(a-1))){
if(right){
p= ((char*)header->right_free)-t+1;
/*31:*/
#line 806 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= (void*)(((long long)p)&(~(a-1)));
offset= ((char*)p)-((char*)new_p);
p= new_p;
}
/*:31*/
#line 850 "./weaver-memory-manager.tex"

header->right_free= (char*)p-1;
}
else{
p= header->left_free;
/*30:*/
#line 788 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= ((char*)p)+(a-1);
new_p= (void*)(((long long)new_p)&(~(a-1)));
offset= ((char*)new_p)-((char*)p);
p= new_p;
}
/*:30*/
#line 855 "./weaver-memory-manager.tex"

header->left_free= (char*)p+t;
}
header->remaining_space-= (t+offset);
#if defined(W_DEBUG_MEMORY)
if(header->remaining_space<header->smallest_remaining_space)
header->smallest_remaining_space= header->remaining_space;
#endif
}
}
/*:32*/
#line 889 "./weaver-memory-manager.tex"

/*24:*/
#line 593 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_unlock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
LeaveCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:24*/
#line 890 "./weaver-memory-manager.tex"

return p;
}
/*:33*/
#line 911 "./weaver-memory-manager.tex"

/*:34*/
