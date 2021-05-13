/*1:*/
#line 138 "weaver_api.tex"

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
#line 168 "weaver_api.tex"



extern struct _weaver_struct{
struct _game_struct*game;
/*17:*/
#line 573 "weaver_api.tex"


#if !defined(W_MAX_LOOP_NAME)
#define W_MAX_LOOP_NAME 64
#endif
unsigned pending_files;
char loop_name[W_MAX_LOOP_NAME];
/*:17*//*23:*/
#line 685 "weaver_api.tex"

unsigned long long t;
unsigned long dt;
/*:23*/
#line 173 "weaver_api.tex"

/*52:*/
#line 1183 "weaver_api.tex"

void*(*alloc)(size_t);
/*:52*//*66:*/
#line 1414 "weaver_api.tex"

uint64_t(*rand)(void);
/*:66*/
#line 174 "weaver_api.tex"

}W;
/*:2*/
#line 149 "weaver_api.tex"

/*5:*/
#line 224 "weaver_api.tex"

void Winit(void);
/*:5*//*7:*/
#line 244 "weaver_api.tex"

void Wexit(void);
/*:7*//*9:*/
#line 262 "weaver_api.tex"

#include <stdlib.h> 
/*:9*//*10:*/
#line 287 "weaver_api.tex"

#if defined(_WIN32)
#include <windows.h> 
LARGE_INTEGER _last_time;
#else
#include <sys/time.h> 
struct timeval _last_time;
#endif
/*:10*//*12:*/
#line 316 "weaver_api.tex"

unsigned long _update_time(void);
/*:12*//*15:*/
#line 544 "weaver_api.tex"

#include <stdbool.h> 
bool _running_loop,_loop_begin,_loop_finalized;
/*:15*//*19:*/
#line 596 "weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif


/*:19*//*20:*/
#line 617 "weaver_api.tex"

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
#line 666 "weaver_api.tex"

unsigned long _lag;
/*:21*//*25:*/
#line 714 "weaver_api.tex"

void _update(void);
/*:25*//*27:*/
#line 734 "weaver_api.tex"

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
#line 776 "weaver_api.tex"

void _render(void);
/*:28*//*30:*/
#line 795 "weaver_api.tex"

#define LOOP_END                                           \
    _lag -=   40000;                                        \
    W.t +=   40000;                                         \
  }                                                        \
  _render();                                               \
  return;                                                  \
  goto _LABEL_0;                                           \
_LOOP_FINALIZATION
/*:30*//*31:*/
#line 831 "weaver_api.tex"

#if !defined(_MSC_VER)
void _Wloop(void(*f)(void))__attribute__((noreturn));
void Wsubloop(void(*f)(void))__attribute__((noreturn));
#else
__declspec(noreturn)void _Wloop(void(*f)(void));
__declspec(noreturn)void Wsubloop(void(*f)(void));
#endif
#define Wloop(a) ((W.pending_files)?(false):(_Wloop(a)))
/*:31*//*32:*/
#line 858 "weaver_api.tex"

#if !defined(W_MAX_SUBLOOP)
#define W_MAX_SUBLOOP 3
#endif
int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:32*//*38:*/
#line 962 "weaver_api.tex"

#include <stdio.h> 
/*:38*//*40:*/
#line 1000 "weaver_api.tex"

#define Wexit_loop() (_running_loop =  false)
/*:40*//*41:*/
#line 1011 "weaver_api.tex"

#if !defined(_MSC_VER)
void _exit_loop(void)__attribute__((noreturn));
#else
__declspec(noreturn)void _exit_loop(void);
#endif
/*:41*//*43:*/
#line 1073 "weaver_api.tex"

#ifndef W_MAX_MEMORY
#define W_MAX_MEMORY 4096
#endif
/*:43*//*48:*/
#line 1137 "weaver_api.tex"

#ifndef W_MEMORY_ALIGNMENT
#define W_MEMORY_ALIGNMENT (sizeof(unsigned long))
#endif
/*:48*/
#line 150 "weaver_api.tex"

/*73:*/
#line 1463 "weaver_api.tex"

/*:73*/
#line 151 "weaver_api.tex"

#ifdef __cplusplus
}
#endif
#endif
/*:1*/
