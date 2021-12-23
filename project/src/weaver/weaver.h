/*1:*/
#line 125 "weaver_api_en.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 153 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#include <windows.h> 
#endif
/*:2*//*3:*/
#line 169 "weaver_api_en.tex"

#include <stdio.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <stdbool.h> 
/*:3*//*14:*/
#line 344 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
/*:14*//*42:*/
#line 953 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:42*//*73:*/
#line 1446 "weaver_api_en.tex"

#include "window.h"
/*:73*//*84:*/
#line 1569 "weaver_api_en.tex"

#include "interface.h"
/*:84*/
#line 131 "weaver_api_en.tex"

/*6:*/
#line 234 "weaver_api_en.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*22:*/
#line 620 "weaver_api_en.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:22*//*29:*/
#line 735 "weaver_api_en.tex"

unsigned long long t;
unsigned long dt;
/*:29*//*77:*/
#line 1480 "weaver_api_en.tex"

long*keyboard;
struct __Wmouse*mouse;
/*:77*//*82:*/
#line 1538 "weaver_api_en.tex"

int width,height,resolution_x,resolution_y;
/*:82*/
#line 239 "weaver_api_en.tex"

/*57:*/
#line 1201 "weaver_api_en.tex"

void*(*alloc)(size_t);
/*:57*//*71:*/
#line 1426 "weaver_api_en.tex"

uint64_t(*rand)(void);
/*:71*/
#line 240 "weaver_api_en.tex"

}W;
/*:6*/
#line 132 "weaver_api_en.tex"

/*8:*/
#line 267 "weaver_api_en.tex"

void Winit(void);
/*:8*//*10:*/
#line 287 "weaver_api_en.tex"

void Wexit(void);
/*:10*//*16:*/
#line 368 "weaver_api_en.tex"

unsigned long _update_time(void);
/*:16*//*24:*/
#line 643 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:24*//*31:*/
#line 762 "weaver_api_en.tex"

void _update(void);
/*:31*//*34:*/
#line 817 "weaver_api_en.tex"

void _render(void);
/*:34*//*37:*/
#line 868 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:37*/
#line 133 "weaver_api_en.tex"

/*12:*/
#line 320 "weaver_api_en.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
extern struct timeval _last_time;
#endif
/*:12*//*19:*/
#line 587 "weaver_api_en.tex"

extern bool _running_loop,_loop_begin,_loop_finalized;
/*:19*//*26:*/
#line 707 "weaver_api_en.tex"

unsigned long _lag;
/*:26*//*38:*/
#line 895 "weaver_api_en.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
extern int _number_of_loops;
extern void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:38*/
#line 134 "weaver_api_en.tex"

/*25:*/
#line 662 "weaver_api_en.tex"

#define LOOP_INIT                                                   \
  if(!_running_loop){                                               \
    if(W.pending_files)                                             \
      return;                                                       \
    if(!_loop_finalized){                                           \
      _loop_finalized =  true;                                       \
      goto _LOOP_FINALIZATION;                                      \
    }                                                              \
    _exit_loop();                                                   \
  }                                                                 \
  if(!_loop_begin)                                                   \
    goto _END_LOOP_INITIALIZATION;                                   \
  snprintf(W.loop_name, W_MAX_LOOP_NAME, "%s", __func__);            \
  _BEGIN_LOOP_INITIALIZATION
/*:25*//*33:*/
#line 781 "weaver_api_en.tex"

#define LOOP_BODY                                            \
  _loop_begin =   false;                                      \
  if(_loop_begin)                                            \
    goto _BEGIN_LOOP_INITIALIZATION;                         \
_END_LOOP_INITIALIZATION:                                    \
  _lag +=  _update_time();                                    \
  while(_lag >= W.dt){                                       \
    _update();                                               \
_LABEL_0
/*:33*//*36:*/
#line 835 "weaver_api_en.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:36*//*46:*/
#line 1034 "weaver_api_en.tex"

#define Wexit_loop() (_running_loop =  false)
/*:46*//*48:*/
#line 1096 "weaver_api_en.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:48*//*53:*/
#line 1156 "weaver_api_en.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:53*/
#line 135 "weaver_api_en.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
