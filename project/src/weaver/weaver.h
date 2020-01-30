/*1:*/
#line 140 "./weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 165 "./weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*17:*/
#line 559 "./weaver_api.tex"


unsigned pending_files;
char*loop_name;
/*:17*/
#line 170 "./weaver_api.tex"


}W;
/*:2*/
#line 146 "./weaver_api.tex"

/*5:*/
#line 219 "./weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 238 "./weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 255 "./weaver_api.tex"

#include <stdlib.h> 
/*:9*//*10:*/
#line 279 "./weaver_api.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
#include <sys/time.h> 
struct timeval _last_time;
#endif
/*:10*//*12:*/
#line 307 "./weaver_api.tex"

unsigned long _update_time(void);
/*:12*//*15:*/
#line 533 "./weaver_api.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin;
/*:15*//*19:*/
#line 579 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:19*//*20:*/
#line 598 "./weaver_api.tex"

#define LOOP_INIT                                                   \
  if(!_running_loop && !W.pending_files)                             \
    _exit_loop();                                                    \
  if(!_running_loop)                                                 \
   goto _LOOP_FINALIZATION;                                          \
  if(!_loop_begin)                                                   \
    goto _END_LOOP_INITIALIZATION;                                   \
  W.loop_name =  __func__;                                            \
  _BEGIN_LOOP_INITIALIZATION
/*:20*//*21:*/
#line 638 "./weaver_api.tex"

long _lag;
/*:21*//*24:*/
#line 683 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
#endif
/*:24*/
#line 147 "./weaver_api.tex"

/*23:*/
#line 666 "./weaver_api.tex"

#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:23*/
#line 148 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
