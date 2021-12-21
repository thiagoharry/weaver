/*4:*/
#line 180 "weaver_api_en.tex"

#include "weaver.h"
#include "../game.h"
/*38:*/
#line 900 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
#include <emscripten.h> 
#endif
/*:38*//*48:*/
#line 1077 "weaver_api_en.tex"

#include "memory.h"
/*:48*//*58:*/
#line 1195 "weaver_api_en.tex"

#include "random.h"
/*:58*//*62:*/
#line 1256 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:62*//*65:*/
#line 1322 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:65*/
#line 183 "weaver_api_en.tex"

/*47:*/
#line 1069 "weaver_api_en.tex"

static void*memory_arena;
/*:47*//*59:*/
#line 1203 "weaver_api_en.tex"

static struct _Wrng*rng;
/*:59*//*79:*/
#line 1489 "weaver_api_en.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen;
#endif
/*:79*/
#line 184 "weaver_api_en.tex"

/*6:*/
#line 225 "weaver_api_en.tex"

struct _weaver_struct W;
/*:6*//*12:*/
#line 302 "weaver_api_en.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
struct timeval _last_time;
#endif
/*:12*/
#line 185 "weaver_api_en.tex"

/*16:*/
#line 353 "weaver_api_en.tex"

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
/*:16*//*17:*/
#line 393 "weaver_api_en.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:17*//*40:*/
#line 924 "weaver_api_en.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*42:*/
#line 964 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:42*//*52:*/
#line 1129 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:52*//*78:*/
#line 1471 "weaver_api_en.tex"

_Wflush_window_input();
/*:78*/
#line 929 "weaver_api_en.tex"

/*85:*/
#line 1571 "weaver_api_en.tex"
/*:85*/
#line 930 "weaver_api_en.tex"

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
/*:40*//*45:*/
#line 1011 "weaver_api_en.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*86:*/
#line 1575 "weaver_api_en.tex"
/*:86*/
#line 1018 "weaver_api_en.tex"

_number_of_loops--;
/*42:*/
#line 964 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:42*//*52:*/
#line 1129 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:52*//*78:*/
#line 1471 "weaver_api_en.tex"

_Wflush_window_input();
/*:78*/
#line 1020 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#else
while(1)
_loop_stack[_number_of_loops-1]();
#endif
}
}
/*:45*/
#line 186 "weaver_api_en.tex"

/*29:*/
#line 724 "weaver_api_en.tex"

void _update(void){
/*77:*/
#line 1462 "weaver_api_en.tex"

_Wget_window_input(W.t);
/*:77*/
#line 726 "weaver_api_en.tex"

}
/*:29*//*37:*/
#line 875 "weaver_api_en.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*39:*/
#line 912 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:39*//*53:*/
#line 1140 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:53*/
#line 878 "weaver_api_en.tex"

_number_of_loops--;
}
/*42:*/
#line 964 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:42*//*52:*/
#line 1129 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:52*//*78:*/
#line 1471 "weaver_api_en.tex"

_Wflush_window_input();
/*:78*/
#line 881 "weaver_api_en.tex"

/*87:*/
#line 1579 "weaver_api_en.tex"
/*:87*/
#line 882 "weaver_api_en.tex"

_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#else
while(1)
f();
#endif
}
/*:37*//*54:*/
#line 1153 "weaver_api_en.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:54*//*57:*/
#line 1182 "weaver_api_en.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:57*//*68:*/
#line 1377 "weaver_api_en.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:68*/
#line 187 "weaver_api_en.tex"

/*8:*/
#line 243 "weaver_api_en.tex"

void Winit(void){
W.game= &_game;
/*14:*/
#line 325 "weaver_api_en.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:14*//*19:*/
#line 565 "weaver_api_en.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:19*//*21:*/
#line 596 "weaver_api_en.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:21*//*25:*/
#line 677 "weaver_api_en.tex"

_lag= 0;
/*:25*//*27:*/
#line 703 "weaver_api_en.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:27*//*36:*/
#line 861 "weaver_api_en.tex"

_number_of_loops= 0;
/*:36*//*49:*/
#line 1086 "weaver_api_en.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:49*//*56:*/
#line 1172 "weaver_api_en.tex"

W.alloc= _alloc;
/*:56*//*60:*/
#line 1213 "weaver_api_en.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:60*//*61:*/
#line 1240 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
{
ssize_t ret;
uint64_t buffer[4];
do{
ret= getrandom(buffer,4*8,0);
}while(ret!=4*8);
}
#endif
/*:61*//*63:*/
#line 1268 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:63*//*64:*/
#line 1298 "weaver_api_en.tex"

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
/*:64*//*66:*/
#line 1338 "weaver_api_en.tex"

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
/*:66*//*70:*/
#line 1396 "weaver_api_en.tex"

W.rand= _rand;
/*:70*//*72:*/
#line 1418 "weaver_api_en.tex"

_Wcreate_window();
/*:72*//*76:*/
#line 1452 "weaver_api_en.tex"

W.keyboard= _Wkeyboard.key;
W.mouse= &_Wmouse;
/*:76*//*81:*/
#line 1508 "weaver_api_en.tex"

_Wget_screen_resolution(&W.resolution_x,&W.resolution_y);
_Wget_window_size(&W.width,&W.height);
#if defined(W_FORCE_LANDSCAPE)
if(W.height> W.width){
int tmp;
tmp= W.resolution_y;
W.resolution_y= W.resolution_x;
W.resolution_x= tmp;
tmp= W.width;
W.width= W.height;
W.height= tmp;
rotated_screen= true;
}
#endif
/*:81*//*83:*/
#line 1539 "weaver_api_en.tex"

{
int*window_width= &W.width,*window_height= &W.height;
#if defined(W_FORCE_LANDSCAPE)
if(rotated_screen){
*window_width= &W.height;
*window_height= &W.width;
}
#endif
_Winit_interface(window_width,window_height,_alloc,NULL,
_internal_alloc,NULL,NULL,NULL,NULL);
}
/*:83*/
#line 246 "weaver_api_en.tex"

}
/*:8*//*10:*/
#line 263 "weaver_api_en.tex"

void Wexit(void){
/*67:*/
#line 1367 "weaver_api_en.tex"

_Wdestroy_rng(NULL,rng);
/*:67*//*73:*/
#line 1424 "weaver_api_en.tex"

_Wdestroy_window();
/*:73*//*84:*/
#line 1557 "weaver_api_en.tex"

_Wfinish_interface();
/*:84*/
#line 265 "weaver_api_en.tex"

/*50:*/
#line 1099 "weaver_api_en.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:50*/
#line 266 "weaver_api_en.tex"

exit(0);
}
/*:10*/
#line 188 "weaver_api_en.tex"

/*:4*/
