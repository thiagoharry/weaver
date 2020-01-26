/*3:*/
#line 186 "./weaver_api.tex"

#include "weaver.h"
#include "../game.h"
/*4:*/
#line 200 "./weaver_api.tex"

struct _weaver_struct W;
/*:4*/
#line 189 "./weaver_api.tex"


/*6:*/
#line 223 "./weaver_api.tex"

void Winit(void){
W.game= &_game;
/*11:*/
#line 428 "./weaver_api.tex"

_running_loop= false;
_loop_begin= false;
/*:11*//*13:*/
#line 456 "./weaver_api.tex"

W.pending_files= 0;
W.loop_name= NULL;
/*:13*//*16:*/
#line 498 "./weaver_api.tex"

W.pending_files= 0;
/*:16*/
#line 226 "./weaver_api.tex"

}
/*:6*//*8:*/
#line 242 "./weaver_api.tex"

void Wexit(void){

exit(0);
}
/*:8*/
#line 191 "./weaver_api.tex"

/*:3*/
