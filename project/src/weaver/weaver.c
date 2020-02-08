/*3:*/
#line 188 "./weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*4:*/
#line 202 "./weaver_api.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 321 "./weaver_api.tex"

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
#line 363 "./weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev= _last_time;
QueryPerformanceCounter(&_last_time);
return(_last_time-prev);
}
#endif
/*:14*//*36:*/
#line 905 "./weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*38:*/
#line 941 "./weaver_api.tex"

_running_loop= true;
_update_time();
/*:38*/
#line 910 "./weaver_api.tex"

/*42:*/
#line 1016 "./weaver_api.tex"

/*:42*/
#line 911 "./weaver_api.tex"

if(_number_of_loops>=W_MAX_SUBLOOP){
fprintf(stderr,"Error: Max number of subloops achieved.\n");
fprintf(stderr,"Please, increase W_MAX_SUBLOOP in conf/conf.h"
" to a value bigger than %d.\n",W_MAX_SUBLOOP);
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
#line 988 "./weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1)
Wexit();
else{
/*43:*/
#line 1021 "./weaver_api.tex"

/*:43*/
#line 993 "./weaver_api.tex"

_number_of_loops--;
/*38:*/
#line 941 "./weaver_api.tex"

_running_loop= true;
_update_time();
/*:38*/
#line 995 "./weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops],0,1);
#else
while(1)
_loop_stack[_number_of_loops]();
#endif
}
}
/*:41*/
#line 191 "./weaver_api.tex"

/*44:*/
#line 1026 "./weaver_api.tex"

/*:44*/
#line 192 "./weaver_api.tex"

/*6:*/
#line 225 "./weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 294 "./weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 546 "./weaver_api.tex"

_running_loop= false;
_loop_begin= false;
/*:16*//*18:*/
#line 574 "./weaver_api.tex"

W.pending_files= 0;
W.loop_name= NULL;
/*:18*//*22:*/
#line 653 "./weaver_api.tex"

_lag= 0;
/*:22*//*24:*/
#line 681 "./weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 851 "./weaver_api.tex"

_number_of_loops= 0;
/*:33*/
#line 228 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 244 "./weaver_api.tex"

void Wexit(void){

exit(0);
}
/*:8*//*26:*/
#line 703 "./weaver_api.tex"

void _update(void){
/*45:*/
#line 1031 "./weaver_api.tex"

/*:45*/
#line 705 "./weaver_api.tex"

}
/*:26*//*29:*/
#line 764 "./weaver_api.tex"

void _render(void){
/*46:*/
#line 1036 "./weaver_api.tex"

/*:46*/
#line 766 "./weaver_api.tex"

}
/*:29*//*34:*/
#line 867 "./weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*35:*/
#line 892 "./weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:35*/
#line 870 "./weaver_api.tex"

_number_of_loops--;
}
/*38:*/
#line 941 "./weaver_api.tex"

_running_loop= true;
_update_time();
/*:38*/
#line 873 "./weaver_api.tex"

/*47:*/
#line 1041 "./weaver_api.tex"

/*:47*/
#line 874 "./weaver_api.tex"

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
#line 193 "./weaver_api.tex"

/*:3*/
