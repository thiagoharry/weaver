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
/*:14*/
#line 191 "./weaver_api.tex"


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
#line 542 "./weaver_api.tex"

_running_loop= false;
_loop_begin= false;
/*:16*//*18:*/
#line 570 "./weaver_api.tex"

W.pending_files= 0;
W.loop_name= NULL;
/*:18*//*22:*/
#line 645 "./weaver_api.tex"

_lag= 0;
/*:22*/
#line 228 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 244 "./weaver_api.tex"

void Wexit(void){

exit(0);
}
/*:8*/
#line 193 "./weaver_api.tex"

/*:3*/
