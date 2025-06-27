/*4:*/
#line 200 "weaver_api.tex"

#include "weaver.h"
#include "../game.h"
struct _game_struct _game;
/*50:*/
#line 1173 "weaver_api.tex"

#include "memory.h"
/*:50*//*61:*/
#line 1310 "weaver_api.tex"

#include "random.h"
/*:61*//*65:*/
#line 1374 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
#line 1378 "weaver_api.tex"
/*:65*//*68:*/
#line 1442 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
#line 1446 "weaver_api.tex"
/*:68*//*92:*/
#line 1773 "weaver_api.tex"

#include "metafont.h"
#include "wave.h"
/*:92*//*100:*/
#line 1919 "weaver_api.tex"

#include <string.h> 
/*:100*/
#line 204 "weaver_api.tex"

/*5:*/
#line 218 "weaver_api.tex"

#if defined(__linux__) || defined(BSD)
#define STATIC_MUTEX_DECLARATION(mutex) static pthread_mutex_t mutex
#define MUTEX_INIT(mutex) pthread_mutex_init(mutex, NULL)
#define MUTEX_DESTROY(mutex) pthread_mutex_destroy(mutex);
#define MUTEX_WAIT(mutex) pthread_mutex_lock(mutex);
#define MUTEX_SIGNAL(mutex) pthread_mutex_unlock(mutex);
#elif defined(_WIN32)
#line 226 "weaver_api.tex"
#define STATIC_MUTEX_DECLARATION(mutex) static CRITICAL_SECTION mutex
#define MUTEX_INIT(mutex) InitializeCriticalSection(mutex)
#define MUTEX_DESTROY(mutex) DeleteCriticalSection(mutex);
#define MUTEX_WAIT(mutex) EnterCriticalSection(mutex);
#define MUTEX_SIGNAL(mutex) LeaveCriticalSection(mutex);
#elif defined(__EMSCRIPTEN__)
#line 232 "weaver_api.tex"
#define STATIC_MUTEX_DECLARATION(mutex)
#define MUTEX_INIT(mutex)
#define MUTEX_DESTROY(mutex)
#define MUTEX_WAIT(mutex)
#define MUTEX_SIGNAL(mutex)
#endif
#line 238 "weaver_api.tex"
/*:5*/
#line 205 "weaver_api.tex"

/*7:*/
#line 276 "weaver_api.tex"

struct _weaver_struct W;
/*:7*//*13:*/
#line 355 "weaver_api.tex"

#if defined(_WIN32)
LARGE_INTEGER _last_time;
#else
#line 359 "weaver_api.tex"
 struct timeval _last_time;
#endif
#line 361 "weaver_api.tex"
/*:13*//*20:*/
#line 628 "weaver_api.tex"

bool _running_loop,_loop_begin,_loop_finalized;
/*:20*//*27:*/
#line 753 "weaver_api.tex"

unsigned long _lag;
/*:27*//*39:*/
#line 957 "weaver_api.tex"

int _number_of_loops;
void(*_loop_stack[W_MAX_SUBLOOP])(void);
/*:39*/
#line 206 "weaver_api.tex"

/*49:*/
#line 1164 "weaver_api.tex"

static void*memory_arena;
/*:49*//*62:*/
#line 1319 "weaver_api.tex"

static struct _Wrng*rng;
/*:62*//*76:*/
#line 1550 "weaver_api.tex"

static struct _Wkeyboard keyboard;
/*:76*//*83:*/
#line 1622 "weaver_api.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen= false;
#endif
#line 1626 "weaver_api.tex"
/*:83*//*87:*/
#line 1692 "weaver_api.tex"

STATIC_MUTEX_DECLARATION(pending_files_mutex);
STATIC_MUTEX_DECLARATION(loading_files);
/*:87*/
#line 207 "weaver_api.tex"

/*17:*/
#line 406 "weaver_api.tex"

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
#line 439 "weaver_api.tex"
/*:17*//*18:*/
#line 447 "weaver_api.tex"

#if defined(_WIN32)
unsigned long _update_time(void){
LARGE_INTEGER prev;
prev.QuadPart= _last_time.QuadPart;
QueryPerformanceCounter(&_last_time);
return(_last_time.QuadPart-prev.QuadPart);
}
#endif
#line 456 "weaver_api.tex"
/*:18*//*32:*/
#line 812 "weaver_api.tex"

void _update(void){
/*60:*/
#line 1298 "weaver_api.tex"

if(W.pending_files==0)
_Wtrash(memory_arena,1);
/*:60*//*81:*/
#line 1594 "weaver_api.tex"

_Wget_window_input(W.t,&keyboard,&W.mouse);
/*:81*//*97:*/
#line 1841 "weaver_api.tex"

_Winteract_interface(W.mouse.x,W.mouse.y,
W.mouse.button[W_MOUSE_LEFT]> 0,
W.mouse.button[W_MOUSE_MIDDLE]> 0,
W.mouse.button[W_MOUSE_RIGHT]> 0);
/*:97*/
#line 814 "weaver_api.tex"

}
/*:32*//*35:*/
#line 874 "weaver_api.tex"

