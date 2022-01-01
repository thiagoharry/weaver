/*1:*/
#line 214 "weaver_program.tex"

/*3:*/
#line 289 "weaver_program.tex"

#if defined(_WIN32)
#define _CRT_SECURE_NO_WARNING
#endif
#include <stdio.h>  
#include <stdbool.h>  
#include <stdlib.h>  
/*:3*//*7:*/
#line 387 "weaver_program.tex"

#if !defined(_WIN32)
#include <sys/types.h>  
#include <sys/stat.h>  
#else
#include <windows.h>  
#endif
/*:7*//*9:*/
#line 446 "weaver_program.tex"

#include <string.h>  
#include <stdarg.h>  
/*:9*//*11:*/
#line 484 "weaver_program.tex"

#if !defined(_WIN32)
#include <libgen.h> 
#endif
/*:11*//*16:*/
#line 638 "weaver_program.tex"

#if !defined(_WIN32)
#include <dirent.h>  
#endif
/*:16*//*22:*/
#line 901 "weaver_program.tex"

#if !defined(_WIN32)
#include <unistd.h>  
#endif
/*:22*//*32:*/
#line 1153 "weaver_program.tex"

#include <ctype.h>  
/*:32*//*38:*/
#line 1357 "weaver_program.tex"

#if !defined(_WIN32)
#include <pwd.h>  
#else
#define SECURITY_WIN32
#include <Security.h> 
#include <Lmcons.h> 
#endif
/*:38*//*42:*/
#line 1435 "weaver_program.tex"

#include <time.h>  
/*:42*/
#line 215 "weaver_program.tex"

/*2:*/
#line 266 "weaver_program.tex"

#define VERSION "Alpha"
#define W_ERROR() {perror(NULL); return_value =  1; goto END_OF_PROGRAM;}
#define END() goto END_OF_PROGRAM;
/*:2*//*5:*/
#line 354 "weaver_program.tex"

#define NAO_EXISTE             0
#define EXISTE_E_EH_DIRETORIO  1
#define EXISTE_E_EH_ARQUIVO   -1
/*:5*/
#line 216 "weaver_program.tex"

/*4:*/
#line 318 "weaver_program.tex"

void path_up(char*path){
#if !defined(_WIN32)
char separator= '/';
#else
char separator= '\\';
#endif
int erased= 0;
char*p= path;
while(*p!='\0')p++;
while(erased<2&&p!=path){
p--;
if(*p==separator)erased++;
*p= '\0';
}
}
/*:4*//*6:*/
#line 362 "weaver_program.tex"

int directory_exist(char*dir){
#if !defined(_WIN32)

struct stat s;
int err;
err= stat(dir,&s);
if(err==-1)return NAO_EXISTE;
if(S_ISDIR(s.st_mode))return EXISTE_E_EH_DIRETORIO;
return EXISTE_E_EH_ARQUIVO;
#else

DWORD dwAttrib= GetFileAttributes(dir);
if(dwAttrib==INVALID_FILE_ATTRIBUTES)return NAO_EXISTE;
if(!(dwAttrib&FILE_ATTRIBUTE_DIRECTORY))return EXISTE_E_EH_ARQUIVO;
else return EXISTE_E_EH_DIRETORIO;
#endif
}
/*:6*//*8:*/
#line 407 "weaver_program.tex"

char*concatenate(char*string,...){
va_list arguments;
char*new_string,*current_string= string;
size_t current_size= strlen(string)+1;
char*realloc_return;
va_start(arguments,string);
new_string= (char*)malloc(current_size);
if(new_string==NULL)return NULL;

memcpy(new_string,string,current_size);
while(current_string!=NULL&&current_string[0]!='\0'){
size_t increment_length,last_length;
current_string= va_arg(arguments,char*);
increment_length= strlen(current_string);
last_length= current_size;
current_size+= increment_length;
realloc_return= (char*)realloc(new_string,current_size);
if(realloc_return==NULL){
free(new_string);
return NULL;
}
new_string= realloc_return;

memcpy(&(new_string[last_length-1]),current_string,increment_length+1);
}
return new_string;
}
/*:8*//*10:*/
#line 461 "weaver_program.tex"

