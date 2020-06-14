# weaver-memory-manager

A portable memory manager for game engines written in literary programming style

Read the code [here (in portuguese)](https://github.com/thiagoharry/weaver-memory-manager/blob/master/weaver-memory-manager.pdf)

This memory manager is self contained in the files present in src/ folder. To use it, just put these files in your project.

This is a stack-based memory manager. It doesn't have a 'free'
function. Instead, you ask for memory with 'Walloc', and you can ask
for the creations of 'memory points'. When you call 'Wtrash' all the
memory allocated with 'Walloc' called after the last memory point will
be freed (and this also erases the memory point).

In fact, we have two stacks where memory is allocated and each one has
its own independent memory points. So when you call for memory, free
memory or create memory points, you should inform if you want to use
the left or right stack.

As this memory manager also wants to give more control to its users,
you can choose the byte alignment when calling Walloc.

# Functions

The code here defines the following functions:

* void *Wcreate_arena(size_t SIZE)

Ask some ammount of memory to the Operating System. Our memory manager
will manage it. Returns NULL in case of error. Otherwise returns a
continuous memory array bigger or equal than SIZE bytes (our arena).

* bool Wdestroy_arena(void *arena)

Free a memory arena allocated with Wcreate_arena. Return true if there
were no memory leaks in our arena (no 'Wallocs' which were not freed
with a 'Wtrash').

* void *Walloc(void *arena, unsigned a, int right, size_t t)

Allocates a new memory from a given arena. The parameter 'a' is the
byte alignment and should be a power of two. The parameter 'right'
should be 1 or 0 and determines if we take memory from the left or
right stack in the arena. And 't' is the amount of allocated
memory. Returns NULL in case of no enough memory, or a pointer to the
allocated memory otherwise.

* bool Wmempoint(void *arena, unsigned a, int right)

Creates a memory point in a given arena, storing the data with byte
alignment 'a' (a power of 2) and in the left stack (if right=0) or in
the right (if right=1).

* void Wtrash(void *arena, int right)

Frees all the memory allocated in the left stack (right=0) or in the
right stack (right=1) after the last 'Wmempoint' invocation in the
given stack. This also erases the last memory point created by
'Wmempoint'. If there was no previous memory point, it frees all the
memory allocated in the stack.