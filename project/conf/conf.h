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

// To where the game data should be installed
#define W_INSTALL_DATA "/usr/share/games/"W_PROG
// Where the game binary should be installed?
#define W_INSTALL_PROG "/usr/games/"

// Where should we look for plugins? Directories separated by ':'
#define W_PLUGIN_PATH W_INSTALL_DATA"/plugins:compiled_plugins"

// The maximum ammount of memory for the game
#define W_MAX_MEMORY 100000000
#define W_INTERNAL_MEMORY 16384
// When compiling for the web, we usually need aditional memory. So we
// sum the memory above with the value below:
#define W_WEB_MEMORY 900000000

// If you wont use multiple threads, you can comment this:
//#define W_MULTITHREAD

// If W_MULTITHREAD is defined above, this sets the size of the pool
// of threads used to read and parse files. If the value is zero or
// less, we don't use a pool of threads, but create a new thread each
// time we read and parse a file with audio, font or texture
#define W_THREAD_POOL 0

// The window width. If equal 0, takes the maximum possible width
#define W_WIDTH  0

// The window height. If equal 0, takes the maximum possible height
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

/* Various Limits */
#define W_LIMIT_SUBLOOP 16 // Max number of subloops
#define W_MAX_PERIODIC_FUNCTIONS 16 // Max periodic functions in a loop
#define W_MAX_INTERFACES         16 // Max number of interface elements
