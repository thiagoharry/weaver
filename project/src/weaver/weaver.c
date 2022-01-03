/*4:*/
#line 198 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*50:*/
#line 1173 "weaver_api.tex"

#include "memory.h"
/*:50*//*60:*/
#line 1294 "weaver_api.tex"

#include "random.h"
/*:60*//*64:*/
#line 1359 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:64*//*67:*/
#line 1427 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:67*//*97:*/
#line 1874 "weaver_api.tex"

#include <string.h> 
/*:97*/
#line 201 "weaver_api.tex"

/*5:*/
#line 215 "weaver_api.tex"

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
#line 202 "weaver_api.tex"

/*7:*/
#line 273 "weaver_api.tex"

struct _weaver_struct W;
/*:7*//*13:*/
#line 352 "weaver_api.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
struct timeval _last_time;
#endif
/*:13*//*20:*/
#line 625 "weaver_api.tex"

bool _running_loop,_loop_begin,_loop_finalized;
/*:20*//*27:*/
#line 750 "weaver_api.tex"

unsigned long _lag;
/*:27*//*39:*/
#line 954 "weaver_api.tex"

int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:39*/
#line 203 "weaver_api.tex"

/*49:*/
#line 1164 "weaver_api.tex"

static void*memory_arena;
/*:49*//*61:*/
#line 1303 "weaver_api.tex"

static struct _Wrng*rng;
/*:61*//*75:*/
#line 1535 "weaver_api.tex"

static struct _Wkeyboard keyboard;
/*:75*//*82:*/
#line 1607 "weaver_api.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen= false;
#endif
/*:82*//*86:*/
#line 1677 "weaver_api.tex"

STATIC_MUTEX_DECLARATION(pending_files_mutex);
STATIC_MUTEX_DECLARATION(loading_files);
/*:86*/
#line 204 "weaver_api.tex"

/*17:*/
#line 403 "weaver_api.tex"

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
#line 444 "weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
/*:18*//*32:*/
#line 809 "weaver_api.tex"

void _update(void){
/*80:*/
#line 1579 "weaver_api.tex"

_Wget_window_input(W.t,&keyboard,&W.mouse);
/*:80*//*94:*/
#line 1796 "weaver_api.tex"

_Winteract_interface(W.mouse.x,W.mouse.y,
W.mouse.button[W_MOUSE_LEFT]> 0,
W.mouse.button[W_MOUSE_MIDDLE]> 0,
W.mouse.button[W_MOUSE_RIGHT]> 0);
/*:94*/
#line 811 "weaver_api.tex"

}
/*:32*//*35:*/
#line 871 "weaver_api.tex"

void _render(void){
/*79:*/
#line 1570 "weaver_api.tex"

_Wrender_window();
/*:79*//*95:*/
#line 1808 "weaver_api.tex"

_Wrender_interface(W.t);
/*:95*/
#line 873 "weaver_api.tex"

}
/*:35*//*41:*/
#line 980 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*43:*/
#line 1018 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:43*//*93:*/
#line 1788 "weaver_api.tex"

_Wrestore_history_interface();
/*:93*/
#line 983 "weaver_api.tex"

/*55:*/
#line 1239 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
/*:55*/
#line 984 "weaver_api.tex"

_number_of_loops--;
}
/*45:*/
#line 1066 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*81:*/
#line 1588 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:81*//*92:*/
#line 1778 "weaver_api.tex"

_Wmark_history_interface();
/*:92*/
#line 987 "weaver_api.tex"

/*103:*/
#line 1935 "weaver_api.tex"

/*:103*/
#line 988 "weaver_api.tex"

/*54:*/
#line 1228 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
/*:54*/
#line 989 "weaver_api.tex"

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
#line 1031 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*45:*/
#line 1066 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*81:*/
#line 1588 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:81*//*92:*/
#line 1778 "weaver_api.tex"

_Wmark_history_interface();
/*:92*/
#line 1036 "weaver_api.tex"

/*101:*/
#line 1923 "weaver_api.tex"

/*:101*/
#line 1037 "weaver_api.tex"

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
#line 1105 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*102:*/
#line 1928 "weaver_api.tex"

/*:102*/
#line 1112 "weaver_api.tex"

_number_of_loops--;
/*45:*/
#line 1066 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*81:*/
#line 1588 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:81*//*92:*/
#line 1778 "weaver_api.tex"

_Wmark_history_interface();
/*:92*/
#line 1114 "weaver_api.tex"

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
#line 1251 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:56*//*59:*/
#line 1281 "weaver_api.tex"

static void*_internal_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:59*//*70:*/
#line 1483 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:70*//*89:*/
#line 1712 "weaver_api.tex"

void before_loading_resources(void){
MUTEX_WAIT(&pending_files_mutex);
W.pending_files++;
MUTEX_SIGNAL(&pending_files_mutex);
MUTEX_WAIT(&loading_files);
_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,1);
}
void after_loading_resources(void){
_Wtrash(memory_arena,1);
MUTEX_SIGNAL(&loading_files);
MUTEX_WAIT(&pending_files_mutex);
W.pending_files--;
MUTEX_SIGNAL(&pending_files_mutex);
}
/*:89*//*96:*/
#line 1832 "weaver_api.tex"

