/*4:*/
#line 181 "weaver_api_en.tex"

#include "weaver.h"
#include "../game.h"
/*50:*/
#line 1115 "weaver_api_en.tex"

#include "memory.h"
/*:50*//*60:*/
#line 1232 "weaver_api_en.tex"

#include "random.h"
/*:60*//*64:*/
#line 1294 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:64*//*67:*/
#line 1360 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:67*/
#line 184 "weaver_api_en.tex"

/*5:*/
#line 198 "weaver_api_en.tex"

#if defined(__linux__) || defined(BSD)
#define STATIC_MUTEX_DECLARATION(mutex) static pthread_mutex_t mutex
#define MUTEX_INIT(mutex) pthread_mutex_init(mutex, NULL)
#define MUTEX_DESTROY(mutex) pthread_mutex_destroy(mutex);
#define MUTEX_WAIT(mutex) pthread_mutex_lock(mutex);
#define MUTEX_SIGNAL(mutex) pthread_mutex_unlock(mutex);
#elif defined(_WIN32)
#define STATIC_MUTEX_DECLARATION(mutex) static CRITICAL_SECTION mutex
#define MUTEX_INIT(mutex) InitializeCriticalSection(mutex)
#define MUTEX_DESTROY(mutex) DeleteCriticalSection(mutex);
#define MUTEX_WAIT(mutex) EnterCriticalSection(mutex);
#define MUTEX_SIGNAL(mutex) LeaveCriticalSection(mutex);
#elif defined(__EMSCRIPTEN__)
#define STATIC_MUTEX_DECLARATION(mutex)
#define MUTEX_INIT(mutex)
#define MUTEX_DESTROY(mutex)
#define MUTEX_WAIT(mutex)
#define MUTEX_SIGNAL(mutex)
#endif
/*:5*/
#line 185 "weaver_api_en.tex"

/*7:*/
#line 255 "weaver_api_en.tex"

struct _weaver_struct W;
/*:7*//*13:*/
#line 332 "weaver_api_en.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
struct timeval _last_time;
#endif
/*:13*//*20:*/
#line 595 "weaver_api_en.tex"

bool _running_loop,_loop_begin,_loop_finalized;
/*:20*//*27:*/
#line 713 "weaver_api_en.tex"

unsigned long _lag;
/*:27*//*39:*/
#line 905 "weaver_api_en.tex"

int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:39*/
#line 186 "weaver_api_en.tex"

/*49:*/
#line 1107 "weaver_api_en.tex"

static void*memory_arena;
/*:49*//*61:*/
#line 1240 "weaver_api_en.tex"

static struct _Wrng*rng;
/*:61*//*81:*/
#line 1527 "weaver_api_en.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen;
#endif
/*:81*//*85:*/
#line 1591 "weaver_api_en.tex"

STATIC_MUTEX_DECLARATION(pending_files_mutex);
/*:85*/
#line 187 "weaver_api_en.tex"

/*17:*/
#line 383 "weaver_api_en.tex"

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
/*:17*//*18:*/
#line 423 "weaver_api_en.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:18*//*32:*/
#line 770 "weaver_api_en.tex"

void _update(void){
/*79:*/
#line 1500 "weaver_api_en.tex"

_Wget_window_input(W.t);
/*:79*/
#line 772 "weaver_api_en.tex"

}
/*:32*//*35:*/
#line 825 "weaver_api_en.tex"

void _render(void){
/*76:*/
#line 1471 "weaver_api_en.tex"

_Wrender_window();
/*:76*/
#line 827 "weaver_api_en.tex"

}
/*:35*//*41:*/
#line 928 "weaver_api_en.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*43:*/
#line 965 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:43*//*55:*/
#line 1178 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:55*/
#line 931 "weaver_api_en.tex"

_number_of_loops--;
}
/*45:*/
#line 1012 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*54:*/
#line 1167 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:54*//*80:*/
#line 1509 "weaver_api_en.tex"

_Wflush_window_input();
/*:80*/
#line 934 "weaver_api_en.tex"

/*93:*/
#line 1675 "weaver_api_en.tex"
/*:93*/
#line 935 "weaver_api_en.tex"

