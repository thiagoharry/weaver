/*3:*/
#line 188 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*44:*/
#line 1079 "weaver_api.tex"

#include "memory.h"
/*:44*//*53:*/
#line 1188 "weaver_api.tex"

#include "random.h"
/*:53*//*57:*/
#line 1253 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:57*//*60:*/
#line 1321 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:60*/
#line 191 "weaver_api.tex"

/*43:*/
#line 1070 "weaver_api.tex"

static void*memory_arena;
/*:43*//*54:*/
#line 1197 "weaver_api.tex"

static struct _Wrng*rng;
/*:54*/
#line 192 "weaver_api.tex"

/*4:*/
#line 204 "weaver_api.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 327 "weaver_api.tex"

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
#line 369 "weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:14*//*36:*/
#line 921 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*38:*/
#line 962 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1134 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 926 "weaver_api.tex"

/*66:*/
#line 1412 "weaver_api.tex"

/*:66*/
#line 927 "weaver_api.tex"

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
#line 1011 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*67:*/
#line 1417 "weaver_api.tex"

/*:67*/
#line 1018 "weaver_api.tex"

_number_of_loops--;
/*38:*/
#line 962 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1134 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 1020 "weaver_api.tex"

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
#line 193 "weaver_api.tex"

/*50:*/
#line 1157 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:50*//*63:*/
#line 1377 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:63*/
#line 194 "weaver_api.tex"

/*6:*/
#line 227 "weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 300 "weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 550 "weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:16*//*18:*/
#line 584 "weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:18*//*22:*/
#line 670 "weaver_api.tex"

_lag= 0;
/*:22*//*24:*/
#line 698 "weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 867 "weaver_api.tex"

_number_of_loops= 0;
/*:33*//*45:*/
#line 1089 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:45*//*52:*/
#line 1177 "weaver_api.tex"

W.alloc= _alloc;
/*:52*//*55:*/
#line 1207 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:55*//*56:*/
#line 1236 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
{
ssize_t ret;
uint64_t buffer[4];
do{
ret= getrandom(buffer,4*8,0);
}while(ret!=4*8);
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:56*//*58:*/
#line 1266 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:58*//*59:*/
#line 1296 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
{
uint64_t buffer[4];
NTSTATUS ret;
int count= 0;
do{
ret= BCryptGenRandom(NULL,buffer,8*4,
BCRYPT_USE_SYSTEM_PREFERRED_RNG);
count++;
}while(ret!=STATUS_SUCCESS&&count<16);
if(ret!=STATUS_SUCCESS){
fprintf(stderr,"ERROR: I could not initialize the RNG.\n");
exit(1);
}
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:59*//*61:*/
#line 1338 "weaver_api.tex"

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
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:61*//*65:*/
#line 1397 "weaver_api.tex"

W.rand= _rand;
/*:65*/
#line 230 "weaver_api.tex"

}
/*:6*//*8:*/
#line 247 "weaver_api.tex"

void Wexit(void){
/*62:*/
#line 1367 "weaver_api.tex"

_Wdestroy_rng(NULL,rng);
/*:62*/
#line 249 "weaver_api.tex"

/*46:*/
#line 1102 "weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:46*/
#line 250 "weaver_api.tex"

exit(0);
}
/*:8*//*26:*/
#line 720 "weaver_api.tex"

void _update(void){
/*68:*/
#line 1422 "weaver_api.tex"

/*:68*/
#line 722 "weaver_api.tex"

}
/*:26*//*29:*/
#line 782 "weaver_api.tex"

void _render(void){
/*69:*/
#line 1427 "weaver_api.tex"

/*:69*/
#line 784 "weaver_api.tex"

}
/*:29*//*34:*/
#line 883 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*35:*/
#line 908 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:35*//*49:*/
#line 1145 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:49*/
#line 886 "weaver_api.tex"

_number_of_loops--;
}
/*38:*/
#line 962 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:38*//*48:*/
#line 1134 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:48*/
#line 889 "weaver_api.tex"

/*70:*/
#line 1432 "weaver_api.tex"

/*:70*/
#line 890 "weaver_api.tex"

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
#line 195 "weaver_api.tex"

/*:3*/
