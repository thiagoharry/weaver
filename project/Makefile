SHELL := /bin/bash
PROG=$(shell cat .weaver/name)
CORES=$(shell grep -c ^processor /proc/cpuinfo)

TARGET_TEST=$(shell grep "\#define[ \t]\+W_TARGET[ \t]\+W_" conf/conf.h | grep -o "\(W_WEB\|W_ELF\)")
INSTALL_DATA_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_DATA[ \t]\+" conf/conf.h | grep -o "\".*\"")
INSTALL_PROG_DIR=$(shell grep "\#define[ \t]\+W_INSTALL_PROG[ \t]\+" conf/conf.h | grep -o "\".*\"")
DEBUG_LEVEL=$(shell grep "\#define[ \t]\+W_DEBUG_LEVEL[ \t]\+" conf/conf.h | grep -o "[0-9]\+")

ifeq ($(strip $(TARGET_TEST)),W_WEB)
web: test_emcc shader_data make-web
else ifeq ($(strip $(TARGET_TEST)),W_ELF)
prog: test_cc shader_data make-prog
else
err:
	$(error Invalid W_TARGET in conf/conf.h)
endif
make-prog:
	echo ${DEBUG_LEVEL}
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f prog.Makefile; fi
make-web:
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f web.Makefile; fi
shader_data: src/weaver/vertex_interface.data\
		src/weaver/fragment_interface.data\
		src/weaver/fragment_interface_texture.data\
		src/weaver/vertex_interface_texture.data
src/weaver/vertex_interface.data: src/weaver/vertex_interface.glsl
	cat src/weaver/vertex_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/vertex_interface.data
src/weaver/fragment_interface.data: src/weaver/fragment_interface.glsl
	cat src/weaver/fragment_interface.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/fragment_interface.data
src/weaver/fragment_interface_texture.data: src/weaver/fragment_interface_texture.glsl
	cat src/weaver/fragment_interface_texture.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/fragment_interface_texture.data
src/weaver/vertex_interface_texture.data: src/weaver/vertex_interface_texture.glsl
	cat src/weaver/vertex_interface_texture.glsl | sed 's/^#line.*//' | \
	xxd -i > src/weaver/vertex_interface_texture.data
clean:
	rm -f *.o *.bc *~ .weaver/*.o .weaver/*.bc src/weaver/*.data
	rm -f compiled_plugins/* .plugin/*
distclean: clean
	rm -f ${PROG}
	rm -rf web
	rm -f .weaver/have_*
test_cc: .weaver/have_cc
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
	install -d ${INSTALL_DATA_DIR}/${PROG}
	cp -r shaders/ ${INSTALL_DATA_DIR}/${PROG}/
	cp -r sound/ ${INSTALL_DATA_DIR}/${PROG}/
	install -m755 -c ${PROG} ${INSTALL_PROG_DIR}
else
install:
	$(error Please, change W_DEBUG_LEVEL definition to 0 in conf/conf.h before installing the program.)
endif
