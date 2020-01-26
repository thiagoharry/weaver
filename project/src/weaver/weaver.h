/*1:*/
#line 140 "./weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 163 "./weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*12:*/
#line 445 "./weaver_api.tex"


unsigned pending_files;
char*loop_name;
/*:12*//*15:*/
#line 488 "./weaver_api.tex"


unsigned int pending_files;
/*:15*/
#line 168 "./weaver_api.tex"


}W;
/*:2*/
#line 146 "./weaver_api.tex"

/*5:*/
#line 217 "./weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 236 "./weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 253 "./weaver_api.tex"

#include <stdlib.h> 
/*:9*//*10:*/
#line 420 "./weaver_api.tex"

bool _running_loop,_loop_begin;
/*:10*//*17:*/
#line 507 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
#endif
/*:17*/
#line 147 "./weaver_api.tex"

/*14:*/
#line 479 "./weaver_api.tex"

#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:14*/
#line 148 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
