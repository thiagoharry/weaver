// This test shader and user interface support

#include "game.h"

static struct user_interface *a, *b;

void main_loop(void){ // The game loop
 LOOP_INIT: // Code executed during loop initialization
  a = W.new_interface(NULL, NULL,
		      W.width / 4, W.height / 4, 1.0,
		      W.width / 2, W.height / 2);
  b = W.new_interface("shader.glsl", NULL,
		      3 * W.width / 4, 3 * W.height / 4, 1.0,
		      W.width / 2, W.height / 2);
  if(a == NULL || b == NULL)
    exit(1);
 LOOP_BODY: // Code executed every loop iteration
  if(W.keyboard[W_ANY])
    Wexit_loop();
  if(W.t > 2000000)
    Wexit_loop();
 LOOP_END: // Code executed at the end of the loop
    return;
}

int main(void){
  Winit(); // Initializes Weaver
  Wloop(main_loop); // Enter a new game loop
  return 0;
}
