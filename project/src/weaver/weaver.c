/*3:*/
#line 192 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*35:*/
#line 911 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:35*//*45:*/
#line 1094 "weaver_api.tex"

#include "memory.h"
/*:45*//*55:*/
#line 1215 "weaver_api.tex"

#include "random.h"
/*:55*//*59:*/
#line 1280 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:59*//*62:*/
#line 1348 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:62*/
#line 195 "weaver_api.tex"

/*44:*/
#line 1085 "weaver_api.tex"

static void*memory_arena;
/*:44*//*56:*/
#line 1224 "weaver_api.tex"

static struct _Wrng*rng;
/*:56*/
#line 196 "weaver_api.tex"

/*4:*/
#line 208 "weaver_api.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 331 "weaver_api.tex"

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
#line 373 "weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:14*//*37:*/
#line 936 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*39:*/
#line 977 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1149 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1500 "weaver_api.tex"

_Wflush_window_input();
/*:75*/
#line 941 "weaver_api.tex"

/*76:*/
#line 1513 "weaver_api.tex"

/*:76*/
#line 942 "weaver_api.tex"

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
#line 1026 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*77:*/
#line 1518 "weaver_api.tex"

/*:77*/
#line 1033 "weaver_api.tex"

_number_of_loops--;
/*39:*/
#line 977 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1149 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1500 "weaver_api.tex"

_Wflush_window_input();
/*:75*/
#line 1035 "weaver_api.tex"

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
#line 197 "weaver_api.tex"

/*51:*/
#line 1172 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:51*//*54:*/
#line 1202 "weaver_api.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:54*//*65:*/
#line 1404 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:65*/
#line 198 "weaver_api.tex"

/*6:*/
#line 231 "weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 304 "weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 554 "weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:16*//*18:*/
#line 588 "weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:18*//*22:*/
#line 674 "weaver_api.tex"

_lag= 0;
/*:22*//*24:*/
#line 702 "weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 871 "weaver_api.tex"

_number_of_loops= 0;
/*:33*//*46:*/
#line 1104 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:46*//*53:*/
#line 1192 "weaver_api.tex"

W.alloc= _alloc;
/*:53*//*57:*/
#line 1234 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:57*//*58:*/
#line 1263 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
{
ssize_t ret;
uint64_t buffer[4];
do{
ret= getrandom(buffer,4*8,0);
}while(ret!=4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:58*//*60:*/
#line 1293 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:60*//*61:*/
#line 1323 "weaver_api.tex"

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
#line 1365 "weaver_api.tex"

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
#line 1424 "weaver_api.tex"

W.rand= _rand;
/*:67*//*69:*/
#line 1447 "weaver_api.tex"

_Wcreate_window();
/*:69*//*73:*/
#line 1482 "weaver_api.tex"

W.keyboard= _Wkeyboard.key;
W.mouse= &_Wmouse;
/*:73*/
#line 234 "weaver_api.tex"

}
/*:6*//*8:*/
#line 251 "weaver_api.tex"

void Wexit(void){
/*64:*/
#line 1394 "weaver_api.tex"

_Wdestroy_rng(NULL,rng);
/*:64*//*70:*/
#line 1453 "weaver_api.tex"

_Wdestroy_window();
/*:70*/
#line 253 "weaver_api.tex"

/*47:*/
#line 1117 "weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:47*/
#line 254 "weaver_api.tex"

exit(0);
}
/*:8*//*26:*/
#line 724 "weaver_api.tex"

void _update(void){
/*74:*/
#line 1491 "weaver_api.tex"

_Wget_window_input(W.t);
/*:74*/
#line 726 "weaver_api.tex"

}
/*:26*//*29:*/
#line 786 "weaver_api.tex"

void _render(void){
/*71:*/
#line 1463 "weaver_api.tex"

_Wrender_window();
/*:71*/
#line 788 "weaver_api.tex"

}
/*:29*//*34:*/
#line 887 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*36:*/
#line 923 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:36*//*50:*/
#line 1160 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:50*/
#line 890 "weaver_api.tex"

_number_of_loops--;
}
/*39:*/
#line 977 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1149 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*//*75:*/
#line 1500 "weaver_api.tex"

_Wflush_window_input();
/*:75*/
#line 893 "weaver_api.tex"

/*78:*/
#line 1525 "weaver_api.tex"

/*:78*/
#line 894 "weaver_api.tex"

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
#line 199 "weaver_api.tex"

/*:3*/
