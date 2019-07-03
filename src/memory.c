/*39:*/
#line 1082 "./weaver-memory-manager.tex"

/*7:*/
#line 312 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
#include <sys/mman.h> 
#endif
/*:7*//*12:*/
#line 390 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>   
#include <memoryapi.h>  
#endif
/*:12*//*15:*/
#line 444 "./weaver-memory-manager.tex"

#if defined(__APPLE__) || defined(__unix__)
#include <unistd.h> 
#endif
/*:15*//*17:*/
#line 472 "./weaver-memory-manager.tex"

#if defined(_WIN32)
#include <windows.h>  
#endif
/*:17*//*19:*/
#line 525 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h> 
#endif
/*:19*//*29:*/
#line 778 "./weaver-memory-manager.tex"

#if defined(W_DEBUG_MEMORY)
#include <stdio.h> 
#endif
/*:29*//*31:*/
#line 820 "./weaver-memory-manager.tex"

#include <stdint.h> 
/*:31*/
#line 1083 "./weaver-memory-manager.tex"

#include "memory.h"
/*25:*/
#line 639 "./weaver-memory-manager.tex"

struct arena_header{
/*20:*/
#line 535 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_t mutex;
#endif
#if defined(_WIN32)
CRITICAL_SECTION mutex;
#endif
/*:20*/
#line 641 "./weaver-memory-manager.tex"

void*left_free,*right_free;
void*left_point,*right_point;
size_t remaining_space,total_size,right_allocations,left_allocations;
#if defined(W_DEBUG_MEMORY)
size_t smallest_remaining_space;
#endif
};
/*:25*/
#line 1085 "./weaver-memory-manager.tex"

/*36:*/
#line 981 "./weaver-memory-manager.tex"

struct memory_point{
size_t allocations;
struct memory_point*last_memory_point;
};
/*:36*/
#line 1086 "./weaver-memory-manager.tex"

/*27:*/
#line 712 "./weaver-memory-manager.tex"

void*Wcreate_arena(size_t t){
bool error= false;
void*arena;
size_t p,M,header_size= sizeof(struct arena_header);

/*13:*/
#line 418 "./weaver-memory-manager.tex"

#if defined(__unix__)
p= sysconf(_SC_PAGESIZE);
#endif
/*:13*//*14:*/
#line 433 "./weaver-memory-manager.tex"

#if defined(__APPLE__)
p= getpagesize();
#endif
/*:14*//*16:*/
#line 457 "./weaver-memory-manager.tex"

#if defined(_WIN32)
{
SYSTEM_INFO info;
GetSystemInfo(&info);
p= info.dwPageSize;
}
#endif
/*:16*//*18:*/
#line 489 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__)
p= 64*1024;
#endif
/*:18*/
#line 718 "./weaver-memory-manager.tex"


M= (((t-1)/p)+1)*p;
if(M<header_size)
M= (((header_size-1)/p)+1)*p;

/*8:*/
#line 325 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
arena= mmap(NULL,M,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,
-1,0);
#endif
/*:8*//*10:*/
#line 361 "./weaver-memory-manager.tex"

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
#line 724 "./weaver-memory-manager.tex"


/*26:*/
#line 664 "./weaver-memory-manager.tex"

{
struct arena_header*header= (struct arena_header*)arena;
header->right_free= ((char*)header)+M-1;
header->left_free= ((char*)header)+sizeof(struct arena_header);
header->remaining_space= M-sizeof(struct arena_header);
header->right_allocations= 0;
header->left_allocations= 0;
header->total_size= M;
header->left_point= NULL;
header->right_point= NULL;
#if defined(W_DEBUG_MEMORY)
header->smallest_remaining_space= header->remaining_space;
#endif
{
void*mutex= &(header->mutex);
/*21:*/
#line 553 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
error= pthread_mutex_init((pthread_mutex_t*)mutex,NULL);
#endif
#if defined(_WIN32)
InitializeCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:21*/
#line 680 "./weaver-memory-manager.tex"

}
}
/*:26*/
#line 726 "./weaver-memory-manager.tex"


if(error)return NULL;
return arena;
}
/*:27*/
#line 1087 "./weaver-memory-manager.tex"

/*28:*/
#line 752 "./weaver-memory-manager.tex"

bool Wdestroy_arena(void*arena){
struct arena_header*header= (struct arena_header*)arena;
void*mutex= (void*)&(header->mutex);
size_t M= header->total_size;
bool ret= true;
/*22:*/
#line 567 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_destroy((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
DeleteCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:22*/
#line 758 "./weaver-memory-manager.tex"

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
#line 342 "./weaver-memory-manager.tex"

#if defined(__EMSCRIPTEN__) || defined(__unix__) || defined(__APPLE__)
munmap(arena,M);
#endif
/*:9*//*11:*/
#line 380 "./weaver-memory-manager.tex"

#if defined(_WIN32)
UnmapViewOfFile(arena);
#endif
/*:11*/
#line 768 "./weaver-memory-manager.tex"

return ret;
}
/*:28*/
#line 1088 "./weaver-memory-manager.tex"

/*34:*/
#line 915 "./weaver-memory-manager.tex"