void _render(void){
/*80:*/
#line 1585 "weaver_api.tex"

_Wrender_window();
/*:80*//*98:*/
#line 1853 "weaver_api.tex"

_Wrender_interface(W.t);
/*:98*/
#line 876 "weaver_api.tex"

}
/*:35*//*41:*/
#line 983 "weaver_api.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*43:*/
#line 1020 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
#line 1024 "weaver_api.tex"
/*:43*//*96:*/
#line 1833 "weaver_api.tex"

_Wrestore_history_interface();
/*:96*/
#line 986 "weaver_api.tex"

/*55:*/
#line 1238 "weaver_api.tex"

_Wtrash(memory_arena,0);
/*:55*/
#line 987 "weaver_api.tex"

_number_of_loops--;
}
/*45:*/
#line 1067 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1603 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*95:*/
#line 1823 "weaver_api.tex"

_Wmark_history_interface();
/*:95*/
#line 990 "weaver_api.tex"

/*107:*/
#line 2011 "weaver_api.tex"

/*:107*/
#line 991 "weaver_api.tex"

/*54:*/
#line 1228 "weaver_api.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
/*:54*/
#line 992 "weaver_api.tex"

_loop_stack[_number_of_loops]= f;
_number_of_loops++;
#if defined(__EMSCRIPTEN__)
emscripten_set_main_loop(f,0,1);
#endif
#line 998 "weaver_api.tex"
 while(1)
f();
}
/*:41*//*44:*/
#line 1033 "weaver_api.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
#line 1038 "weaver_api.tex"
/*45:*/
#line 1067 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1603 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*95:*/
#line 1823 "weaver_api.tex"

_Wmark_history_interface();
/*:95*/
#line 1038 "weaver_api.tex"

/*105:*/
#line 2001 "weaver_api.tex"

/*:105*/
#line 1039 "weaver_api.tex"

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
#endif
#line 1051 "weaver_api.tex"
 while(1)
f();
}
/*:44*//*47:*/
#line 1106 "weaver_api.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*106:*/
#line 2006 "weaver_api.tex"

/*:106*/
#line 1113 "weaver_api.tex"

_number_of_loops--;
/*45:*/
#line 1067 "weaver_api.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1603 "weaver_api.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*95:*/
#line 1823 "weaver_api.tex"

_Wmark_history_interface();
/*:95*/
#line 1115 "weaver_api.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
emscripten_set_main_loop(_loop_stack[_number_of_loops-1],0,1);
#endif
#line 1120 "weaver_api.tex"
 while(1)
_loop_stack[_number_of_loops-1]();
}
}
/*:47*//*56:*/
#line 1250 "weaver_api.tex"

static void*_alloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,0,size);
}
/*:56*//*57:*/
#line 1262 "weaver_api.tex"

static void*_talloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:57*//*71:*/
#line 1498 "weaver_api.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:71*//*90:*/
#line 1727 "weaver_api.tex"

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
/*:90*//*99:*/
#line 1877 "weaver_api.tex"

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
#line 1892 "weaver_api.tex"
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
#line 1905 "weaver_api.tex"
 memcpy(&path_texture[dir_len],"/image/",8);
dir_len+= 7;
memcpy(&path_texture[dir_len],texture,texture_len+1);
}
return _Wnew_interface((texture==NULL)?(NULL):(path_texture),
(shader==NULL)?(NULL):(path_shader),
x,y,z,width,height);
}
/*:99*//*101:*/
#line 1934 "weaver_api.tex"

static struct sound*new_sound(char*audio){
char path_audio[512];
int dir_len,audio_len;
audio_len= strlen(audio);
path_audio[0]= '.';
path_audio[1]= '\0';
dir_len= 1;
#if defined(W_DATA_DIR)
dir_len= strlen(W_DATA_DIR);
memcpy(path_audio,W_DATA_DIR,dir_len+1);
#endif
#line 1946 "weaver_api.tex"
 memcpy(&path_audio[dir_len],"/sound/",8);
dir_len+= 7;
memcpy(&path_audio[dir_len],audio,audio_len+1);
return _Wnew_sound(path_audio);
}
/*:101*/
#line 208 "weaver_api.tex"

/*9:*/
#line 294 "weaver_api.tex"

