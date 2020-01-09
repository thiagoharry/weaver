/*3:*/
#line 179 "./weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*4:*/
#line 193 "./weaver_api.tex"

struct _weaver_struct W;
/*:4*/
#line 182 "./weaver_api.tex"


/*6:*/
#line 214 "./weaver_api.tex"

void Winit(void){
W.game= &_game;
/*12:*/
#line 295 "./weaver_api.tex"

W.pending_files= 0;
/*:12*/
#line 217 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 233 "./weaver_api.tex"

void Wexit(void){

exit(0);
}
/*:8*/
#line 184 "./weaver_api.tex"

/*:3*/
