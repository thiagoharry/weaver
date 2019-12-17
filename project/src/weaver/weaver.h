/*1:*/
#line 132 "./weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 155 "./weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*11:*/
#line 284 "./weaver_api.tex"


unsigned int pending_files;
/*:11*/
#line 160 "./weaver_api.tex"


}W;
/*:2*/
#line 138 "./weaver_api.tex"

/*5:*/
#line 207 "./weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 226 "./weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 243 "./weaver_api.tex"

#include <stdlib.h> 
/*:9*//*13:*/
#line 303 "./weaver_api.tex"

void _Wloop(void(*f)(void))__attribute__((noreturn));
/*:13*/
#line 139 "./weaver_api.tex"

/*10:*/
#line 275 "./weaver_api.tex"

#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:10*/
#line 140 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
