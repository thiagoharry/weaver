# weaver

A Game Engine written in C which can be used to develop games in C or
C++ and compiled to Linux executables or Javascript web pages.

This project is under heavy refactoring, so it can't be
installed. This will be corrected soon.

## Literary programming code

You can read the PDFs documenting all the Weaver code here:

* **Weaver Program**: [[In
    English]](https://github.com/thiagoharry/weaver/blob/master/weaver_program_en.pdf)[[In
    Portuguese]](https://github.com/thiagoharry/weaver/blob/master/weaver_program.pdf)
    The program used to create and manage new Weaver game projects.

* **Weaver API**: [[In
    English]](https://github.com/thiagoharry/weaver/blob/master/weaver_api_en.pdf)[[In
    Portuguese]](https://github.com/thiagoharry/weaver/blob/master/weaver_api.pdf)How
    the code is organized and the API functions are defined and work
    together.


The Weaver API uses several subsystems in its code. You can read about
each subsystem separately:

* **Memory Manager**: [[In English]](https://github.com/thiagoharry/weaver-memory-manager/blob/master/weaver-memory-manager_en.pdf)[[In Portuguese]](https://github.com/thiagoharry/weaver-memory-manager/blob/master/weaver-memory-manager.pdf)--[[GitHub Page]](https://github.com/thiagoharry/weaver-memory-manager)

* **Random Number Generator**: [[In English]](https://github.com/thiagoharry/weaver-random/raw/master/weaver-random_en.pdf)[[In Portuguese]](https://github.com/thiagoharry/weaver-random/raw/master/weaver-random.pdf)--[[GitHub Page]](https://github.com/thiagoharry/weaver-random)

* **Window**: [[In English]](https://github.com/thiagoharry/weaver-window/raw/master/weaver-window_en.pdf)[[In Portuguese]](https://github.com/thiagoharry/weaver-window/raw/master/weaver-window.pdf)--[[GitHub Page]](https://github.com/thiagoharry/weaver-window)


## Building

To build and install the engine you can type `make` and `make
install`. You must have CWEB or noweb to extract and compile the
source code. The source code is always extracted from the portuguese
literate program, not the english version.

To build the portuguese PDF, Weaver uses
[magitex](https://github.com/thiagoharry/magitex), a custom TeX format
tuned to support portuguese characters and hyphenation and able to
substitute the more traditional `ctangle` program in literary
programming. If you installed `magitex`, you can type `make doc` to
build the PDF.

To build the english PDF, just type `make doc_en`. As Plain TeX deal
correctly with english hyphenation, we just import a file with macro
definition used in `magitex` and use Plain Tex to build the PDF.

## Helping

Pull requests to correct typos and grammar errors are welcome.

If you want to contribute with code, this should be done in the TeX
files. Nontrivial modifications usually require updates in the text to
explain what the new code does. You can update just the TeX file in
english or just the file in portuguese. After this I will update the
other file to keep the versions in the two languages the same.