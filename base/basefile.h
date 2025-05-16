#ifndef _game_h_
#define _game_h_

#include "weaver/weaver.h"
#include "includes.h"

__attribute__((weak)) struct _game_struct{
  // You can personalize this struct putting your variables here. But
  // don't change it's name. Access it in W.game variable.
  int whatever;
} _game;

void main_loop(void);

#endif
