/*1:*/
#line 175 "./weaver-memory-manager.tex"

#ifndef WEAVER_MEMORY_MANAGER
#define WEAVER_MEMORY_MANAGER
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 221 "./weaver-memory-manager.tex"

#include <stdlib.h>  
void*Wcreate_arena(size_t size);
/*:2*//*3:*/
#line 232 "./weaver-memory-manager.tex"

#include <stdbool.h>  
bool Wdestroy_arena(void*);
/*:3*//*4:*/
#line 247 "./weaver-memory-manager.tex"

void*Walloc(void*arena,unsigned alignment,int right,size_t size);
/*:4*//*5:*/
#line 261 "./weaver-memory-manager.tex"

bool Wmempoint(void*arena,unsigned alignment,int regiao);
/*:5*//*6:*/
#line 272 "./weaver-memory-manager.tex"

void Wtrash(void*arena,int regiao);
/*:6*/
#line 181 "./weaver-memory-manager.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
