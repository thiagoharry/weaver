/*3:*/
#line 192 "./weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*44:*/
#line 1081 "./weaver_api.tex"

#include "memory.h"
/*:44*/
#line 195 "./weaver_api.tex"

/*43:*/
#line 1072 "./weaver_api.tex"

static void*memory_arena;
/*:43*/
#line 196 "./weaver_api.tex"

/*4:*/
#line 208 "./weaver_api.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 329 "./weaver_api.tex"

#if !defined(_WIN32)
unsigned long _update_time(void){
int nsec;
unsigned long result;
struct timeval _current_time;
gettimeofday(&_current_time,NULL);

if(_current_time.tv_usec<_last_time.tv_usec){
nsec= (_last_time.tv_usec-_current_time.tv_usec)/1000000+1;
_last_time.tv_usec-= 1000000*nsec;
_last_time.tv_sec+= nsec;
}
if(_current_time.tv_usec-_last_time.tv_usec> 1000000){
nsec= (_current_time.tv_usec-_last_time.tv_usec)/1000000;
_last_time.tv_usec+= 1000000*nsec;
_last_time.tv_sec-= nsec;
}
if(_current_time.tv_sec<_last_time.tv_sec){

result= (_current_time.tv_sec-_last_time.tv_sec)*(-1000000);

result+= (_current_time.tv_usec-_last_time.tv_usec);
}
else{
result= (_current_time.tv_sec-_last_time.tv_sec)*1000000;
result+= (_current_time.tv_usec-_last_time.tv_usec);
}
_last_time.tv_sec= _current_time.tv_sec;
_last_time.tv_usec= _current_time.tv_usec;
return result;
}
#endif
/*:13*//*14:*/
#line 371 "./weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:14*//*36:*/
#line 923 "./weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*38:*/
#line 964 "./weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1136 "./weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 928 "./weaver_api.tex"

/*53:*/
#line 1193 "./weaver_api.tex"

/*:53*/
#line 929 "./weaver_api.tex"

if(_number_of_loops>=W_MAX_SUBLOOP){
fprintf(stderr,"Error: Max number of subloops achieved.\n");
fprintf(stderr,"Please, increase W_MAX_SUBLOOP in conf/conf.h"
" to a value bigger than %d.\n",W_MAX_SUBLOOP);
exit(1);
}
_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#else
while(1)
f();
#endif
}
/*:36*//*41:*/
#line 1013 "./weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*54:*/
#line 1198 "./weaver_api.tex"

/*:54*/
#line 1020 "./weaver_api.tex"

_number_of_loops--;
/*38:*/
#line 964 "./weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1136 "./weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 1022 "./weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#else
while(1)
_loop_stack[_number_of_loops-1]();
#endif
}
}
/*:41*/
#line 197 "./weaver_api.tex"

/*50:*/
#line 1159 "./weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:50*/
#line 198 "./weaver_api.tex"

/*6:*/
#line 231 "./weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 302 "./weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 552 "./weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:16*//*18:*/
#line 586 "./weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:18*//*22:*/
#line 672 "./weaver_api.tex"

_lag= 0;
/*:22*//*24:*/
#line 700 "./weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 869 "./weaver_api.tex"

_number_of_loops= 0;
/*:33*//*52:*/
#line 1179 "./weaver_api.tex"

W.alloc= _alloc;
/*:52*/
#line 234 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 250 "./weaver_api.tex"

void Wexit(void){
/*46:*/
#line 1104 "./weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:46*/
#line 252 "./weaver_api.tex"

exit(0);
}
/*:8*//*26:*/
#line 722 "./weaver_api.tex"

void _update(void){
/*55:*/
#line 1203 "./weaver_api.tex"

/*:55*/
#line 724 "./weaver_api.tex"

}
/*:26*//*29:*/
#line 784 "./weaver_api.tex"

void _render(void){
/*56:*/
#line 1208 "./weaver_api.tex"

/*:56*/
#line 786 "./weaver_api.tex"

}
/*:29*//*34:*/
#line 885 "./weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*35:*/
#line 910 "./weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:35*/
#line 888 "./weaver_api.tex"

_number_of_loops--;
}
/*38:*/
#line 964 "./weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1136 "./weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 891 "./weaver_api.tex"

/*57:*/
#line 1213 "./weaver_api.tex"

/*:57*/
#line 892 "./weaver_api.tex"

_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#else
while(1)
f();
#endif
}
/*:34*/
#line 199 "./weaver_api.tex"

/*:3*/
