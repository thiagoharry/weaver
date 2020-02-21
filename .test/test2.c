#include <string.h>
#include "game.h"

#include <pthread.h>

/*
  This test checks the game loop flow. It checks if the initialization
  really runs only once, the finalization runs only onbce and the loop
  body is executed many times.
*/

void loop1(void);
void *clear_pending_files(void *);

static int init = 0, end = 0, middle = 0;
static pthread_t thread;
static int rc;


void *clear_pending_files(void *p){
  sleep(1);
  W.pending_files = 0;
  pthread_exit(NULL);
  return p;
}

void loop1(void){
 LOOP_INIT:
  init ++;
  if(init > 1 || end > 0){
    printf("A");
    exit(1);
  }
  W.pending_files = 30;
  rc = pthread_create(&thread, NULL, clear_pending_files, NULL);
  if(rc){
    printf("B");
    exit(1);
  }
 LOOP_BODY:
  if(init > 1 || end > 0){
    printf("C");
    exit(1);
  }
  middle ++;
  if(middle == 5)
    Wexit_loop();
 LOOP_END:
  end ++;
  if(W.pending_files > 0){
    printf("D");
    exit(1);
  }
  if(end > 1){
    printf("E(%d)", end);
    exit(1);
  }
  return;
}


int main(void){
  Winit();
  Wloop(loop1);
  Wexit();
}