#if defined(_WIN32)
char*basename(char*path){
char*p= path;
char*last_delimiter= NULL;
while(*p!='\0'){
if(*p=='\\')
last_delimiter= p;
p++;
}
if(last_delimiter!=NULL)
return last_delimiter+1;
else
return path;
}
#endif
/*:10*//*12:*/
#line 499 "weaver_program.tex"

int copy_single_file(char*file,char*directory){
int block_size,bytes_read;
char*buffer,*file_dst;
FILE*orig,*dst;

/*13:*/
#line 541 "weaver_program.tex"

#if !defined(_WIN32)
{
struct stat s;
stat(directory,&s);
block_size= s.st_blksize;
if(block_size<=0){
block_size= 4096;
}
}
#endif
/*:13*//*14:*/
#line 558 "weaver_program.tex"

#if defined(_WIN32)
block_size= 4096;
#endif
/*:14*/
#line 505 "weaver_program.tex"

buffer= (char*)malloc(block_size);
if(buffer==NULL)return 0;
file_dst= concatenate(directory,"/",basename(file),"");
if(file_dst==NULL)return 0;
orig= fopen(file,"r");
if(orig==NULL){
free(buffer);
free(file_dst);
return 0;
}
dst= fopen(file_dst,"w");
if(dst==NULL){
fclose(orig);
free(buffer);
free(file_dst);
return 0;
}
while((bytes_read= fread(buffer,1,block_size,orig))> 0){
fwrite(buffer,1,bytes_read,dst);
}
fclose(orig);
fclose(dst);
free(file_dst);
free(buffer);
return 1;
}
/*:12*//*15:*/
#line 577 "weaver_program.tex"

