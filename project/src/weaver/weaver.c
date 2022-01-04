/*4:*/
#line 181 "weaver_api_en.tex"

#include "weaver.h"
#include "../game.h"
/*50:*/
#line 1117 "weaver_api_en.tex"

#include "memory.h"
/*:50*//*61:*/
#line 1250 "weaver_api_en.tex"

#include "random.h"
/*:61*//*65:*/
#line 1311 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(__linux__)
#include <sys/random.h> 
#endif
/*:65*//*68:*/
#line 1377 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(_WIN32)
#include <bcrypt.h> 
#endif
/*:68*//*98:*/
#line 1817 "weaver_api_en.tex"

#include <string.h> 
/*:98*/
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
#line 1109 "weaver_api_en.tex"

static void*memory_arena;
/*:49*//*62:*/
#line 1258 "weaver_api_en.tex"

static struct _Wrng*rng;
/*:62*//*76:*/
#line 1482 "weaver_api_en.tex"

static struct _Wkeyboard keyboard;
/*:76*//*83:*/
#line 1552 "weaver_api_en.tex"

#if defined(W_FORCE_LANDSCAPE)
static bool rotated_screen;
#endif
/*:83*//*87:*/
#line 1619 "weaver_api_en.tex"

STATIC_MUTEX_DECLARATION(pending_files_mutex);
STATIC_MUTEX_DECLARATION(loading_files);
/*:87*/
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
/*81:*/
#line 1525 "weaver_api_en.tex"

_Wget_window_input(W.t,&keyboard,&W.mouse);
/*:81*//*95:*/
#line 1739 "weaver_api_en.tex"

_Winteract_interface(W.mouse.x,W.mouse.y,
W.mouse.button[W_MOUSE_LEFT]> 0,
W.mouse.button[W_MOUSE_MIDDLE]> 0,
W.mouse.button[W_MOUSE_RIGHT]> 0);
/*:95*/
#line 772 "weaver_api_en.tex"

}
/*:32*//*35:*/
#line 825 "weaver_api_en.tex"

void _render(void){
/*80:*/
#line 1516 "weaver_api_en.tex"

_Wrender_window();
/*:80*//*96:*/
#line 1751 "weaver_api_en.tex"

_Wrender_interface(W.t);
/*:96*/
#line 827 "weaver_api_en.tex"

}
/*:35*//*41:*/
#line 928 "weaver_api_en.tex"

