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
#line 563 "./weaver_api.tex"


unsigned pending_files;
const char*loop_name;
/*:17*//*23:*/
#line 665 "./weaver_api.tex"

unsigned long long t;
unsigned long dt;
/*:23*/
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
#line 537 "./weaver_api.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin;
/*:15*//*19:*/
#line 583 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:19*//*20:*/
#line 602 "./weaver_api.tex"

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
#line 646 "./weaver_api.tex"

unsigned long _lag;
/*:21*//*25:*/
#line 694 "./weaver_api.tex"

void _update(void);
/*:25*//*27:*/
#line 714 "./weaver_api.tex"

#define LOOP_BODY                                            \
  _loop_begin =   false;                                      \
  if(_loop_begin)                                            \
    goto _BEGIN_LOOP_INITIALIZATION;                         \
_END_LOOP_INITIALIZATION:                                    \
  _lag +=  _update_time();                                    \
  while(_lag >= W.dt){                                       \
    _update();                                               \
_LABEL_0
/*:27*//*28:*/
#line 755 "./weaver_api.tex"

void _render(void);
/*:28*//*30:*/
#line 774 "./weaver_api.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  if(_running_loop || W.pending_files)                     \
    return;                                                \
  if(W.t == 0)                                             \
    goto _LABEL_0;                                         \
_LOOP_FINALIZATION
/*:30*//*31:*/
#line 812 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:31*//*32:*/
#line 839 "./weaver_api.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:32*//*37:*/
#line 931 "./weaver_api.tex"

#include <stdio.h> 
/*:37*//*39:*/
#line 963 "./weaver_api.tex"

#define Wexit_loop() (_running_loop =  false)
/*:39*//*40:*/
#line 974 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:40*/
#line 147 "./weaver_api.tex"

/*48:*/
#line 1046 "./weaver_api.tex"

/*:48*/
#line 148 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
