#include <string.h>
#include "game.h"

/*
  This test checks if memory subsystem is workng.
*/

static bool pass=false;
static void *p;

void loop1(void);
void loop2(void);
void loop3(void);

void loop1(void){
 LOOP_INIT:
  p = W.alloc(W_MAX_MEMORY - 32);
  if(p == NULL){
    fprintf(stderr, "Alloc 1 failed.\n");
    exit(1);
  }
 LOOP_BODY:
  Wloop(loop2);
 LOOP_END:
  return;
}

void loop2(void){
 LOOP_INIT:
  p = W.alloc(W_MAX_MEMORY - 32);
  if(p == NULL){
    fprintf(stderr, "Alloc 2 failed.\n");
    exit(1);
  }
 LOOP_BODY:
  Wloop(loop3);
 LOOP_END:
  return;
}

void loop3(void){
 LOOP_INIT:
  printf("Loop 3\n");
  p = W.alloc(W_MAX_MEMORY - 32);
  if(p == NULL){
    fprintf(stderr, "Alloc 3 failed.\n");
    exit(1);
  }
 LOOP_BODY:
  Wexit();
 LOOP_END:
  return;
}


int main(void){
  Winit();
  Wloop(loop1);
  Wexit();
}