void Winit(void){
W.game= &_game;
/*15:*/
#line 379 "weaver_api.tex"

#if defined(_WIN32)
QueryPerformanceCounter(&_last_time);
#else
#line 383 "weaver_api.tex"
 gettimeofday(&_last_time,NULL);
#endif
#line 385 "weaver_api.tex"
/*:15*//*21:*/
#line 636 "weaver_api.tex"

_running_loop= false;
_loop_begin= false;
_loop_finalized= false;
/*:21*//*23:*/
#line 670 "weaver_api.tex"

W.pending_files= 0;
W.loop_name[0]= '\0';
/*:23*//*28:*/
#line 761 "weaver_api.tex"

_lag= 0;
/*:28*//*30:*/
#line 790 "weaver_api.tex"

#if !defined(W_TIMESTEP)
#define W_TIMESTEP 40000
#endif
#line 794 "weaver_api.tex"
 W.dt= W_TIMESTEP;
W.t= 0;
/*:30*//*40:*/
#line 967 "weaver_api.tex"

_number_of_loops= 0;
/*:40*//*51:*/
#line 1183 "weaver_api.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:51*//*59:*/
#line 1284 "weaver_api.tex"

W.alloc= _alloc;
W.talloc= _talloc;
/*:59*//*63:*/
#line 1329 "weaver_api.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_alloc,sizeof(seed)/sizeof(uint64_t),seed);
}
#endif
#line 1336 "weaver_api.tex"
/*:63*//*64:*/
#line 1357 "weaver_api.tex"

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
#line 1368 "weaver_api.tex"
/*:64*//*66:*/
#line 1387 "weaver_api.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
#line 1395 "weaver_api.tex"
/*:66*//*67:*/
#line 1417 "weaver_api.tex"

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
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
#line 1435 "weaver_api.tex"
/*:67*//*69:*/
#line 1459 "weaver_api.tex"

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
#line 1480 "weaver_api.tex"
/*:69*//*73:*/
#line 1518 "weaver_api.tex"

W.rand= _rand;
/*:73*//*77:*/
#line 1559 "weaver_api.tex"

W.keyboard= keyboard.key;
/*:77*//*78:*/
#line 1569 "weaver_api.tex"

_Wcreate_window(&keyboard,&W.mouse);
/*:78*//*85:*/
#line 1641 "weaver_api.tex"

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
#line 1656 "weaver_api.tex"
/*:85*//*88:*/
#line 1701 "weaver_api.tex"

MUTEX_INIT(&pending_files_mutex);
MUTEX_INIT(&loading_files);
/*:88*//*91:*/
#line 1748 "weaver_api.tex"

{
int*window_width= &W.width,*window_height= &W.height;
#if defined(W_FORCE_LANDSCAPE)
if(rotated_screen){
*window_width= &W.height;
*window_height= &W.width;
}
#endif
#line 1757 "weaver_api.tex"
/*93:*/
#line 1781 "weaver_api.tex"

{
int dpi_x,dpi_y;
if(!_Wget_screen_dpi(&dpi_x,&dpi_y)){
dpi_x= dpi_y= 96;
}
if(!_Winit_weavefont(_talloc,NULL,_alloc,NULL,_rand,(dpi_x+dpi_y)/2)){
fprintf(stderr,"ERROR: Test cannot be done. Initialization failed.\n");
exit(1);
}
}
/*:93*/
#line 1757 "weaver_api.tex"

_Winit_interface(window_width,window_height,_alloc,NULL,
_talloc,NULL,before_loading_resources,
after_loading_resources,

"mf",_Wmetafont_loading,
"wav",_extract_wave,
NULL);
}
/*:91*//*104:*/
#line 1982 "weaver_api.tex"

W.new_interface= new_interface;
W.new_sound= new_sound;
W.link_interface= _Wlink_interface;
W.rotate_interface= _Wrotate_interface;
W.resize_interface= _Wresize_interface;
W.move_interface= _Wmove_interface;
W.play_sound= _Wplay_sound;
/*:104*/
#line 297 "weaver_api.tex"

}
/*:9*//*11:*/
#line 314 "weaver_api.tex"

void Wexit(void){
/*70:*/
#line 1488 "weaver_api.tex"

_Wdestroy_rng(NULL,rng);
/*:70*//*79:*/
#line 1575 "weaver_api.tex"

_Wdestroy_window();
/*:79*//*89:*/
#line 1710 "weaver_api.tex"

MUTEX_DESTROY(&pending_files_mutex);
MUTEX_DESTROY(&loading_files);
/*:89*//*94:*/
#line 1804 "weaver_api.tex"

_Wfinish_interface();
/*:94*/
#line 316 "weaver_api.tex"

/*52:*/
#line 1195 "weaver_api.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:52*/
#line 317 "weaver_api.tex"

exit(0);
}
/*:11*/
#line 209 "weaver_api.tex"

/*:4*/
