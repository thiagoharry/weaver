/*3:*/
#line 178 "./weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*4:*/
#line 192 "./weaver_api.tex"

struct _weaver_struct W;
/*:4*/
#line 181 "./weaver_api.tex"


/*6:*/
#line 213 "./weaver_api.tex"

void Winit(void){
W.game= &_game;
/*12:*/
#line 294 "./weaver_api.tex"

W.pending_files= 0;
/*:12*/
#line 216 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 232 "./weaver_api.tex"

void Wexit(void){

exit(0);
}
/*:8*/
#line 183 "./weaver_api.tex"

/*:3*/
