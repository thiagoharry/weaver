# weaver
A Game Engine written in C which can be used to develop games in C or C++ and compiled to Linux executables or Javascript web pages

Weaver is a literate programming project written in brazilian portuguese which describes the building of a 3D game engine using the C language.

To build and install the engine you can type 'make' and 'make install'.

To build the PDF which explains all the source code, you can type 'make doc' and a 'weaver.pdf' will be created.

To build the engine or the PDF you must have Knuth's CWEB. For the PDF you should edit Knuth's CWEB to make its internal buffer bigger, or it won't be able to process all the source code files. The program 'noweb' also should work.

To use the engine to compile Javascript web games from C, you should have Emscripten installed and configured.
