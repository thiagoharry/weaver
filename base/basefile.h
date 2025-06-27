#ifndef _game_h_
#define _game_h_

#include "weaver/weaver.h"
#include "includes.h"

struct _game_struct{
  // You can personalize this struct putting your variables here. But
  // don't change it's name. Access it in W.game variable.
  int whatever; // <- This variable is here to prevent compiler errors
};

extern struct _game_struct _game;

void main_loop(void);

#endif
