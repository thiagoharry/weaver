/* Contains Weaver configuration rules */

// BASIC CONFIGURATION

// The program name as a legible and human-friendly string:
//#define W_PROGRAM_NAME "Program Name"

// The ammount of details printed by weaver functions:
// 0: No warning is printed.
// 1: General warnings will be printed
// 2: General and memory manager warnings will be printed
// 3: General, memory and informational warnings will be printed
// If you aren't developing the game anymore and wish to distribute it,
// choose the level 0
#define W_DEBUG_LEVEL 2

// This macro determines if we are building a native program (W_ELF) or
// a web program to be run in a browser (W_WEB). In the first case,
// running "make" creates an executable with the project name. In the
// second, creates a "web" directory with a web application
#define W_TARGET W_ELF

// This macro determines if we are writting a C program (W_C) or a C++
// program (W_CPP):
#define W_SOURCE W_C

// The maximum ammount of memory for the game
#define W_MAX_MEMORY 100000000
// When compiling for the web, we usually need aditional memory. So we
// sum the memory above with the value below:
#define W_WEB_MEMORY 900000000

// If you wont use multiple threads, you can comment this:
//#define W_MULTITHREAD

// The window width. If equal 0, takes the maximum possible width
#define W_WIDTH  0

// The window height. If equal 0, takes the maximum possible width
#define W_HEIGHT 0

// The window default color
#define W_DEFAULT_COLOR 0.0, 0.0, 0.0

// The maximum number of Weaver classes that can be defined:
#define W_MAX_CLASSES   100

// Maximum number of instances for each Weaver Object:
#define W_MAX_INSTANCES 100

// How the objects are projected in the screen. The options are
// W_PERSPECTIVE and W_ORTHOGONAL
#define W_PROJECTION W_PERSPECTIVE
// Minimal distance captured by our camera. Shouldn't be 0 when using
// a perspective projection:
#define W_NEAR_PLANE      0.3
// Maximal distance captured by our camera:
#define W_FAR_PLANE    1000.0
// How big are the camera lens (usually an orthogonal projection needs
// bigger lens):
#define W_CAMERA_SIZE     0.3