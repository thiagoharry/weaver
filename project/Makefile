SHELL := /usr/bin/env bash
MAKE=$(shell if which gmake > /dev/null; then echo gmake; else echo make; fi)
PROG=$(shell cat .weaver/name)
CORES=$(shell grep -c ^processor /proc/cpuinfo 2> /dev/null)

TARGET_TEST=$(shell egrep "\#define[ \t]+W_TARGET[ \t]+W_" conf/conf.h | egrep -o "(W_WEB|W_ELF)")
INSTALL_DATA_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_DATA[ \t]\+" conf/conf.h | grep -o "\".*\"")
INSTALL_PROG_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_PROG[ \t]\+" conf/conf.h | grep -o "\".*\"")
DEBUG_LEVEL=$(shell egrep "^\#define[\t ]+W_DEBUG_LEVEL[\t ]+" conf/conf.h | egrep -o "[0-9]+")
DONT_USE_PNG=$(shell grep "^\#define[ \t]\+W_DISABLE_PNG" conf/conf.h)
DONT_USE_MP3=$(shell grep "^\#define[ \t]\+W_DISABLE_MP3" conf/conf.h)

ifeq ($(CORES),)
CORES := $(shell sysctl hw.ncpu | grep -E -o "[0-9]+")
endif

ifeq ($(INSTALL_DATA_DIR),)
INSTALL_DATA_DIR := "/usr/share/games/"$(PROG)
endif
ifeq ($(INSTALL_PROG_DIR),)
INSTALL_PROG_DIR := "/usr/games/"
endif

ifeq ($(DONT_USE_MP3),)
TEST_MP3=test_mp3
else
TEST_MP3=
endif
ifeq ($(DONT_USE_PNG),)
TEST_PNG=test_png
else
TEST_PNG=
endif

prog: test_cc shader_data make-prog
web: test_emcc shader_data make-web
make-prog:
	@if [ -e .error ]; then	rm .error; \
	else ${MAKE} --no-print-directory -j ${CORES} -f prog.Makefile; fi
make-web:
	@if [ -e .error ]; then	rm .error; \
	else ${MAKE} --no-print-directory -j ${CORES} -f web.Makefile; fi
