/*1:*/
#line 140 "./weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
#include "../../conf/conf.h"
/*2:*/
#line 170 "./weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*17:*/
#line 573 "./weaver_api.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:17*//*23:*/
#line 678 "./weaver_api.tex"

unsigned long long t;
unsigned long dt;
/*:23*/
#line 175 "./weaver_api.tex"


}W;
/*:2*/
#line 147 "./weaver_api.tex"

/*5:*/
#line 224 "./weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 243 "./weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 260 "./weaver_api.tex"

#include <stdlib.h> 
/*:9*//*10:*/
#line 285 "./weaver_api.tex"

#if defined(_WIN32)
#include <windows.h> 
LARGE_INTEGER _last_time;
#else
#include <sys/time.h> 
struct timeval _last_time;
#endif
/*:10*//*12:*/
#line 314 "./weaver_api.tex"

unsigned long _update_time(void);
/*:12*//*15:*/
#line 545 "./weaver_api.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin;
/*:15*//*19:*/
#line 596 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:19*//*20:*/
#line 615 "./weaver_api.tex"

#define LOOP_INIT                                                   \
  if(!_running_loop && !W.pending_files)                             \
    _exit_loop();                                                    \
  if(!_running_loop)                                                 \
   goto _LOOP_FINALIZATION;                                          \
  if(!_loop_begin)                                                   \
    goto _END_LOOP_INITIALIZATION;                                   \
  snprintf(W.loop_name, W_MAX_LOOP_NAME, "%s", __func__);            \
  _BEGIN_LOOP_INITIALIZATION
/*:20*//*21:*/
#line 659 "./weaver_api.tex"

unsigned long _lag;
/*:21*//*25:*/
#line 707 "./weaver_api.tex"

void _update(void);
/*:25*//*27:*/
#line 727 "./weaver_api.tex"

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
#line 768 "./weaver_api.tex"

void _render(void);
/*:28*//*30:*/
#line 787 "./weaver_api.tex"

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
#line 825 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:31*//*32:*/
#line 852 "./weaver_api.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:32*//*37:*/
#line 945 "./weaver_api.tex"

#include <stdio.h> 
/*:37*//*39:*/
#line 980 "./weaver_api.tex"

#define Wexit_loop() (_running_loop =  false)
/*:39*//*40:*/
#line 991 "./weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:40*/
#line 148 "./weaver_api.tex"

/*48:*/
#line 1065 "./weaver_api.tex"

/*:48*/
#line 149 "./weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
