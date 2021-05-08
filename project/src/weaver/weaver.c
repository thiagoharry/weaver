/*3:*/
#line 188 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*35:*/
#line 907 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:35*//*45:*/
#line 1090 "weaver_api.tex"

#include "memory.h"
/*:45*//*54:*/
#line 1199 "weaver_api.tex"

#include "random.h"
/*:54*//*58:*/
#line 1264 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:58*//*61:*/
#line 1332 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:61*/
#line 191 "weaver_api.tex"

/*44:*/
#line 1081 "weaver_api.tex"

static void*memory_arena;
/*:44*//*55:*/
#line 1208 "weaver_api.tex"

static struct _Wrng*rng;
/*:55*/
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
/*:14*//*37:*/
#line 932 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*39:*/
#line 973 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1145 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 937 "weaver_api.tex"

/*67:*/
#line 1425 "weaver_api.tex"

/*:67*/
#line 938 "weaver_api.tex"

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
#line 1022 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*68:*/
#line 1430 "weaver_api.tex"

/*:68*/
#line 1029 "weaver_api.tex"

_number_of_loops--;
/*39:*/
#line 973 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1145 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 1031 "weaver_api.tex"

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
#line 193 "weaver_api.tex"

/*51:*/
#line 1168 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:51*//*64:*/
#line 1390 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:64*/
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
/*:33*//*46:*/
#line 1100 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:46*//*53:*/
#line 1188 "weaver_api.tex"

W.alloc= _alloc;
/*:53*//*56:*/
#line 1218 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:56*//*57:*/
#line 1247 "weaver_api.tex"

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
/*:57*//*59:*/
#line 1277 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:59*//*60:*/
#line 1307 "weaver_api.tex"

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
/*:60*//*62:*/
#line 1349 "weaver_api.tex"

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
/*:62*//*66:*/
#line 1410 "weaver_api.tex"

W.rand= _rand;
/*:66*/
#line 230 "weaver_api.tex"

}
/*:6*//*8:*/
#line 247 "weaver_api.tex"

void Wexit(void){
/*63:*/
#line 1378 "weaver_api.tex"

printf("Fim do rng: \n");
_Wdestroy_rng(NULL,rng);
printf("Feito\n");
/*:63*/
#line 249 "weaver_api.tex"

/*47:*/
#line 1113 "weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:47*/
#line 250 "weaver_api.tex"

exit(0);
}
/*:8*//*26:*/
#line 720 "weaver_api.tex"

void _update(void){
/*69:*/
#line 1435 "weaver_api.tex"

/*:69*/
#line 722 "weaver_api.tex"

}
/*:26*//*29:*/
#line 782 "weaver_api.tex"

void _render(void){
/*70:*/
#line 1440 "weaver_api.tex"

/*:70*/
#line 784 "weaver_api.tex"

}
/*:29*//*34:*/
#line 883 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*36:*/
#line 919 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:36*//*50:*/
#line 1156 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:50*/
#line 886 "weaver_api.tex"

_number_of_loops--;
}
/*39:*/
#line 973 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:39*//*49:*/
#line 1145 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:49*/
#line 889 "weaver_api.tex"

/*71:*/
#line 1445 "weaver_api.tex"

/*:71*/
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
