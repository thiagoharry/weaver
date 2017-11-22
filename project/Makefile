SHELL := /bin/bash
PROG=$(shell cat .weaver/name)
CORES=$(shell grep -c ^processor /proc/cpuinfo)

TARGET_TEST=$(shell grep "\#define[ \t]\+W_TARGET[ \t]\+W_" conf/conf.h | grep -o "\(W_WEB\|W_ELF\)")
INSTALL_DATA_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_DATA[ \t]\+" conf/conf.h | grep -o "\".*\"")
INSTALL_PROG_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_PROG[ \t]\+" conf/conf.h | grep -o "\".*\"")
DEBUG_LEVEL=$(shell grep "\#define[ \t]\+W_DEBUG_LEVEL[ \t]\+" conf/conf.h | grep -o "[0-9]\+")

ifeq ($(INSTALL_DATA_DIR),)
INSTALL_DATA_DIR := "/usr/share/games/"$(PROG)
endif
ifeq ($(INSTALL_PROG_DIR),)
INSTALL_PROG_DIR := "/usr/games/"
endif

ifeq ($(strip $(TARGET_TEST)),W_WEB)
web: test_emcc test_xxd shader_data make-web
else ifeq ($(strip $(TARGET_TEST)),W_ELF)
prog: test_cc test_xlib test_xrandr test_opengl test_openal test_xxd shader_data make-prog
else
err:
	$(error Invalid W_TARGET in conf/conf.h)
endif
make-prog:
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f prog.Makefile; fi
make-web:
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f web.Makefile; fi
shader_data: src/weaver/vertex_interface.data\
		src/weaver/fragment_interface.data\
		src/weaver/fragment_interface_texture.data\
		src/weaver/vertex_interface_texture.data\
                src/weaver/vertex_image_interface.data\
                src/weaver/fragment_image_interface.data
src/weaver/vertex_interface.data: src/weaver/vertex_interface.glsl
	@cat src/weaver/vertex_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/vertex_interface.data
src/weaver/fragment_interface.data: src/weaver/fragment_interface.glsl
	@cat src/weaver/fragment_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/fragment_interface.data
src/weaver/vertex_image_interface.data: src/weaver/vertex_image_interface.glsl
	@cat src/weaver/vertex_image_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/vertex_image_interface.data
src/weaver/fragment_image_interface.data: src/weaver/fragment_image_interface.glsl
	@cat src/weaver/fragment_image_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/fragment_image_interface.data
src/weaver/fragment_interface_texture.data: src/weaver/fragment_interface_texture.glsl
	@cat src/weaver/fragment_interface_texture.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/fragment_interface_texture.data
src/weaver/vertex_interface_texture.data: src/weaver/vertex_interface_texture.glsl
	@cat src/weaver/vertex_interface_texture.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/vertex_interface_texture.data
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
	@(gcc .weaver/dummy.c -o .weaver/a.out -lX11 &> /dev/null && \
	touch .weaver/have_xlib) || \
	(clang .weaver/dummy.c -o .weaver/a.out -lX11 &> /dev/null && \
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
	@(gcc .weaver/dummy.c -o .weaver/a.out -lX11 -lGL -lGLEW &> /dev/null && \
	touch .weaver/have_opengl) || \
	(clang .weaver/dummy.c -o .weaver/a.out -lX11 -lGL -lGLEW &> /dev/null && \
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
	@(gcc .weaver/dummy.c -o .weaver/a.out -lX11 -lXrandr &> /dev/null && \
	touch .weaver/have_xrandr) || \
	(clang .weaver/dummy.c -o .weaver/a.out -lX11 -lXrandr &> /dev/null && \
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
	@(gcc .weaver/dummy.c -o .weaver/a.out -lopenal &> /dev/null && \
	touch .weaver/have_openal) || \
	(clang .weaver/dummy.c -o .weaver/a.out -lopenal &> /dev/null && \
	touch .weaver/have_openal) ||true
	@if [ -e .weaver/have_openal ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install OpenAL library and headers to run this command.";\
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
	install -d ${INSTALL_DATA_DIR}/
	cp -r shaders/ ${INSTALL_DATA_DIR}/
	cp -r sound/ ${INSTALL_DATA_DIR}/
	cp -r image/ ${INSTALL_DATA_DIR}/
	install -d ${INSTALL_PROG_DIR}
	install -m755 -c ${PROG} ${INSTALL_PROG_DIR}
else
install: clean
	$(error Please, change W_DEBUG_LEVEL definition to 0 in conf/conf.h and recompile before installing the program.)
endif