shader_data:
clean:
	rm -f *.o *.bc *~ .weaver/*.o .weaver/*.bc src/weaver/*.data
	rm -f compiled_plugins/* .plugin/*
distclean: clean
	rm -f ${PROG}
	rm -rf web
	rm -f .weaver/have_*
test_xxd: .weaver/have_xxd
test_openal: .weaver/have_openal
test_opengl: .weaver/have_opengl
test_xrandr: .weaver/have_xrandr
test_xlib: .weaver/have_xlib
test_png: .weaver/have_png
test_mp3: .weaver/have_mp3
test_cc: .weaver/have_cc
.weaver/have_xxd:
	@echo -n "Testing XXD.................."
	@(which xxd &> /dev/null && touch .weaver/have_xxd) || true
	@if [ -e .weaver/have_xxd ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install xxd program to run this command.";\
	fi
.weaver/have_cc:
	@echo -n "Testing GCC or CLANG........."
	@(which gcc &> /dev/null && touch .weaver/have_cc) || \
	(which clang &> /dev/null && touch .weaver/have_cc) ||true
	@if [ -e .weaver/have_cc ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install gcc or clang to run this command.";\
	fi
.weaver/have_xlib:
	@echo -n "Testing Xlib................."
	@echo "#include <X11/Xlib.h>" > .weaver/dummy.c
	@echo "#include <X11/XKBlib.h>" >> .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${XLIB} &> /dev/null && \
	touch .weaver/have_xlib) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${XLIB} -lX11 &> /dev/null && \
	touch .weaver/have_xlib) ||true
	@if [ -e .weaver/have_xlib ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install Xlib headers to run this command.";\
	fi
.weaver/have_opengl:
	@echo -n "Testing OpenGL..............."
	@echo "#include <X11/Xlib.h>" > .weaver/dummy.c
	@echo "#include <GL/glew.h>" >> .weaver/dummy.c
	@echo "#include <GL/gl.h>" >> .weaver/dummy.c
	@echo "#include <GL/glx.h>" >> .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${XLIB} ${GL} &> /dev/null && \
	touch .weaver/have_opengl) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${XLIB} ${GL} &> /dev/null && \
	touch .weaver/have_opengl) ||true
	@if [ -e .weaver/have_opengl ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: You need GLX extension and GLEW library and header files.";\
	fi
.weaver/have_xrandr:
	@echo -n "Testing XRandR..............."
	@echo "#include <X11/Xlib.h>" > .weaver/dummy.c
	@echo "#include <X11/extensions/Xrandr.h>" >> .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${XLIB} -lXrandr &> /dev/null && \
	touch .weaver/have_xrandr) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${XLIB} -lXrandr &> /dev/null && \
	touch .weaver/have_xrandr) ||true
	@if [ -e .weaver/have_xrandr ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install XRandR library and headers to run this command.";\
	fi
.weaver/have_openal:
	@echo -n "Testing OpenAL..............."
	@echo "#include <AL/al.h>" > .weaver/dummy.c
	@echo "#include <AL/alc.h>" >> .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${AL} &> /dev/null && \
	touch .weaver/have_openal) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${AL} &> /dev/null && \
	touch .weaver/have_openal) ||true
	@if [ -e .weaver/have_openal ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install OpenAL library and headers to run this command.";\
	fi
.weaver/have_png:
	@echo -n "Testing PNG.................."
	@echo "#include <png.h>" > .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${PNG} &> /dev/null && \
	touch .weaver/have_png) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${PNG} &> /dev/null && \
	touch .weaver/have_png) ||true
	@if [ -e .weaver/have_png ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install PNG library and headers to run this command.";\
	echo "       Or disable PNG support adding W_DISABLE_PNG in conf/conf.h.";\
	fi
.weaver/have_mp3:
	@echo -n "Testing MPG123..............."
	@echo "#include <mpg123.h>" > .weaver/dummy.c
	@echo "int main(void){ return 1; }" >> .weaver/dummy.c
	@(gcc .weaver/dummy.c -o .weaver/a.out ${MPG123} &> /dev/null && \
	touch .weaver/have_mp3) || \
	(clang .weaver/dummy.c -o .weaver/a.out ${MPG123} &> /dev/null && \
	touch .weaver/have_mp3) ||true
	@if [ -e .weaver/have_mp3 ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install MPG123 library and headers to run this command.";\
	echo "       Or disable MP3 support adding W_DISABLE_MP3 in conf/conf.h.";\
	fi
test_emcc: .weaver/have_emcc
.weaver/have_emcc:
	@echo -n "Testing EMCC................."
	@(which emcc &> /dev/null && touch .weaver/have_emcc) ||true
	@if [ -e .weaver/have_emcc ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install Emscripten to run this command.";\
	fi
ifeq ($(strip $(DEBUG_LEVEL)),0)
install:
	install -m755 -d ${INSTALL_DATA_DIR}/
	cp -r shaders/ ${INSTALL_DATA_DIR}/
	cp -r sound/ ${INSTALL_DATA_DIR}/
	cp -r image/ ${INSTALL_DATA_DIR}/
	cp -r music/ ${INSTALL_DATA_DIR}/
	cp -r fonts/ ${INSTALL_DATA_DIR}/
	chmod 755 ${INSTALL_DATA_DIR}/*
	chmod 755 ${INSTALL_DATA_DIR}/shaders/*
	install -d ${INSTALL_PROG_DIR}
	install -m755 -c ${PROG} ${INSTALL_PROG_DIR}
else
install: clean
	$(error Please, change W_DEBUG_LEVEL definition to 0 in conf/conf.h and recompile before installing the program.)
endif
