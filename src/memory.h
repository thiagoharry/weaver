/*1:*/
#line 176 "./weaver-memory-manager.tex"

#ifndef WEAVER_MEMORY_MANAGER
#define WEAVER_MEMORY_MANAGER
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 222 "./weaver-memory-manager.tex"

#include <stdlib.h>  
void*_Wcreate_arena(size_t size);
/*:2*//*3:*/
#line 233 "./weaver-memory-manager.tex"

#include <stdbool.h>  
bool _Wdestroy_arena(void*);
/*:3*//*4:*/
#line 248 "./weaver-memory-manager.tex"

void*_Walloc(void*arena,unsigned alignment,int right,size_t size);
/*:4*//*5:*/
#line 262 "./weaver-memory-manager.tex"

bool _Wmempoint(void*arena,unsigned alignment,int regiao);
/*:5*//*6:*/
#line 273 "./weaver-memory-manager.tex"

void _Wtrash(void*arena,int regiao);
/*:6*/
#line 182 "./weaver-memory-manager.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
