Here you can check the list of all functions defined in Weaver API and
what they do.

## Basic Functions and Variables

### Basic Variables

* `unsigned long W.t`

This variable represents the time in microsseconds since the beginning
of the program. One microssecond is 0.000001 seconds. So each second
increments the value in 1,000,000.

* `unsigned long W.dt`

This variable represents the elapsed time in microsseconds since the
current iteration in the main loop and the last iteration. As the main
loop runs code in deterministic intervals, this value shouldn't change
much. If it's value becames too hight, perhaps the game is running in
a too slow machine.


### basic Functions

* `void Winit(void)`

This function initializes the Weaver API. It should be the first thing
called in your program. If you call other functions before calling
`Winit` (note that this function doesn't have the point "." in the
name), the result is undefined and probably wrong.

* `void Wexit(void)`

This function finalizes Weaver API, closes the window and clean
everything. You should call this function to exit your game.


