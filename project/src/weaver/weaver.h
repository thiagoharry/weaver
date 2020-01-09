/*1:*/
#line 133 "./weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 156 "./weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*11:*/
#line 285 "./weaver_api.tex"


unsigned int pending_files;
/*:11*/
#line 161 "./weaver_api.tex"


}W;
/*:2*/
#line 139 "./weaver_api.tex"

/*5:*/
#line 208 "./weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 227 "./weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 244 "./weaver_api.tex"

#include <stdlib.h> 
/*:9*//*13:*/
#line 304 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
#endif
/*:13*/
#line 140 "./weaver_api.tex"

/*10:*/
#line 276 "./weaver_api.tex"

#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:10*/
#line 141 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
