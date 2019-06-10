/*1:*/
#line 185 "./weaver-memory-manager.tex"

#ifndef WEAVER_MEMORY_MANAGER
#define WEAVER_MEMORY_MANAGER
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 231 "./weaver-memory-manager.tex"

#include <stdlib.h>
void*Wcreate_arena(size_t size);
/*:2*//*3:*/
#line 241 "./weaver-memory-manager.tex"

#include <stdbool.h>
bool Wdestroy_arena(void*);
/*:3*//*4:*/
#line 258 "./weaver-memory-manager.tex"

#if W_DEBUG_MEMORY
void*_alloc_(void*arena,int flag,size_t size,char*filename,
unsigned long line);
#define Walloc(a, b, c) _alloc_(a, b, c, __FILE__, __LINE__)
#else
void*_alloc_(void*arena,int flag,size_t size);
#define Walloc(a, b, c) _alloc_(a, b, c)
#endif
/*:4*//*5:*/
#line 276 "./weaver-memory-manager.tex"

#if defined(W_DEBUG_MEMORY)
void _free_(void*mem,char*filename,unsigned long line);
#define Wfree(a) _free_(a, __FILE__, __LINE__)
#else
void*_free_(void*mem);
#define Wfree(a) _free_(a)
#endif
/*:5*//*6:*/
#line 295 "./weaver-memory-manager.tex"

bool Wbreakpoint(void*arena,int regiao);
/*:6*//*7:*/
#line 306 "./weaver-memory-manager.tex"

void Wtrash(void*arena,int regiao);
/*:7*/
#line 191 "./weaver-memory-manager.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