_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#else
while(1)
f();
#endif
}
/*:41*//*44:*/
#line 977 "weaver_api_en.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*45:*/
#line 1012 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*54:*/
#line 1167 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:54*//*80:*/
#line 1509 "weaver_api_en.tex"

_Wflush_window_input();
/*:80*/
#line 982 "weaver_api_en.tex"

/*91:*/
#line 1667 "weaver_api_en.tex"
/*:91*/
#line 983 "weaver_api_en.tex"

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
/*:44*//*47:*/
#line 1049 "weaver_api_en.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*92:*/
#line 1671 "weaver_api_en.tex"
/*:92*/
#line 1056 "weaver_api_en.tex"

_number_of_loops--;
/*45:*/
#line 1012 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*54:*/
#line 1167 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:54*//*80:*/
#line 1509 "weaver_api_en.tex"

_Wflush_window_input();
/*:80*/
#line 1058 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#else
while(1)
_loop_stack[_number_of_loops-1]();
#endif
}
}
/*:47*//*56:*/
#line 1190 "weaver_api_en.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:56*//*59:*/
#line 1219 "weaver_api_en.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:59*//*70:*/
#line 1415 "weaver_api_en.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:70*//*88:*/
#line 1617 "weaver_api_en.tex"

void before_loading_resources(void){
MUTEX_WAIT(&pending_files_mutex);
W.pending_files++;
MUTEX_SIGNAL(&pending_files_mutex);
}
void after_loading_resources(void){
MUTEX_WAIT(&pending_files_mutex);
W.pending_files--;
MUTEX_SIGNAL(&pending_files_mutex);
}
/*:88*/
#line 188 "weaver_api_en.tex"

/*9:*/
#line 273 "weaver_api_en.tex"

void Winit(void){
W.game= &_game;
/*15:*/
#line 355 "weaver_api_en.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:15*//*21:*/
#line 603 "weaver_api_en.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:21*//*23:*/
#line 634 "weaver_api_en.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:23*//*28:*/
#line 722 "weaver_api_en.tex"

_lag= 0;
/*:28*//*30:*/
#line 749 "weaver_api_en.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:30*//*40:*/
#line 914 "weaver_api_en.tex"

_number_of_loops= 0;
/*:40*//*51:*/
#line 1124 "weaver_api_en.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:51*//*58:*/
#line 1209 "weaver_api_en.tex"

W.alloc= _alloc;
/*:58*//*62:*/
#line 1250 "weaver_api_en.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:62*//*63:*/
#line 1277 "weaver_api_en.tex"

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
/*:63*//*65:*/
#line 1306 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:65*//*66:*/
#line 1336 "weaver_api_en.tex"

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
/*:66*//*68:*/
#line 1376 "weaver_api_en.tex"

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
/*:68*//*72:*/
#line 1434 "weaver_api_en.tex"

W.rand= _rand;
/*:72*//*74:*/
#line 1456 "weaver_api_en.tex"

_Wcreate_window();
/*:74*//*78:*/
#line 1490 "weaver_api_en.tex"

W.keyboard= _Wkeyboard.key;
W.mouse= &_Wmouse;
/*:78*//*83:*/
#line 1546 "weaver_api_en.tex"

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
/*:83*//*86:*/
#line 1600 "weaver_api_en.tex"

MUTEX_INIT(&pending_files_mutex);
/*:86*//*89:*/
#line 1635 "weaver_api_en.tex"

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
/*:89*/
#line 276 "weaver_api_en.tex"

}
/*:9*//*11:*/
#line 293 "weaver_api_en.tex"

void Wexit(void){
/*69:*/
#line 1405 "weaver_api_en.tex"

_Wdestroy_rng(NULL,rng);
/*:69*//*75:*/
#line 1462 "weaver_api_en.tex"

_Wdestroy_window();
/*:75*//*87:*/
#line 1608 "weaver_api_en.tex"

MUTEX_DESTROY(&pending_files_mutex);
/*:87*//*90:*/
#line 1653 "weaver_api_en.tex"

_Wfinish_interface();
/*:90*/
#line 295 "weaver_api_en.tex"

/*52:*/
#line 1137 "weaver_api_en.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:52*/
#line 296 "weaver_api_en.tex"

exit(0);
}
/*:11*/
#line 189 "weaver_api_en.tex"

/*:4*/
