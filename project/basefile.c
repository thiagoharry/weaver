#include "game.h"

void main_loop(void){ // The game loop
 BEGIN_LOOP_INITIALIZATION:
  // Put here initialization code to be executed just in the first iteration 
 END_LOOP_INITIALIZATION:
  if(W.keyboard[W_ANY])
    Wexit(); // If the user presses any key, quit (you should change this)

  // (...) Put the loop logic here

  Wrest(10); // Spends 14 milisseconds idle (70fps)
}

int main(void){
  Winit(); // Initializes Weaver
  Wloop(main_loop); // Enter a new game loop
  Wexit(); // Quit the program
  return 0;
}
