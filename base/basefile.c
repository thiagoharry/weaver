#include "game.h"

MAIN_LOOP(main_loop){ // The game loop
 LOOP_INIT: // Code executed during loop initialization

 LOOP_BODY: // Code executed every loop iteration
    if(W.keyboard[W_ANY])
        Wexit_loop();
 LOOP_END: // Code executed at the end of the loop
    return;
}

int main(void){
  Winit(); // Initializes Weaver
  Wloop(main_loop); // Enter a new game loop
  return 0;
}