void*Walloc(void*arena,unsigned a,int right,size_t t){
struct arena_header*header= (struct arena_header*)arena;
void*mutex= (void*)&(header->mutex);
void*p= NULL;
/*23:*/
#line 580 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_lock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
EnterCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:23*/
#line 920 "./weaver-memory-manager.tex"

/*33:*/
#line 873 "./weaver-memory-manager.tex"

{
int offset;
struct arena_header*header= (struct arena_header*)arena;
if(header->remaining_space>=t+((a==0)?(0):(a-1))){
if(right){
p= ((char*)header->right_free)-t+1;
/*32:*/
#line 833 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= (void*)(((uintptr_t)p)&(~((uintptr_t)a-1)));
offset= ((char*)p)-((char*)new_p);
p= new_p;
}
/*:32*/
#line 880 "./weaver-memory-manager.tex"

header->right_free= (char*)p-1;
header->right_allocations+= (t+offset);
}
else{
p= header->left_free;
/*30:*/
#line 804 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= ((char*)p)+(a-1);
new_p= (void*)(((uintptr_t)new_p)&(~((uintptr_t)a-1)));
offset= ((char*)new_p)-((char*)p);
p= new_p;
}
/*:30*/
#line 886 "./weaver-memory-manager.tex"

header->left_free= (char*)p+t;
header->left_allocations+= (t+offset);
}
header->remaining_space-= (t+offset);
#if defined(W_DEBUG_MEMORY)
if(header->remaining_space<header->smallest_remaining_space)
header->smallest_remaining_space= header->remaining_space;
#endif
}
}
/*:33*/
#line 921 "./weaver-memory-manager.tex"

/*24:*/
#line 594 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_unlock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
LeaveCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:24*/
#line 922 "./weaver-memory-manager.tex"

return p;
}
/*:34*/
#line 1089 "./weaver-memory-manager.tex"

/*37:*/
#line 999 "./weaver-memory-manager.tex"

bool Wmempoint(void*arena,unsigned a,int right){
struct arena_header*header= (struct arena_header*)arena;
void*mutex= (void*)&(header->mutex);
char*p= NULL;
struct memory_point*point;
size_t allocations,t= sizeof(struct memory_point);
/*23:*/
#line 580 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_lock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
EnterCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:23*/
#line 1006 "./weaver-memory-manager.tex"

if(right)
allocations= header->right_allocations;
else
allocations= header->left_allocations;
/*33:*/
#line 873 "./weaver-memory-manager.tex"

{
int offset;
struct arena_header*header= (struct arena_header*)arena;
if(header->remaining_space>=t+((a==0)?(0):(a-1))){
if(right){
p= ((char*)header->right_free)-t+1;
/*32:*/
#line 833 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= (void*)(((uintptr_t)p)&(~((uintptr_t)a-1)));
offset= ((char*)p)-((char*)new_p);
p= new_p;
}
/*:32*/
#line 880 "./weaver-memory-manager.tex"

header->right_free= (char*)p-1;
header->right_allocations+= (t+offset);
}
else{
p= header->left_free;
/*30:*/
#line 804 "./weaver-memory-manager.tex"

offset= 0;
if(a> 1){
void*new_p= ((char*)p)+(a-1);
new_p= (void*)(((uintptr_t)new_p)&(~((uintptr_t)a-1)));
offset= ((char*)new_p)-((char*)p);
p= new_p;
}
/*:30*/
#line 886 "./weaver-memory-manager.tex"

header->left_free= (char*)p+t;
header->left_allocations+= (t+offset);
}
header->remaining_space-= (t+offset);
#if defined(W_DEBUG_MEMORY)
if(header->remaining_space<header->smallest_remaining_space)
header->smallest_remaining_space= header->remaining_space;
#endif
}
}
/*:33*/
#line 1011 "./weaver-memory-manager.tex"

point= (struct memory_point*)p;
if(point!=NULL){
point->allocations= allocations;
if(right){
point->last_memory_point= header->right_point;
header->right_point= point;
}
else{
point->last_memory_point= header->left_point;
header->left_point= point;
}
}
/*24:*/
#line 594 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_unlock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
LeaveCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:24*/
#line 1024 "./weaver-memory-manager.tex"

if(point==NULL)
return false;
return true;
}
/*:37*/
#line 1090 "./weaver-memory-manager.tex"

/*38:*/
#line 1041 "./weaver-memory-manager.tex"

void Wtrash(void*arena,int right){
struct arena_header*head= (struct arena_header*)arena;
void*mutex= (void*)&(head->mutex);
struct memory_point*point;
/*23:*/
#line 580 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_lock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
EnterCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:23*/
#line 1046 "./weaver-memory-manager.tex"

if(right){
point= head->right_point;
}
else{
point= head->left_point;
}
if(point==NULL){
/*35:*/
#line 945 "./weaver-memory-manager.tex"

{
struct arena_header*header= arena;
if(right){
header->right_free= ((char*)arena)+header->total_size-1;
header->remaining_space+= header->right_allocations;
header->right_allocations= 0;
}
else{
header->left_free= ((char*)arena)+sizeof(struct arena_header);
header->remaining_space+= header->left_allocations;
header->left_allocations= 0;
}
}
/*:35*/
#line 1054 "./weaver-memory-manager.tex"

}
else{
if(right){
head->remaining_space+= (head->right_allocations-
point->allocations);
head->right_point= point->last_memory_point;
head->right_allocations= point->allocations;
}
else{
head->remaining_space+= (head->left_allocations-
point->allocations);
head->left_point= point->last_memory_point;
head->left_allocations= point->allocations;
}
}
/*24:*/
#line 594 "./weaver-memory-manager.tex"

#if defined(__unix__) || defined(__APPLE__)
pthread_mutex_unlock((pthread_mutex_t*)mutex);
#endif
#if defined(_WIN32)
LeaveCriticalSection((CRITICAL_SECTION*)mutex);
#endif
/*:24*/
#line 1070 "./weaver-memory-manager.tex"

}
/*:38*/
#line 1091 "./weaver-memory-manager.tex"

/*:39*/
