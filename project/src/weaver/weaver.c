/*3:*/
#line 191 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*35:*/
#line 910 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:35*//*45:*/
#line 1093 "weaver_api.tex"

#include "memory.h"
/*:45*//*55:*/
#line 1214 "weaver_api.tex"

#include "random.h"
/*:55*//*59:*/
#line 1279 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:59*//*62:*/
#line 1347 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:62*/
#line 194 "weaver_api.tex"

/*44:*/
#line 1084 "weaver_api.tex"

static void*memory_arena;
/*:44*//*56:*/
#line 1223 "weaver_api.tex"

static struct _Wrng*rng;
/*:56*/
#line 195 "weaver_api.tex"

/*4:*/
#line 207 "weaver_api.tex"

struct _weaver_struct W;
/*:4*//*13:*/
#line 330 "weaver_api.tex"

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
#line 372 "weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:14*//*37:*/
#line 935 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*39:*/
#line 976 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1148 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 940 "weaver_api.tex"

/*68:*/
#line 1438 "weaver_api.tex"

/*:68*/
#line 941 "weaver_api.tex"

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
#line 1025 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*69:*/
#line 1443 "weaver_api.tex"

/*:69*/
#line 1032 "weaver_api.tex"

_number_of_loops--;
/*39:*/
#line 976 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1148 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 1034 "weaver_api.tex"

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
#line 196 "weaver_api.tex"

/*51:*/
#line 1171 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:51*//*54:*/
#line 1201 "weaver_api.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:54*//*65:*/
#line 1403 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:65*/
#line 197 "weaver_api.tex"

/*6:*/
#line 230 "weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 303 "weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:11*//*16:*/
#line 553 "weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:16*//*18:*/
#line 587 "weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:18*//*22:*/
#line 673 "weaver_api.tex"

_lag= 0;
/*:22*//*24:*/
#line 701 "weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:24*//*33:*/
#line 870 "weaver_api.tex"

_number_of_loops= 0;
/*:33*//*46:*/
#line 1103 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:46*//*53:*/
#line 1191 "weaver_api.tex"

W.alloc= _alloc;
/*:53*//*57:*/
#line 1233 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:57*//*58:*/
#line 1262 "weaver_api.tex"

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
#line 1292 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:60*//*61:*/
#line 1322 "weaver_api.tex"

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
#line 1364 "weaver_api.tex"

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
#line 1423 "weaver_api.tex"

W.rand= _rand;
/*:67*/
#line 233 "weaver_api.tex"

}
/*:6*//*8:*/
#line 250 "weaver_api.tex"

void Wexit(void){
/*64:*/
#line 1393 "weaver_api.tex"

_Wdestroy_rng(NULL,rng);
/*:64*/
#line 252 "weaver_api.tex"

/*47:*/
#line 1116 "weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:47*/
#line 253 "weaver_api.tex"

exit(0);
}
/*:8*//*26:*/
#line 723 "weaver_api.tex"

void _update(void){
/*70:*/
#line 1448 "weaver_api.tex"

/*:70*/
#line 725 "weaver_api.tex"

}
/*:26*//*29:*/
#line 785 "weaver_api.tex"

void _render(void){
/*71:*/
#line 1453 "weaver_api.tex"

/*:71*/
#line 787 "weaver_api.tex"

}
/*:29*//*34:*/
#line 886 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*36:*/
#line 922 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:36*//*50:*/
#line 1159 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:50*/
#line 889 "weaver_api.tex"

_number_of_loops--;
}
/*39:*/
#line 976 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1148 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 892 "weaver_api.tex"

/*72:*/
#line 1458 "weaver_api.tex"

/*:72*/
#line 893 "weaver_api.tex"

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
#line 198 "weaver_api.tex"

/*:3*/