void _Wloop(void(*f)(void)){
if(_number_of_loops> 0){
/*43:*/
#line 967 "weaver_api_en.tex"

#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*:43*//*94:*/
#line 1730 "weaver_api_en.tex"

_Wrestore_history_interface();
/*:94*/
#line 931 "weaver_api_en.tex"

/*55:*/
#line 1179 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
/*:55*/
#line 932 "weaver_api_en.tex"

_number_of_loops--;
}
/*45:*/
#line 1014 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1534 "weaver_api_en.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*93:*/
#line 1720 "weaver_api_en.tex"

_Wmark_history_interface();
/*:93*/
#line 935 "weaver_api_en.tex"

/*104:*/
#line 1873 "weaver_api_en.tex"
/*:104*/
#line 936 "weaver_api_en.tex"

/*54:*/
#line 1169 "weaver_api_en.tex"

_Wmempoint(memory_arena,W_MEMORY_ALIGNMENT,0);
/*:54*/
#line 937 "weaver_api_en.tex"

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
#line 979 "weaver_api_en.tex"

void Wsubloop(void(*f)(void)){
#if defined(__EMSCRIPTEN__)
emscripten_cancel_main_loop();
#endif
/*45:*/
#line 1014 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1534 "weaver_api_en.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*93:*/
#line 1720 "weaver_api_en.tex"

_Wmark_history_interface();
/*:93*/
#line 984 "weaver_api_en.tex"

/*102:*/
#line 1865 "weaver_api_en.tex"
/*:102*/
#line 985 "weaver_api_en.tex"

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
#line 1051 "weaver_api_en.tex"

void _exit_loop(void){
if(_number_of_loops<=1){
Wexit();
exit(1);
}
else{
/*103:*/
#line 1869 "weaver_api_en.tex"
/*:103*/
#line 1058 "weaver_api_en.tex"

_number_of_loops--;
/*45:*/
#line 1014 "weaver_api_en.tex"

_running_loop= true;
_loop_begin= true;
_loop_finalized= false;
_update_time();
/*:45*//*82:*/
#line 1534 "weaver_api_en.tex"

_Wflush_window_input(&keyboard,&W.mouse);
/*:82*//*93:*/
#line 1720 "weaver_api_en.tex"

_Wmark_history_interface();
/*:93*/
#line 1060 "weaver_api_en.tex"

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
/*:56*//*57:*/
#line 1201 "weaver_api_en.tex"

static void*_talloc(size_t size){
return _Walloc(memory_arena,W_MEMORY_ALIGNMENT,1,size);
}
/*:57*//*71:*/
#line 1432 "weaver_api_en.tex"

static uint64_t _rand(void){
return _Wrand(rng);
}
/*:71*//*90:*/
#line 1653 "weaver_api_en.tex"

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
/*:90*//*97:*/
#line 1775 "weaver_api_en.tex"

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
/*:97*/
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
#line 1126 "weaver_api_en.tex"

memory_arena= _Wcreate_arena(W_MAX_MEMORY);
/*:51*//*59:*/
#line 1223 "weaver_api_en.tex"

W.alloc= _alloc;
W.talloc= _talloc;
/*:59*//*63:*/
#line 1268 "weaver_api_en.tex"

#if defined(W_RNG_SEED)
{
uint64_t seed[]= W_RNG_SEED;
rng= _Wcreate_rng(_alloc,sizeof(seed)/sizeof(uint64_t),seed);
}
#endif
/*:63*//*64:*/
#line 1294 "weaver_api_en.tex"

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
/*:64*//*66:*/
#line 1323 "weaver_api_en.tex"

#if !defined(W_RNG_SEED) && defined(BSD)
{
uint64_t buffer[4];
arc4random_buf(buffer,4*8);
rng= _Wcreate_rng(_alloc,4,buffer);
}
#endif
/*:66*//*67:*/
#line 1353 "weaver_api_en.tex"

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
/*:67*//*69:*/
#line 1393 "weaver_api_en.tex"

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
/*:69*//*73:*/
#line 1451 "weaver_api_en.tex"

W.rand= _rand;
/*:73*//*77:*/
#line 1491 "weaver_api_en.tex"

W.keyboard= keyboard.key;
/*:77*//*78:*/
#line 1501 "weaver_api_en.tex"

_Wcreate_window(&keyboard,&W.mouse);
/*:78*//*85:*/
#line 1571 "weaver_api_en.tex"

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
/*:85*//*88:*/
#line 1629 "weaver_api_en.tex"

MUTEX_INIT(&pending_files_mutex);
MUTEX_INIT(&loading_files);
/*:88*//*91:*/
#line 1675 "weaver_api_en.tex"

{
int*window_width= &W.width,*window_height= &W.height;
#if defined(W_FORCE_LANDSCAPE)
if(rotated_screen){
*window_width= &W.height;
*window_height= &W.width;
}
#endif
_Winit_interface(window_width,window_height,_alloc,NULL,
_talloc,NULL,before_loading_resources,
after_loading_resources,NULL);
}
/*:91*//*101:*/
#line 1847 "weaver_api_en.tex"

W.new_interface= new_interface;
W.link_interface= _Wlink_interface;
W.rotate_interface= _Wrotate_interface;
W.resize_interface= _Wresize_interface;
W.move_interface= _Wmove_interface;
/*:101*/
#line 276 "weaver_api_en.tex"

}
/*:9*//*11:*/
#line 293 "weaver_api_en.tex"

void Wexit(void){
/*70:*/
#line 1422 "weaver_api_en.tex"

_Wdestroy_rng(NULL,rng);
/*:70*//*79:*/
#line 1507 "weaver_api_en.tex"

_Wdestroy_window();
/*:79*//*89:*/
#line 1638 "weaver_api_en.tex"

MUTEX_DESTROY(&pending_files_mutex);
MUTEX_DESTROY(&loading_files);
/*:89*//*92:*/
#line 1701 "weaver_api_en.tex"

_Wfinish_interface();
/*:92*/
#line 295 "weaver_api_en.tex"

/*52:*/
#line 1138 "weaver_api_en.tex"

_Wtrash(memory_arena,0);
_Wtrash(memory_arena,1);
_Wdestroy_arena(memory_arena);
/*:52*/
#line 296 "weaver_api_en.tex"

exit(0);
}
/*:11*/
#line 189 "weaver_api_en.tex"

/*:4*/
