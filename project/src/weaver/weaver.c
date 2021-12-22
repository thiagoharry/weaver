/*4:*/
#line 183 "weaver_api_en.tex"

#include "weaver.h"
#include "../game.h"
/*49:*/
#line 1088 "weaver_api_en.tex"

#include "memory.h"
/*:49*//*59:*/
#line 1206 "weaver_api_en.tex"

#include "random.h"
/*:59*//*63:*/
#line 1268 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:63*//*66:*/
#line 1334 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:66*/
#line 186 "weaver_api_en.tex"

/*48:*/
#line 1080 "weaver_api_en.tex"

static void*memory_arena;
/*:48*//*60:*/
#line 1214 "weaver_api_en.tex"

static struct _Wrng*rng;
/*:60*//*80:*/
#line 1501 "weaver_api_en.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen;
#endif
/*:80*/
#line 187 "weaver_api_en.tex"

/*6:*/
#line 228 "weaver_api_en.tex"

struct _weaver_struct W;
/*:6*//*12:*/
#line 305 "weaver_api_en.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
struct timeval _last_time;
#endif
/*:12*//*19:*/
#line 568 "weaver_api_en.tex"

bool _running_loop,_loop_begin,_loop_finalized;
/*:19*//*26:*/
#line 686 "weaver_api_en.tex"

unsigned long _lag;
/*:26*//*38:*/
#line 878 "weaver_api_en.tex"

int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:38*/
#line 188 "weaver_api_en.tex"

/*16:*/
#line 356 "weaver_api_en.tex"

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
#line 396 "weaver_api_en.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:17*//*31:*/
#line 743 "weaver_api_en.tex"

void _update(void){
/*78:*/
#line 1474 "weaver_api_en.tex"

_Wget_window_input(W.t);
/*:78*/
#line 745 "weaver_api_en.tex"

}
/*:31*//*34:*/
#line 798 "weaver_api_en.tex"

void _render(void){
/*75:*/
#line 1445 "weaver_api_en.tex"

_Wrender_window();
/*:75*/
#line 800 "weaver_api_en.tex"

}
/*:34*//*40:*/
#line 901 "weaver_api_en.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*42:*/
#line 938 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:42*//*54:*/
#line 1151 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:54*/
#line 904 "weaver_api_en.tex"

_number_of_loops--;
}
/*44:*/
#line 985 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:44*//*53:*/
#line 1140 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:53*//*79:*/
#line 1483 "weaver_api_en.tex"

_Wflush_window_input();
/*:79*/
#line 907 "weaver_api_en.tex"

/*88:*/
#line 1591 "weaver_api_en.tex"
/*:88*/
#line 908 "weaver_api_en.tex"

_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#else
while(1)
f();
#endif
}
/*:40*//*43:*/
#line 950 "weaver_api_en.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*44:*/
#line 985 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:44*//*53:*/
#line 1140 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:53*//*79:*/
#line 1483 "weaver_api_en.tex"

_Wflush_window_input();
/*:79*/
#line 955 "weaver_api_en.tex"

/*86:*/
#line 1583 "weaver_api_en.tex"
/*:86*/
#line 956 "weaver_api_en.tex"

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
/*:43*//*46:*/
#line 1022 "weaver_api_en.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*87:*/
#line 1587 "weaver_api_en.tex"
/*:87*/
#line 1029 "weaver_api_en.tex"

_number_of_loops--;
/*44:*/
#line 985 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:44*//*53:*/
#line 1140 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:53*//*79:*/
#line 1483 "weaver_api_en.tex"

_Wflush_window_input();
/*:79*/
#line 1031 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#else
while(1)
_loop_stack[_number_of_loops-1]();
#endif
}
}
/*:46*/
#line 189 "weaver_api_en.tex"

/*55:*/
#line 1164 "weaver_api_en.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:55*//*58:*/
#line 1193 "weaver_api_en.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:58*//*69:*/
#line 1389 "weaver_api_en.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:69*/
#line 190 "weaver_api_en.tex"

/*8:*/
#line 246 "weaver_api_en.tex"

void Winit(void){
W.game= &_game;
/*14:*/
#line 328 "weaver_api_en.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:14*//*20:*/
#line 576 "weaver_api_en.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:20*//*22:*/
#line 607 "weaver_api_en.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:22*//*27:*/
#line 695 "weaver_api_en.tex"

_lag= 0;
/*:27*//*29:*/
#line 722 "weaver_api_en.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:29*//*39:*/
#line 887 "weaver_api_en.tex"

_number_of_loops= 0;
/*:39*//*50:*/
#line 1097 "weaver_api_en.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:50*//*57:*/
#line 1183 "weaver_api_en.tex"

W.alloc= _alloc;
/*:57*//*61:*/
#line 1224 "weaver_api_en.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:61*//*62:*/
#line 1251 "weaver_api_en.tex"

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
/*:62*//*64:*/
#line 1280 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:64*//*65:*/
#line 1310 "weaver_api_en.tex"

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
/*:65*//*67:*/
#line 1350 "weaver_api_en.tex"

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
/*:67*//*71:*/
#line 1408 "weaver_api_en.tex"

W.rand= _rand;
/*:71*//*73:*/
#line 1430 "weaver_api_en.tex"

_Wcreate_window();
/*:73*//*77:*/
#line 1464 "weaver_api_en.tex"

W.keyboard= _Wkeyboard.key;
W.mouse= &_Wmouse;
/*:77*//*82:*/
#line 1520 "weaver_api_en.tex"

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
/*:82*//*84:*/
#line 1551 "weaver_api_en.tex"

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
/*:84*/
#line 249 "weaver_api_en.tex"

}
/*:8*//*10:*/
#line 266 "weaver_api_en.tex"

void Wexit(void){
/*68:*/
#line 1379 "weaver_api_en.tex"

_Wdestroy_rng(NULL,rng);
/*:68*//*74:*/
#line 1436 "weaver_api_en.tex"

_Wdestroy_window();
/*:74*//*85:*/
#line 1569 "weaver_api_en.tex"

_Wfinish_interface();
/*:85*/
#line 268 "weaver_api_en.tex"

/*51:*/
#line 1110 "weaver_api_en.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:51*/
#line 269 "weaver_api_en.tex"

exit(0);
}
/*:10*/
#line 191 "weaver_api_en.tex"

/*:4*/
