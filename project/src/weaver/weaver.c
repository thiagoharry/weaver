/*3:*/
#line 177 "weaver_api_en.tex"

#include "weaver.h"
#include "../game.h"
/*35:*/
#line 862 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:35*//*45:*/
#line 1039 "weaver_api_en.tex"

#include "memory.h"
/*:45*//*55:*/
#line 1156 "weaver_api_en.tex"

#include "random.h"
/*:55*//*59:*/
#line 1217 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:59*//*62:*/
#line 1283 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:62*//*68:*/
#line 1368 "weaver_api_en.tex"

#include "window.h"
/*:68*/
#line 180 "weaver_api_en.tex"

/*44:*/
#line 1031 "weaver_api_en.tex"

static void*memory_arena;
/*:44*//*56:*/
#line 1164 "weaver_api_en.tex"

static struct _Wrng*rng;
/*:56*/
#line 181 "weaver_api_en.tex"

/*4:*/
#line 193 "weaver_api_en.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 315 "weaver_api_en.tex"

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
#line 355 "weaver_api_en.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:14*//*37:*/
#line 886 "weaver_api_en.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*39:*/
#line 926 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1091 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1431 "weaver_api_en.tex"

_Wflush_window_input();
/*:75*/
#line 891 "weaver_api_en.tex"

/*76:*/
#line 1445 "weaver_api_en.tex"
/*:76*/
#line 892 "weaver_api_en.tex"

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
/*:37*//*42:*/
#line 973 "weaver_api_en.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*77:*/
#line 1449 "weaver_api_en.tex"
/*:77*/
#line 980 "weaver_api_en.tex"

_number_of_loops--;
/*39:*/
#line 926 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1091 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1431 "weaver_api_en.tex"

_Wflush_window_input();
/*:75*/
#line 982 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#else
while(1)
_loop_stack[_number_of_loops-1]();
#endif
}
}
/*:42*/
#line 182 "weaver_api_en.tex"

/*51:*/
#line 1115 "weaver_api_en.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:51*//*65:*/
#line 1338 "weaver_api_en.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:65*/
#line 183 "weaver_api_en.tex"

/*6:*/
#line 215 "weaver_api_en.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 287 "weaver_api_en.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 527 "weaver_api_en.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:16*//*18:*/
#line 558 "weaver_api_en.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:18*//*22:*/
#line 639 "weaver_api_en.tex"

_lag= 0;
/*:22*//*24:*/
#line 665 "weaver_api_en.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 823 "weaver_api_en.tex"

_number_of_loops= 0;
/*:33*//*46:*/
#line 1048 "weaver_api_en.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:46*//*53:*/
#line 1133 "weaver_api_en.tex"

W.alloc= _alloc;
/*:53*//*57:*/
#line 1174 "weaver_api_en.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:57*//*58:*/
#line 1201 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
{
ssize_t ret;
uint64_t buffer[4];
do{
ret= getrandom(buffer,4*8,0);
}while(ret!=4*8);
}
#endif
/*:58*//*60:*/
#line 1229 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:60*//*61:*/
#line 1259 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
{
uint64_t buffer[4];
NTSTATUS ret;
int count= 0;
do{
ret= BCryptGenRandom(NULL,(unsigned char*)&buffer,8*4,
BCRYPT_USE_SYSTEM_PREFERRED_RNG);
count++;
}while(ret!=0&&count<16);
if(ret!=0){
fprintf(stderr,"ERROR: I could not initialize the RNG.\n");
exit(1);
}
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:61*//*63:*/
#line 1299 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__EMSCRIPTEN__)
{
uint64_t buffer[4];
int i;
for(i= 0;i<4;i++){
buffer[i]= EM_ASM_INT({
var array= new Uint32Array(1);
window.crypto.getRandomValues(array);
return array[0];
});
buffer[i]= buffer[i]<<32;
buffer[i]+= EM_ASM_INT({
var array= new Uint32Array(1);
window.crypto.getRandomValues(array);
return array[0];
});
}
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:63*//*67:*/
#line 1357 "weaver_api_en.tex"

W.rand= _rand;
/*:67*//*69:*/
#line 1378 "weaver_api_en.tex"

_Wcreate_window();
/*:69*//*73:*/
#line 1412 "weaver_api_en.tex"

W.keyboard= _Wkeyboard.key;
W.mouse= &_Wmouse;
/*:73*/
#line 218 "weaver_api_en.tex"

}
/*:6*//*8:*/
#line 235 "weaver_api_en.tex"

void Wexit(void){
/*64:*/
#line 1328 "weaver_api_en.tex"

_Wdestroy_rng(NULL,rng);
/*:64*//*70:*/
#line 1384 "weaver_api_en.tex"

_Wdestroy_window();
/*:70*/
#line 237 "weaver_api_en.tex"

/*47:*/
#line 1061 "weaver_api_en.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:47*/
#line 238 "weaver_api_en.tex"

exit(0);
}
/*:8*//*26:*/
#line 686 "weaver_api_en.tex"

void _update(void){
/*74:*/
#line 1422 "weaver_api_en.tex"

_Wget_window_input(W.t);
/*:74*/
#line 688 "weaver_api_en.tex"

}
/*:26*//*29:*/
#line 741 "weaver_api_en.tex"

void _render(void){
/*71:*/
#line 1393 "weaver_api_en.tex"

_Wrender_window();
/*:71*/
#line 743 "weaver_api_en.tex"

}
/*:29*//*34:*/
#line 837 "weaver_api_en.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*36:*/
#line 874 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:36*//*50:*/
#line 1102 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:50*/
#line 840 "weaver_api_en.tex"

_number_of_loops--;
}
/*39:*/
#line 926 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1091 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1431 "weaver_api_en.tex"

_Wflush_window_input();
/*:75*/
#line 843 "weaver_api_en.tex"

/*78:*/
#line 1453 "weaver_api_en.tex"
/*:78*/
#line 844 "weaver_api_en.tex"

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
#line 184 "weaver_api_en.tex"

/*:3*/
