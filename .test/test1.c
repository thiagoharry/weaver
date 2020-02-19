#include <string.h>
#include "game.h"

/*
  This test checks for loops and subloops relations.  It creates a
  depth 3 subloop, changing the deepest loop sometimes. So we can
  check if this runs successfully with W_MAX_SUBLOOP = 3 and if it
  really fails with W_MAX_SUBLOOP = 2
 */

static bool pass=false;

void loop1(void);
void loop2(void);
void loop3(void);
void loop4(void);
void loop5(void);

void loop1(void){
 LOOP_INIT:
 LOOP_BODY:
  if(strcmp(W.loop_name, "loop1"))
    exit(1);
  Wsubloop(loop2);
 LOOP_END:
  return;
}

void loop2(void){
 LOOP_INIT:
 LOOP_BODY:
  if(strcmp(W.loop_name, "loop2"))
    exit(1);
  Wsubloop(loop3);
 LOOP_END:
  return;
}

void loop3(void){
 LOOP_INIT:
 LOOP_BODY:
  if(strcmp(W.loop_name, "loop3"))
    exit(1);
  if(!pass)
    Wloop(loop4);
  else
    Wloop(loop5);
 LOOP_END:
  return;
}

void loop4(void){
 LOOP_INIT:
 LOOP_BODY:
  if(strcmp(W.loop_name, "loop4"))
    exit(1);
  pass = true;
  Wexit_loop();
 LOOP_END:
  return;
}

void loop5(void){
 LOOP_INIT:
 LOOP_BODY:
  if(strcmp(W.loop_name, "loop5"))
    exit(1);
  Wexit();
 LOOP_END:
  return;
}


int main(void){
  Winit();
  Wloop(loop1);
  Wexit();
}
