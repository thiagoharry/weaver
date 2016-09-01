SHELL := /bin/bash
PROG=$(shell cat .weaver/name)
CORES=$(shell grep -c ^processor /proc/cpuinfo)

TARGET_TEST=$(shell grep "\#define[ \t]\+W_TARGET[ \t]\+W_" conf/conf.h | grep -o "\(W_WEB\|W_ELF\)")

ifeq ($(strip $(TARGET_TEST)),W_WEB)
web: test_emcc make-web
else ifeq ($(strip $(TARGET_TEST)),W_ELF)
prog: test_cc make-prog
else
err:
	$(error Invalid W_TARGET in conf/conf.h)
endif
make-prog: shader_data
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f Makefile.prog; fi
make-web: shader_data
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f Makefile.web; fi
clean:
	rm -f *.o *.bc *~ .weaver/*.o .weaver/*.bc src/weaver/*.data
	rm -f compiled_plugins/* .plugin/*
distclean: clean
	rm -f ${PROG}
	rm -rf web
	rm -f .weaver/have_*
shader_data: src/weaver/vertex.data src/weaver/fragment.data
src/weaver/vertex.data: src/weaver/vertex.glsl
	cat src/weaver/vertex.glsl | sed 's/^#line.*//' | xxd -i  > src/weaver/vertex.data
src/weaver/fragment.data: src/weaver/fragment.glsl
	cat src/weaver/fragment.glsl | sed 's/^#line.*//' | xxd -i  > src/weaver/fragment.data
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
