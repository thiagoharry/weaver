/*1:*/
#line 125 "weaver_api_en.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 155 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#include <windows.h> 
#endif
/*:2*//*3:*/
#line 171 "weaver_api_en.tex"

#include <stdio.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <stdbool.h> 
/*:3*//*13:*/
#line 317 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
/*:13*//*41:*/
#line 926 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:41*/
#line 131 "weaver_api_en.tex"

/*5:*/
#line 207 "weaver_api_en.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*21:*/
#line 593 "weaver_api_en.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:21*//*28:*/
#line 708 "weaver_api_en.tex"

unsigned long long t;
unsigned long dt;
/*:28*//*76:*/
#line 1454 "weaver_api_en.tex"

long*keyboard;
struct __Wmouse*mouse;
/*:76*//*81:*/
#line 1512 "weaver_api_en.tex"

int width,height,resolution_x,resolution_y;
/*:81*/
#line 212 "weaver_api_en.tex"

/*56:*/
#line 1175 "weaver_api_en.tex"

void*(*alloc)(size_t);
/*:56*//*70:*/
#line 1400 "weaver_api_en.tex"

uint64_t(*rand)(void);
/*:70*/
#line 213 "weaver_api_en.tex"

}W;
/*:5*/
#line 132 "weaver_api_en.tex"

/*7:*/
#line 240 "weaver_api_en.tex"

void Winit(void);
/*:7*//*9:*/
#line 260 "weaver_api_en.tex"

void Wexit(void);
/*:9*//*15:*/
#line 341 "weaver_api_en.tex"

unsigned long _update_time(void);
/*:15*//*23:*/
#line 616 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:23*//*30:*/
#line 735 "weaver_api_en.tex"

void _update(void);
/*:30*//*33:*/
#line 790 "weaver_api_en.tex"

void _render(void);
/*:33*//*36:*/
#line 841 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:36*/
#line 133 "weaver_api_en.tex"

/*11:*/
#line 293 "weaver_api_en.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
extern struct timeval _last_time;
#endif
/*:11*//*18:*/
#line 560 "weaver_api_en.tex"

extern bool _running_loop,_loop_begin,_loop_finalized;
/*:18*//*25:*/
#line 680 "weaver_api_en.tex"

unsigned long _lag;
/*:25*//*37:*/
#line 868 "weaver_api_en.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
extern int _number_of_loops;
extern void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:37*/
#line 134 "weaver_api_en.tex"

/*47:*/
#line 1069 "weaver_api_en.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:47*//*52:*/
#line 1129 "weaver_api_en.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:52*//*72:*/
#line 1420 "weaver_api_en.tex"

#include "window.h"
/*:72*//*83:*/
#line 1543 "weaver_api_en.tex"

#include "interface.h"
/*:83*/
#line 135 "weaver_api_en.tex"

/*89:*/
#line 1595 "weaver_api_en.tex"
/*:89*/
#line 136 "weaver_api_en.tex"

/*24:*/
#line 635 "weaver_api_en.tex"

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
/*:24*//*32:*/
#line 754 "weaver_api_en.tex"

#define LOOP_BODY                                            \
  _loop_begin =   false;                                      \
  if(_loop_begin)                                            \
    goto _BEGIN_LOOP_INITIALIZATION;                         \
_END_LOOP_INITIALIZATION:                                    \
  _lag +=  _update_time();                                    \
  while(_lag >= W.dt){                                       \
    _update();                                               \
_LABEL_0
/*:32*//*35:*/
#line 808 "weaver_api_en.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:35*//*45:*/
#line 1007 "weaver_api_en.tex"

#define Wexit_loop() (_running_loop =  false)
/*:45*/
#line 137 "weaver_api_en.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