static struct user_interface*new_interface(char*shader,char*texture,
float x,float y,float z,
float width,float height){
char path_shader[512],path_texture[512];
int dir_len,shader_len,texture_len;
if(shader!=NULL){
shader_len= strlen(shader);
path_shader[0]= '.';
path_shader[1]= '\0';
dir_len= 1;
#if defined(W_DATA_DIR)
dir_len= strlen(W_DATA_DIR);
memcpy(path_shader,W_DATA_DIR,dir_len+1);
#endif
memcpy(&path_shader[dir_len],"/shaders/",10);
dir_len+= 9;
memcpy(&path_shader[dir_len],shader,shader_len+1);
}
if(texture!=NULL){
texture_len= strlen(texture);
path_texture[0]= '.';
path_texture[1]= '\0';
dir_len= 1;
#if defined(W_DATA_DIR)
dir_len= strlen(W_DATA_DIR);
memcpy(path_texture,W_DATA_DIR,dir_len+1);
#endif
memcpy(&path_texture[dir_len],"/images/",9);
dir_len+= 8;
memcpy(&path_texture[dir_len],texture,texture_len+1);
}
return _Wnew_interface((texture==NULL)?(NULL):(path_texture),
(shader==NULL)?(NULL):(path_shader),
x,y,z,width,height);
}
/*:96*/
#line 205 "weaver_api.tex"

/*9:*/
#line 291 "weaver_api.tex"

void Winit(void){
W.game= &_game;
/*15:*/
#line 376 "weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
gettimeofday(&_last_time,NULL);
#endif
/*:15*//*21:*/
#line 633 "weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:21*//*23:*/
#line 667 "weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:23*//*28:*/
#line 758 "weaver_api.tex"

_lag= 0;
/*:28*//*30:*/
#line 787 "weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
W.dt= W_TIMESTEP;
W.t= 0;
/*:30*//*40:*/
#line 964 "weaver_api.tex"

_number_of_loops= 0;
/*:40*//*51:*/
#line 1183 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:51*//*58:*/
#line 1271 "weaver_api.tex"

W.alloc= _alloc;
/*:58*//*62:*/
#line 1313 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_internal_alloc,sizeof(seed)/sizeof(uint64_t),
seed);
}
#endif
/*:62*//*63:*/
#line 1342 "weaver_api.tex"

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
#line 1372 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_internal_alloc,4,buffer);
}
#endif
/*:65*//*66:*/
#line 1402 "weaver_api.tex"

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
#line 1444 "weaver_api.tex"

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
#line 1503 "weaver_api.tex"

W.rand= _rand;
/*:72*//*76:*/
#line 1544 "weaver_api.tex"

W.keyboard= keyboard.key;
/*:76*//*77:*/
#line 1554 "weaver_api.tex"

_Wcreate_window(&keyboard,&W.mouse);
/*:77*//*84:*/
#line 1626 "weaver_api.tex"

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
/*:84*//*87:*/
#line 1686 "weaver_api.tex"

MUTEX_INIT(&pending_files_mutex);
MUTEX_INIT(&loading_files);
/*:87*//*90:*/
#line 1733 "weaver_api.tex"

{
int*window_width= &W.width,*window_height= &W.height;
#if defined(W_FORCE_LANDSCAPE)
if(rotated_screen){
*window_width= &W.height;
*window_height= &W.width;
}
#endif
_Winit_interface(window_width,window_height,_alloc,NULL,
_internal_alloc,NULL,before_loading_resources,
after_loading_resources,NULL);
}
/*:90*//*100:*/
#line 1905 "weaver_api.tex"

W.new_interface= new_interface;
W.link_interface= _Wlink_interface;
W.rotate_interface= _Wrotate_interface;
W.resize_interface= _Wresize_interface;
W.move_interface= _Wmove_interface;
/*:100*/
#line 294 "weaver_api.tex"

}
/*:9*//*11:*/
#line 311 "weaver_api.tex"

void Wexit(void){
/*69:*/
#line 1473 "weaver_api.tex"

_Wdestroy_rng(NULL,rng);
/*:69*//*78:*/
#line 1560 "weaver_api.tex"

_Wdestroy_window();
/*:78*//*88:*/
#line 1695 "weaver_api.tex"

MUTEX_DESTROY(&pending_files_mutex);
MUTEX_DESTROY(&loading_files);
/*:88*//*91:*/
#line 1759 "weaver_api.tex"

_Wfinish_interface();
/*:91*/
#line 313 "weaver_api.tex"

/*52:*/
#line 1196 "weaver_api.tex"

_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:52*/
#line 314 "weaver_api.tex"

exit(0);
}
/*:11*/
#line 206 "weaver_api.tex"

/*:4*/