#if !defined(_WIN32)
int copy_files(char*orig,char*dst){
DIR*d= NULL;
struct dirent*dir;
d= opendir(orig);
if(d){
while((dir= readdir(d))!=NULL){
char*file;
file= concatenate(orig,"/",dir->d_name,"");
if(file==NULL){
return 0;
}
#if (defined(__linux__) || defined(_BSD_SOURCE)) && defined(DT_DIR)

if(dir->d_type==DT_DIR){
#else
struct stat s;
int err;
err= stat(file,&s);
if(err==-1)return 0;
if(S_ISDIR(s.st_mode)){
#endif

char*new_dst;
new_dst= concatenate(dst,"/",dir->d_name,"");
if(new_dst==NULL){
return 0;
}
if(strcmp(dir->d_name,".")&&strcmp(dir->d_name,"..")){
if(directory_exist(new_dst)==NAO_EXISTE)mkdir(new_dst,0755);
if(copy_files(file,new_dst)==0){
free(new_dst);
free(file);
closedir(d);
return 0;
}
}
free(new_dst);
}
else{

if(copy_single_file(file,dst)==0){
free(file);
closedir(d);
return 0;
}
}
free(file);
}
closedir(d);
}
return 1;
}
#endif
/*:15*//*17:*/
#line 649 "weaver_program.tex"

#if defined(_WIN32)
int copy_files(char*orig,char*dst){
char*path,*search_path;
WIN32_FIND_DATA file;
HANDLE dir= NULL;
search_path= concatenate(orig,"\\*","");
if(search_path==NULL)
return 0;
dir= FindFirstFile(search_path,&file);
if(dir!=INVALID_HANDLE_VALUE){

do{
if(strcmp(file.cFileName,".")&&strcmp(file.cFileName,"..")){
path= concatenate(orig,"\\",file.cFileName,"");
if(path==NULL){
free(search_path);
return 0;
}
if(file.dwFileAttributes&FILE_ATTRIBUTE_DIRECTORY){
char*dst_path;
dst_path= concatenate(dst,"\\",file.cFileName,"");
if(directory_exist(dst_path)==NAO_EXISTE)
CreateDirectoryA(dst_path,NULL);
if(copy_files(path,dst_path)==0){
free(dst_path);
free(path);
FindClose(dir);
free(search_path);
return 0;
}
free(dst_path);
}
else{
if(copy_single_file(path,dst)==0){
free(path);
FindClose(dir);
free(search_path);
return 0;
}
}
free(path);
}
}while(FindNextFile(dir,&file));
}
free(search_path);
FindClose(dir);
return 1;
}
#endif
/*:17*//*18:*/
#line 713 "weaver_program.tex"

void write_copyright(FILE*fp,char*author_name,char*project_name,int year){
char license[]= "/*\nCopyright (c) %s, %d\n\nThis file is part of %s.\n\n%s\
 is free software: you can redistribute it and/or modify\nit under the terms of\
 the GNU Affero General Public License as published by\nthe Free Software\
 Foundation, either version 3 of the License, or\n(at your option) any later\
 version.\n\n\
%s is distributed in the hope that it will be useful,\nbut WITHOUT ANY\
  WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS\
  FOR A PARTICULAR PURPOSE.  See the\nGNU Affero General Public License for more\
  details.\n\nYou should have received a copy of the GNU Affero General Public License\
\nalong with %s. If not, see <http://www.gnu.org/licenses/>.\n*/\n\n";
fprintf(fp,license,author_name,year,project_name,project_name,
project_name,project_name);
}
/*:18*//*19:*/
#line 758 "weaver_program.tex"

int create_dir(char*string,...){
char*current_string;
va_list arguments;
va_start(arguments,string);
int err= 1;
current_string= string;
while(current_string!=NULL&&current_string[0]!='\0'&&err!=-1){
#if !defined(_WIN32)
err= mkdir(current_string,S_IRWXU|S_IRWXG|S_IROTH);
#else
if(!CreateDirectoryA(current_string,NULL))
err= -1;
#endif
current_string= va_arg(arguments,char*);
}
return err;
}
/*:19*//*20:*/
#line 794 "weaver_program.tex"

int append_file(FILE*fp,char*dir,char*file){
int block_size,bytes_read;
char*buffer,*directory= ".";
char*path= concatenate(dir,file,"");
if(path==NULL)return 0;
FILE*origin;
/*13:*/
#line 541 "weaver_program.tex"

#if !defined(_WIN32)
{
struct stat s;
stat(directory,&s);
block_size= s.st_blksize;
if(block_size<=0){
block_size= 4096;
}
}
#endif
/*:13*//*14:*/
#line 558 "weaver_program.tex"

#if defined(_WIN32)
block_size= 4096;
#endif
/*:14*/
#line 801 "weaver_program.tex"

buffer= (char*)malloc(block_size);
if(buffer==NULL){
free(path);
return 0;
}
origin= fopen(path,"r");
if(origin==NULL){
free(buffer);
free(path);
return 0;
}
while((bytes_read= fread(buffer,1,block_size,origin))> 0){
fwrite(buffer,1,bytes_read,fp);
}
fclose(origin);
free(buffer);
free(path);
return 1;
}
/*:20*/
#line 217 "weaver_program.tex"

int main(int argc,char**argv){
int return_value= 0;
bool inside_weaver_directory= false,arg_is_path= false,
arg_is_valid_project= false,arg_is_valid_module= false,
have_arg= false,
arg_is_valid_function= false;
unsigned int project_version_major= 0,project_version_minor= 0,
weaver_version_major= 0,weaver_version_minor= 0,
year= 0;

char*argument= NULL,*project_path= NULL,*shared_dir= NULL,
*author_name= NULL,*project_name= NULL,*argument2= NULL;
/*21:*/
#line 879 "weaver_program.tex"

char*path= NULL,*complete_path= NULL;
#if !defined(_WIN32)
path= getcwd(NULL,0);
#else
{
DWORD bsize;
bsize= GetCurrentDirectory(0,NULL);
path= (char*)malloc(bsize);
GetCurrentDirectory(bsize,path);
}
#endif
if(path==NULL)W_ERROR();
complete_path= concatenate(path,"/.weaver","");
free(path);
if(complete_path==NULL)W_ERROR();
/*:21*//*23:*/
#line 915 "weaver_program.tex"

{

while(strcmp(complete_path,"/.weaver")&&
strcmp(complete_path,"\\.weaver")&&
strcmp(complete_path+1,":\\.weaver")){
if(directory_exist(complete_path)==EXISTE_E_EH_DIRETORIO){
inside_weaver_directory= true;
complete_path[strlen(complete_path)-7]= '\0';
project_path= concatenate(complete_path,"");
if(project_path==NULL){free(complete_path);W_ERROR();}
break;
}
else{
path_up(complete_path);
#ifdef __OpenBSD__
{
size_t tmp_size= strlen(complete_path);
strlcat(complete_path,"/.weaver",tmp_size+9);
}
#else
strcat(complete_path,"/.weaver");
#endif
}
}
free(complete_path);
}
/*:23*//*25:*/
#line 967 "weaver_program.tex"

{
char*p= VERSION;
while(*p!='.'&&*p!='\0')p++;
if(*p=='.')p++;
weaver_version_major= atoi(VERSION);
weaver_version_minor= atoi(p);
}
/*:25*//*26:*/
#line 988 "weaver_program.tex"

if(inside_weaver_directory){
FILE*fp;
char*p,version[10];
char*file_path= concatenate(project_path,".weaver/version","");
if(file_path==NULL)W_ERROR();
fp= fopen(file_path,"r");
free(file_path);
if(fp==NULL)W_ERROR();
p= fgets(version,10,fp);
if(p==NULL){fclose(fp);W_ERROR();}
while(*p!='.'&&*p!='\0')p++;
if(*p=='.')p++;
project_version_major= atoi(version);
project_version_minor= atoi(p);
fclose(fp);
}
/*:26*//*27:*/
#line 1014 "weaver_program.tex"

have_arg= (argc> 1);
if(have_arg)argument= argv[1];
if(argc> 2)argument2= argv[2];
/*:27*//*28:*/
#line 1029 "weaver_program.tex"

if(have_arg){
char*buffer= concatenate(argument,"/.weaver","");
if(buffer==NULL)W_ERROR();
if(directory_exist(buffer)==EXISTE_E_EH_DIRETORIO){
arg_is_path= 1;
}
free(buffer);
}
/*:28*//*29:*/
#line 1053 "weaver_program.tex"

{
#ifdef WEAVER_DIR
shared_dir= concatenate(WEAVER_DIR,"");
#else
#if !defined(_WIN32)
shared_dir= concatenate("/usr/local/share/weaver/","");
#else
{
char*temp_buf= NULL;
DWORD bsize= GetEnvironmentVariable("ProgramFiles",temp_buf,0);
temp_buf= (char*)malloc(bsize);
GetEnvironmentVariable("ProgramFiles",temp_buf,bsize);
shared_dir= concatenate(temp_buf,"\\weaver\\","");
free(temp_buf);
}
#endif
#endif
if(shared_dir==NULL)W_ERROR();
}
/*:29*//*31:*/
#line 1119 "weaver_program.tex"

if(have_arg&&!arg_is_path){
char*buffer;
char*base= basename(argument);
int size= strlen(base);
int i;

for(i= 0;i<size;i++){
if(!isalnum(base[i])&&base[i]!='_'){
goto NOT_VALID;
}
}

if(directory_exist(argument)!=NAO_EXISTE){
goto NOT_VALID;
}

buffer= concatenate(shared_dir,"project/",base,"");
if(buffer==NULL)W_ERROR();
if(directory_exist(buffer)!=NAO_EXISTE){
free(buffer);
goto NOT_VALID;
}
free(buffer);
arg_is_valid_project= true;
}
NOT_VALID:
/*:31*//*33:*/
#line 1169 "weaver_program.tex"

if(have_arg&&inside_weaver_directory){
char*buffer;
int i,size;
size= strlen(argument);

for(i= 0;i<size;i++){
if(!isalnum(argument[i])&&argument[i]!='_'){
goto NOT_VALID_MODULE;
}
}

buffer= concatenate(project_path,"src/",argument,".c","");
if(buffer==NULL)W_ERROR();
if(directory_exist(buffer)!=NAO_EXISTE){
free(buffer);
goto NOT_VALID_MODULE;
}
buffer[strlen(buffer)-1]= 'h';
if(directory_exist(buffer)!=NAO_EXISTE){
free(buffer);
goto NOT_VALID_MODULE;
}
free(buffer);
arg_is_valid_module= true;
}
NOT_VALID_MODULE:
/*:33*//*34:*/
#line 1209 "weaver_program.tex"

if(argument2!=NULL&&inside_weaver_directory&&
!strcmp(argument,"--loop")){
int i,size;
char*buffer;

if(isdigit(argument2[0]))
goto NOT_VALID_FUNCTION;
size= strlen(argument2);

for(i= 0;i<size;i++){
if(!isalnum(argument2[i])&&argument2[i]!='_'){
goto NOT_VALID_FUNCTION;
}
}

buffer= concatenate(project_path,"src/",argument2,".c","");
if(buffer==NULL)W_ERROR();
if(directory_exist(buffer)!=NAO_EXISTE){
free(buffer);
goto NOT_VALID_FUNCTION;
}
buffer[strlen(buffer)-1]= 'h';
if(directory_exist(buffer)!=NAO_EXISTE){
free(buffer);
goto NOT_VALID_FUNCTION;
}
free(buffer);

const char*reserved[]= {"alignas","alignof","and","and_eq",
"asm","auto","bitand","bitor","bool",
"break","case","catch","char","char8_t",
"char16_t","char32_t","class","compl",
"concept","const","consteval","constexpr",
"constinit","const_cast","continue",
"co_await","co_return","co_yield",
"decltype","default","delete","do",
"double","dynamic_cast","else","enum",
"explicit","export","extern","false",
"float","for","friend","goto","if",
"inline","int","long","mutable",
"namespace","new","noexcept","not",
"not_eq","nullptr","operator","or",
"or_eq","private","protected","public",
"register","reinterpret_cast","requires",
"restrict","return","short","signed",
"sizeof","static","static_assert",
"static_cast","struct","switch","template",
"this","thread_local","throw","true",
"try","typedef","typeid","typename",
"union","unsigned","using","virtual",
"void","volatile","xor","xor_eq",
"wchar_t","while",NULL};
for(i= 0;reserved[i]!=NULL;i++)
if(!strcmp(argument2,reserved[i]))
goto NOT_VALID_FUNCTION;
arg_is_valid_function= true;
}
NOT_VALID_FUNCTION:
/*:34*//*35:*/
#line 1284 "weaver_program.tex"

#if !defined(_WIN32)
{
struct passwd*login;
int size;
char*string_to_copy;
login= getpwuid(getuid());
if(login==NULL)W_ERROR();
size= strlen(login->pw_gecos);
if(size> 0)
string_to_copy= login->pw_gecos;
else
string_to_copy= login->pw_name;
size= strlen(string_to_copy);
author_name= (char*)malloc(size+1);
if(author_name==NULL)W_ERROR();
#ifdef __OpenBSD__
strlcpy(author_name,string_to_copy,size+1);
#else
strcpy(author_name,string_to_copy);
#endif
}
#endif
/*:35*//*36:*/
#line 1319 "weaver_program.tex"

#if defined(_WIN32)
{
int size= 0;
GetUserNameExA(NameDisplay,author_name,&size);
if(GetLastError()==ERROR_MORE_DATA){
if(size==0)
size= 64;
author_name= (char*)malloc(size);
if(GetUserNameExA(NameDisplay,author_name,&size)==0){
size= UNLEN+1;
author_name= (char*)malloc(size);
GetUserNameA(author_name,&size);
}
}
else{
size= UNLEN+1;
author_name= (char*)malloc(size);
GetUserNameA(author_name,&size);
}
}
#endif
/*:36*//*39:*/
#line 1375 "weaver_program.tex"

if(inside_weaver_directory){
FILE*fp;
char*c;
#if !defined(_WIN32)
char*filename= concatenate(project_path,".weaver/name","");
#else
char*filename= concatenate(project_path,".weaver\name","");
#endif
if(filename==NULL)W_ERROR();
project_name= (char*)malloc(256);
if(project_name==NULL){
free(filename);
W_ERROR();
}
fp= fopen(filename,"r");
if(fp==NULL){
free(filename);
W_ERROR();
}
c= fgets(project_name,256,fp);
fclose(fp);
free(filename);
if(c==NULL)W_ERROR();
project_name[strlen(project_name)-1]= '\0';
project_name= realloc(project_name,strlen(project_name)+1);
if(project_name==NULL)W_ERROR();
}
/*:39*//*41:*/
#line 1420 "weaver_program.tex"

{
time_t current_time;
struct tm*date;
time(&current_time);
date= localtime(&current_time);
year= date->tm_year+1900;
}
/*:41*/
#line 230 "weaver_program.tex"

/*43:*/
#line 1466 "weaver_program.tex"

if(!inside_weaver_directory&&(!have_arg||!strcmp(argument,"--help"))){
printf("    .  .     You are outside a Weaver Directory.\n"
"   .|  |.    The following command uses are available:\n"
"   ||  ||\n"
"   \\\\()//  weaver\n"
"   .={}=.      Print this message and exits.\n"
"  / /`'\\ \\\n"
"  ` \\  / '  weaver PROJECT_NAME\n"
"     `'        Creates a new Weaver Directory with a new\n"
"               project.\n");
END();
}
/*:43*/
#line 231 "weaver_program.tex"

/*44:*/
#line 1509 "weaver_program.tex"

if(inside_weaver_directory&&(!have_arg||!strcmp(argument,"--help"))){
printf("       \\                You are inside a Weaver Directory.\n"
"        \\______/        The following command uses are available:\n"
"        /\\____/\\\n"
"       / /\\__/\\ \\       weaver\n"
"    __/_/_/\\/\\_\\_\\___     Prints this message and exits.\n"
"      \\ \\ \\/\\/ / /\n"
"       \\ \\/__\\/ /       weaver NAME\n"
"        \\/____\\/          Creates NAME.c and NAME.h, updating\n"
"        /      \\          the Makefile and headers\n"
"       /\n"
"                        weaver --loop NAME\n"
"                         Creates a new main loop in a new file src/NAME.c\n");
END();
}
/*:44*/
#line 232 "weaver_program.tex"

/*45:*/
#line 1534 "weaver_program.tex"

if(have_arg&&!strcmp(argument,"--version")){
printf("Weaver\t%s\n",VERSION);
END();
}
/*:45*/
#line 233 "weaver_program.tex"

/*46:*/
#line 1581 "weaver_program.tex"

if(arg_is_path){
if((weaver_version_major==0&&weaver_version_minor==0)||
(weaver_version_major> project_version_major)||
(weaver_version_major==project_version_major&&
weaver_version_minor>=project_version_minor)){
char*buffer,*buffer2;

buffer= concatenate(shared_dir,"project/src/weaver/","");
if(buffer==NULL)W_ERROR();

buffer2= concatenate(argument,"/src/weaver/","");
if(buffer2==NULL){
free(buffer);
W_ERROR();
}
if(copy_files(buffer,buffer2)==0){
free(buffer);
free(buffer2);
W_ERROR();
}
free(buffer);
free(buffer2);
}
END();
}
/*:46*/
#line 234 "weaver_program.tex"

/*47:*/
#line 1637 "weaver_program.tex"

if(inside_weaver_directory&&have_arg&&
strcmp(argument,"--plugin")&&strcmp(argument,"--shader")&&
strcmp(argument,"--loop")){
if(arg_is_valid_module){
char*filename;
FILE*fp;

filename= concatenate(project_path,"src/",argument,".c","");
if(filename==NULL)W_ERROR();
fp= fopen(filename,"w");
if(fp==NULL){
free(filename);
W_ERROR();
}
write_copyright(fp,author_name,project_name,year);
fprintf(fp,"#include \"%s.h\"",argument);
fclose(fp);
filename[strlen(filename)-1]= 'h';
fp= fopen(filename,"w");
if(fp==NULL){
free(filename);
W_ERROR();
}
write_copyright(fp,author_name,project_name,year);
fprintf(fp,"#ifndef _%s_h_\n",argument);
fprintf(fp,"#define _%s_h_\n\n#include \"weaver/weaver.h\"\n",
argument);
fprintf(fp,"#include \"includes.h\"\n\n#endif");
fclose(fp);
free(filename);


fp= fopen("src/includes.h","a");
fprintf(fp,"#include \"%s.h\"\n",argument);
fclose(fp);
}
else{
fprintf(stderr,"ERROR: This module name is invalid.\n");
return_value= 1;
}
END();
}
/*:47*/
#line 235 "weaver_program.tex"

/*48:*/
#line 1697 "weaver_program.tex"

if(!inside_weaver_directory&&have_arg){
if(arg_is_valid_project){
int err;
char*dir_name;
FILE*fp;
err= create_dir(argument,NULL);
if(err==-1)W_ERROR();
#if !defined(_WIN32) 
err= chdir(argument);
#else
err= _chdir(argument);
#endif
if(err==-1)W_ERROR();
err= create_dir(".weaver","conf","tex","src","src/weaver",
"fonts","image","sound","models","music",
"plugins","src/misc","src/misc/sqlite",
"compiled_plugins","shaders","");
if(err==-1)W_ERROR();
dir_name= concatenate(shared_dir,"project","");
if(dir_name==NULL)W_ERROR();
if(copy_files(dir_name,".")==0){
free(dir_name);
W_ERROR();
}
free(dir_name);
fp= fopen(".weaver/version","w");
fprintf(fp,"%s\n",VERSION);
fclose(fp);
fp= fopen(".weaver/name","w");
fprintf(fp,"%s\n",basename(argv[1]));
fclose(fp);
fp= fopen("src/game.c","w");
if(fp==NULL)W_ERROR();
write_copyright(fp,author_name,argument,year);
if(append_file(fp,shared_dir,"basefile.c")==0)W_ERROR();
fclose(fp);
fp= fopen("src/game.h","w");
if(fp==NULL)W_ERROR();
write_copyright(fp,author_name,argument,year);
if(append_file(fp,shared_dir,"basefile.h")==0)W_ERROR();
fclose(fp);
fp= fopen("src/includes.h","w");
write_copyright(fp,author_name,argument,year);
fprintf(fp,"\n#include \"weaver/weaver.h\"\n");
fprintf(fp,"\n#include \"game.h\"\n");
fclose(fp);
}
else{
fprintf(stderr,"ERROR: %s is not a valid project name.",argument);
return_value= 1;
}
END();
}
/*:48*/
#line 236 "weaver_program.tex"

/*49:*/
#line 1768 "weaver_program.tex"

if(inside_weaver_directory&&!strcmp(argument,"--loop")){
if(!arg_is_valid_function){
if(argument2==NULL)
fprintf(stderr,
"ERROR: You should pass a name for your new loop.\n");
else
fprintf(stderr,"ERROR: %s not a valid loop name.\n",argument2);
W_ERROR();
}
char*filename;
FILE*fp;

filename= concatenate(project_path,"src/",argument2,".c","");
if(filename==NULL)W_ERROR();
fp= fopen(filename,"w");
if(fp==NULL){
free(filename);
W_ERROR();
}
write_copyright(fp,author_name,project_name,year);
fprintf(fp,"#include \"%s.h\"\n\n",argument2);
fprintf(fp,"MAIN_LOOP %s(void){\n",argument2);
fprintf(fp," LOOP_INIT:\n\n");
fprintf(fp," LOOP_BODY:\n");
fprintf(fp,"  if(W.keyboard[W_ANY])\n");
fprintf(fp,"    Wexit_loop();\n");
fprintf(fp," LOOP_END:\n");
fprintf(fp,"  return;\n");
fprintf(fp,"}\n");
fclose(fp);

filename[strlen(filename)-1]= 'h';
fp= fopen(filename,"w");
if(fp==NULL){
free(filename);
W_ERROR();
}
write_copyright(fp,author_name,project_name,year);
fprintf(fp,"#ifndef _%s_h_\n",argument2);
fprintf(fp,"#define _%s_h_\n#include \"weaver/weaver.h\"\n\n",argument2);
fprintf(fp,"#include \"includes.h\"\n\n");
fprintf(fp,"MAIN_LOOP %s(void);\n\n",argument2);
fprintf(fp,"#endif\n");
fclose(fp);
free(filename);

fp= fopen("src/includes.h","a");
fprintf(fp,"#include \"%s.h\"\n",argument2);
fclose(fp);
}
/*:49*/
#line 237 "weaver_program.tex"

END_OF_PROGRAM:
/*24:*/
#line 950 "weaver_program.tex"

if(project_path!=NULL)free(project_path);
/*:24*//*30:*/
#line 1091 "weaver_program.tex"

if(shared_dir!=NULL)free(shared_dir);
/*:30*//*37:*/
#line 1347 "weaver_program.tex"

if(author_name!=NULL)free(author_name);
/*:37*//*40:*/
#line 1409 "weaver_program.tex"

if(project_name!=NULL)free(project_name);
/*:40*/
#line 239 "weaver_program.tex"

return return_value;
}
/*:1*/
