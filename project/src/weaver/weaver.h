/*1:*/
#line 125 "weaver_api_en.tex"

#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
extern"C"{
#endif
#if !defined(_WIN32)
#include <sys/param.h>  
#endif
#include <stdlib.h>  
#include <stdint.h> 
/*2:*/
#line 155 "weaver_api_en.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*17:*/
#line 544 "weaver_api_en.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:17*//*23:*/
#line 651 "weaver_api_en.tex"

unsigned long long t;
unsigned long dt;
/*:23*//*72:*/
#line 1402 "weaver_api_en.tex"

long*keyboard;
struct __Wmouse*mouse;
/*:72*/
#line 160 "weaver_api_en.tex"

/*52:*/
#line 1125 "weaver_api_en.tex"

void*(*alloc)(size_t);
/*:52*//*66:*/
#line 1349 "weaver_api_en.tex"

uint64_t(*rand)(void);
/*:66*/
#line 161 "weaver_api_en.tex"

}W;
/*:2*/
#line 136 "weaver_api_en.tex"

/*5:*/
#line 209 "weaver_api_en.tex"

void Winit(void);
/*:5*//*7:*/
#line 229 "weaver_api_en.tex"

void Wexit(void);
/*:7*//*9:*/
#line 248 "weaver_api_en.tex"

#include <stdlib.h> 
/*:9*//*10:*/
#line 272 "weaver_api_en.tex"

#if defined(_WIN32)
#include <windows.h> 
LARGE_INTEGER _last_time;
#else
#include <sys/time.h> 
struct timeval _last_time;
#endif
/*:10*//*12:*/
#line 300 "weaver_api_en.tex"

unsigned long _update_time(void);
/*:12*//*15:*/
#line 518 "weaver_api_en.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin,_loop_finalized;
/*:15*//*19:*/
#line 568 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:19*//*20:*/
#line 587 "weaver_api_en.tex"

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
/*:20*//*21:*/
#line 632 "weaver_api_en.tex"

unsigned long _lag;
/*:21*//*25:*/
#line 678 "weaver_api_en.tex"

void _update(void);
/*:25*//*27:*/
#line 697 "weaver_api_en.tex"

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
#line 733 "weaver_api_en.tex"

void _render(void);
/*:28*//*30:*/
#line 751 "weaver_api_en.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:30*//*31:*/
#line 784 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:31*//*32:*/
#line 811 "weaver_api_en.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:32*//*38:*/
#line 913 "weaver_api_en.tex"

#include <stdio.h> 
/*:38*//*40:*/
#line 948 "weaver_api_en.tex"

#define Wexit_loop() (_running_loop =  false)
/*:40*//*41:*/
#line 958 "weaver_api_en.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:41*//*43:*/
#line 1020 "weaver_api_en.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:43*//*48:*/
#line 1080 "weaver_api_en.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:48*/
#line 137 "weaver_api_en.tex"

/*79:*/
#line 1457 "weaver_api_en.tex"
/*:79*/
#line 138 "weaver_api_en.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
