/*1:*/
#line 139 "weaver_api.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
/*2:*/
#line 169 "weaver_api.tex"

#if !defined(_WIN32)
#include <sys/param.h> 
#else
#include <windows.h> 
#endif
/*:2*//*3:*/
#line 186 "weaver_api.tex"

#include <stdio.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <stdbool.h> 
/*:3*//*14:*/
#line 364 "weaver_api.tex"

#if !defined(_WIN32)
#include <sys/time.h> 
#endif
/*:14*//*42:*/
#line 1006 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:42*//*73:*/
#line 1516 "weaver_api.tex"

#include "window.h"
/*:73*//*85:*/
#line 1649 "weaver_api.tex"

#include "interface.h"
/*:85*/
#line 145 "weaver_api.tex"

/*6:*/
#line 251 "weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*22:*/
#line 653 "weaver_api.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:22*//*29:*/
#line 771 "weaver_api.tex"

unsigned long long t;
unsigned long dt;
/*:29*//*74:*/
#line 1526 "weaver_api.tex"

long*keyboard;
struct _Wmouse mouse;
/*:74*//*83:*/
#line 1618 "weaver_api.tex"

int width,height,resolution_x,resolution_y;
/*:83*/
#line 256 "weaver_api.tex"

/*57:*/
#line 1263 "weaver_api.tex"

void*(*alloc)(size_t);
/*:57*//*71:*/
#line 1494 "weaver_api.tex"

uint64_t(*rand)(void);
/*:71*//*98:*/
#line 1878 "weaver_api.tex"

struct user_interface*(*new_interface)(char*,char*,float,float,
float,float,float);
/*:98*//*99:*/
#line 1889 "weaver_api.tex"

struct user_interface*(*link_interface)(struct user_interface*);
void(*rotate_interface)(struct user_interface*,float);
void(*resize_interface)(struct user_interface*,float,float);
void(*move_interface)(struct user_interface*,float,float,float);
/*:99*/
#line 257 "weaver_api.tex"

}W;
/*:6*/
#line 146 "weaver_api.tex"

/*8:*/
#line 285 "weaver_api.tex"

void Winit(void);
/*:8*//*10:*/
#line 305 "weaver_api.tex"

void Wexit(void);
/*:10*//*16:*/
#line 389 "weaver_api.tex"

unsigned long _update_time(void);
/*:16*//*24:*/
#line 676 "weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:24*//*31:*/
#line 800 "weaver_api.tex"

void _update(void);
/*:31*//*34:*/
#line 862 "weaver_api.tex"

void _render(void);
/*:34*//*37:*/
#line 917 "weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:37*/
#line 147 "weaver_api.tex"

/*12:*/
#line 340 "weaver_api.tex"

#if defined(_WIN32)
extern LARGE_INTEGER _last_time;
#else
extern struct timeval _last_time;
#endif
/*:12*//*19:*/
#line 617 "weaver_api.tex"

extern bool _running_loop,_loop_begin,_loop_finalized;
/*:19*//*26:*/
#line 744 "weaver_api.tex"

extern unsigned long _lag;
/*:26*//*38:*/
#line 944 "weaver_api.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
extern int _number_of_loops;
extern void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:38*/
#line 148 "weaver_api.tex"

/*25:*/
#line 695 "weaver_api.tex"

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
#line 820 "weaver_api.tex"

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
#line 881 "weaver_api.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:36*//*46:*/
#line 1090 "weaver_api.tex"

#define Wexit_loop() (_running_loop =  false)
/*:46*//*48:*/
#line 1153 "weaver_api.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:48*//*53:*/
#line 1217 "weaver_api.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:53*/
#line 149 "weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
