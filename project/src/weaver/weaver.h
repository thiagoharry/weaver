/*1:*/
#line 125 "weaver_api_en.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 154 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#include <windows.h> 
#endif
/*:2*//*3:*/
#line 170 "weaver_api_en.tex"

#include <stdlib.h> 
#include <stdint.h> 
/*:3*//*13:*/
#line 314 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
/*:13*/
#line 131 "weaver_api_en.tex"

/*5:*/
#line 204 "weaver_api_en.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*20:*/
#line 582 "weaver_api_en.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:20*//*26:*/
#line 689 "weaver_api_en.tex"

unsigned long long t;
unsigned long dt;
/*:26*//*75:*/
#line 1442 "weaver_api_en.tex"

long*keyboard;
struct __Wmouse*mouse;
/*:75*//*80:*/
#line 1500 "weaver_api_en.tex"

int width,height,resolution_x,resolution_y;
/*:80*/
#line 209 "weaver_api_en.tex"

/*55:*/
#line 1164 "weaver_api_en.tex"

void*(*alloc)(size_t);
/*:55*//*69:*/
#line 1388 "weaver_api_en.tex"

uint64_t(*rand)(void);
/*:69*/
#line 210 "weaver_api_en.tex"

}W;
/*:5*/
#line 132 "weaver_api_en.tex"

/*7:*/
#line 237 "weaver_api_en.tex"

void Winit(void);
/*:7*//*9:*/
#line 257 "weaver_api_en.tex"

void Wexit(void);
/*:9*/
#line 133 "weaver_api_en.tex"

/*11:*/
#line 290 "weaver_api_en.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
extern struct timeval _last_time;
#endif
/*:11*/
#line 134 "weaver_api_en.tex"

/*15:*/
#line 338 "weaver_api_en.tex"

unsigned long _update_time(void);
/*:15*//*18:*/
#line 556 "weaver_api_en.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin,_loop_finalized;
/*:18*//*22:*/
#line 606 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:22*//*23:*/
#line 625 "weaver_api_en.tex"

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
/*:23*//*24:*/
#line 670 "weaver_api_en.tex"

unsigned long _lag;
/*:24*//*28:*/
#line 716 "weaver_api_en.tex"

void _update(void);
/*:28*//*30:*/
#line 735 "weaver_api_en.tex"

#define LOOP_BODY                                            \
  _loop_begin =   false;                                      \
  if(_loop_begin)                                            \
    goto _BEGIN_LOOP_INITIALIZATION;                         \
_END_LOOP_INITIALIZATION:                                    \
  _lag +=  _update_time();                                    \
  while(_lag >= W.dt){                                       \
    _update();                                               \
_LABEL_0
/*:30*//*31:*/
#line 771 "weaver_api_en.tex"

void _render(void);
/*:31*//*33:*/
#line 789 "weaver_api_en.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:33*//*34:*/
#line 822 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:34*//*35:*/
#line 849 "weaver_api_en.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:35*//*41:*/
#line 951 "weaver_api_en.tex"

#include <stdio.h> 
/*:41*//*43:*/
#line 986 "weaver_api_en.tex"

#define Wexit_loop() (_running_loop =  false)
/*:43*//*44:*/
#line 996 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:44*//*46:*/
#line 1058 "weaver_api_en.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:46*//*51:*/
#line 1118 "weaver_api_en.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:51*//*71:*/
#line 1408 "weaver_api_en.tex"

#include "window.h"
/*:71*//*82:*/
#line 1531 "weaver_api_en.tex"

#include "interface.h"
/*:82*/
#line 135 "weaver_api_en.tex"

/*88:*/
#line 1583 "weaver_api_en.tex"
/*:88*/
#line 136 "weaver_api_en.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
