/*1:*/
#line 125 "weaver_api_en.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
#line 131 "weaver_api_en.tex"
/*2:*/
#line 153 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#line 157 "weaver_api_en.tex"
#include <windows.h> 
#endif
#line 159 "weaver_api_en.tex"
/*:2*//*3:*/
#line 169 "weaver_api_en.tex"

#include <stdio.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <stdbool.h> 
/*:3*//*14:*/
#line 345 "weaver_api_en.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
#line 349 "weaver_api_en.tex"
/*:14*//*42:*/
#line 956 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
#line 960 "weaver_api_en.tex"
/*:42*//*74:*/
#line 1464 "weaver_api_en.tex"

#include "window.h"
/*:74*//*86:*/
#line 1595 "weaver_api_en.tex"

#include "interface.h"
/*:86*/
#line 131 "weaver_api_en.tex"

/*6:*/
#line 235 "weaver_api_en.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*22:*/
#line 621 "weaver_api_en.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
#line 626 "weaver_api_en.tex"
 unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:22*//*29:*/
#line 736 "weaver_api_en.tex"

unsigned long long t;
unsigned long dt;
/*:29*//*75:*/
#line 1474 "weaver_api_en.tex"

long*keyboard;
struct _Wmouse mouse;
/*:75*//*84:*/
#line 1564 "weaver_api_en.tex"

int width,height,resolution_x,resolution_y;
/*:84*/
#line 240 "weaver_api_en.tex"

/*58:*/
#line 1215 "weaver_api_en.tex"

void*(*alloc)(size_t);
void*(*talloc)(size_t);
/*:58*//*72:*/
#line 1444 "weaver_api_en.tex"

uint64_t(*rand)(void);
/*:72*//*99:*/
#line 1826 "weaver_api_en.tex"

struct user_interface*(*new_interface)(char*,char*,float,float,
float,float,float);
/*:99*//*100:*/
#line 1837 "weaver_api_en.tex"

struct user_interface*(*link_interface)(struct user_interface*);
void(*rotate_interface)(struct user_interface*,float);
void(*resize_interface)(struct user_interface*,float,float);
void(*move_interface)(struct user_interface*,float,float,float);
/*:100*/
#line 241 "weaver_api_en.tex"

}W;
/*:6*/
#line 132 "weaver_api_en.tex"

/*8:*/
#line 268 "weaver_api_en.tex"

void Winit(void);
/*:8*//*10:*/
#line 288 "weaver_api_en.tex"

void Wexit(void);
/*:10*//*16:*/
#line 369 "weaver_api_en.tex"

unsigned long _update_time(void);
/*:16*//*24:*/
#line 644 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
#line 648 "weaver_api_en.tex"
 __declspec(noreturn)void _exit_loop(void);
#endif
#line 650 "weaver_api_en.tex"
/*:24*//*31:*/
#line 763 "weaver_api_en.tex"

void _update(void);
/*:31*//*34:*/
#line 818 "weaver_api_en.tex"

void _render(void);
/*:34*//*37:*/
#line 869 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
#line 874 "weaver_api_en.tex"
 __declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#line 877 "weaver_api_en.tex"
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:37*/
#line 133 "weaver_api_en.tex"

/*12:*/
#line 321 "weaver_api_en.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
#line 325 "weaver_api_en.tex"
 extern struct timeval _last_time;
#endif
#line 327 "weaver_api_en.tex"
/*:12*//*19:*/
#line 588 "weaver_api_en.tex"

extern bool _running_loop,_loop_begin,_loop_finalized;
/*:19*//*26:*/
#line 708 "weaver_api_en.tex"

extern unsigned long _lag;
/*:26*//*38:*/
#line 896 "weaver_api_en.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
#line 900 "weaver_api_en.tex"
 extern int _number_of_loops;
extern void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:38*/
#line 134 "weaver_api_en.tex"

/*25:*/
#line 663 "weaver_api_en.tex"

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
#line 782 "weaver_api_en.tex"

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
#line 836 "weaver_api_en.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:36*//*46:*/
#line 1037 "weaver_api_en.tex"

#define Wexit_loop() (_running_loop =  false)
/*:46*//*48:*/
#line 1099 "weaver_api_en.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
#line 1103 "weaver_api_en.tex"
/*:48*//*53:*/
#line 1159 "weaver_api_en.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
#line 1163 "weaver_api_en.tex"
/*:53*/
#line 135 "weaver_api_en.tex"

#ifdef __cplusplus
}
#endif
#line 139 "weaver_api_en.tex"
#endif
#line 140 "weaver_api_en.tex"
/*:1*/
