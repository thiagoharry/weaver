/*1:*/
#line 141 "weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
#line 147 "weaver_api.tex"
/*2:*/
#line 171 "weaver_api.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#line 175 "weaver_api.tex"
#include <windows.h> 
#endif
#line 177 "weaver_api.tex"
/*:2*//*3:*/
#line 188 "weaver_api.tex"

#include <stdio.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <stdbool.h> 
/*:3*//*14:*/
#line 367 "weaver_api.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
#line 371 "weaver_api.tex"
/*:14*//*42:*/
#line 1008 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
#line 1012 "weaver_api.tex"
/*:42*//*74:*/
#line 1531 "weaver_api.tex"

#include "window.h"
/*:74*//*86:*/
#line 1664 "weaver_api.tex"

#include "interface.h"
/*:86*/
#line 147 "weaver_api.tex"

/*6:*/
#line 254 "weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*22:*/
#line 656 "weaver_api.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
#line 661 "weaver_api.tex"
 unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:22*//*29:*/
#line 774 "weaver_api.tex"

unsigned long long t;
unsigned long dt;
/*:29*//*75:*/
#line 1541 "weaver_api.tex"

long*keyboard;
struct _Wmouse mouse;
/*:75*//*84:*/
#line 1633 "weaver_api.tex"

int width,height,resolution_x,resolution_y;
/*:84*/
#line 259 "weaver_api.tex"

/*58:*/
#line 1275 "weaver_api.tex"

void*(*alloc)(size_t);
void*(*talloc)(size_t);
/*:58*//*72:*/
#line 1509 "weaver_api.tex"

uint64_t(*rand)(void);
/*:72*//*102:*/
#line 1957 "weaver_api.tex"

struct user_interface*(*new_interface)(char*,char*,float,float,
float,float,float);
struct sound*(*new_sound)(char*);
/*:102*//*103:*/
#line 1969 "weaver_api.tex"

struct user_interface*(*link_interface)(struct user_interface*);
void(*rotate_interface)(struct user_interface*,float);
void(*resize_interface)(struct user_interface*,float,float);
void(*move_interface)(struct user_interface*,float,float,float);
bool(*play_sound)(struct sound*);
/*:103*/
#line 260 "weaver_api.tex"

}W;
/*:6*/
#line 148 "weaver_api.tex"

/*8:*/
#line 288 "weaver_api.tex"

void Winit(void);
/*:8*//*10:*/
#line 308 "weaver_api.tex"

void Wexit(void);
/*:10*//*16:*/
#line 392 "weaver_api.tex"

unsigned long _update_time(void);
/*:16*//*24:*/
#line 679 "weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
#line 683 "weaver_api.tex"
 __declspec(noreturn)void _exit_loop(void);
#endif
#line 685 "weaver_api.tex"
/*:24*//*31:*/
#line 803 "weaver_api.tex"

void _update(void);
/*:31*//*34:*/
#line 865 "weaver_api.tex"

void _render(void);
/*:34*//*37:*/
#line 920 "weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
#line 925 "weaver_api.tex"
 __declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#line 928 "weaver_api.tex"
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:37*/
#line 149 "weaver_api.tex"

/*12:*/
#line 343 "weaver_api.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
#line 347 "weaver_api.tex"
 extern struct timeval _last_time;
#endif
#line 349 "weaver_api.tex"
/*:12*//*19:*/
#line 620 "weaver_api.tex"

extern bool _running_loop,_loop_begin,_loop_finalized;
/*:19*//*26:*/
#line 747 "weaver_api.tex"

extern unsigned long _lag;
/*:26*//*38:*/
#line 947 "weaver_api.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
#line 951 "weaver_api.tex"
 extern int _number_of_loops;
extern void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:38*/
#line 150 "weaver_api.tex"

/*25:*/
#line 698 "weaver_api.tex"

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
#line 823 "weaver_api.tex"

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
#line 884 "weaver_api.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:36*//*46:*/
#line 1091 "weaver_api.tex"

#define Wexit_loop() (_running_loop =  false)
/*:46*//*48:*/
#line 1153 "weaver_api.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
#line 1157 "weaver_api.tex"
/*:48*//*53:*/
#line 1217 "weaver_api.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
#line 1221 "weaver_api.tex"
/*:53*/
#line 151 "weaver_api.tex"

#ifdef __cplusplus
}
#endif
#line 155 "weaver_api.tex"
#endif
#line 156 "weaver_api.tex"
/*:1*/
