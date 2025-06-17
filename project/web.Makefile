SHELL := /usr/bin/env bash
EMCC=emcc
PROG=$(shell cat .weaver/name)
BC=$(shell for i in src/*.c; do echo $$(basename $${i%%.c}).o; done)
W_BC=$(shell for i in src/weaver/*.c; do echo .weaver/$$(basename $${i%%.c}).o; done)
HEADERS=$(shell echo src/*.h)
PLUGINS=$(shell [ "$(ls -A plugins/)" ] && echo plugins/*.c)
LIB= -lm
DEFINES=-DW_PROG=\"${PROG}\"
PLUGINS_NUM=$(shell ls -1 plugins | wc -l)
FLAGS=-DWEAVER_ENGINE -Wall -O2 -D_W_NUMBER_OF_PLUGINS=${PLUGINS_NUM}
NUMBER_OF_SHADERS=$(shell ls -1 shaders/ | wc -l)

SOURCE_TEST=$(shell grep "^\#define[ \t]\+W_SOURCE[ \t]\+W_" conf/conf.h | grep -o "\(W_C\|W_CPP\)")
FINAL_CC=${EMCC}

make-web: ${BC} ${W_BC} ${HEADERS} ${PLUGINS} conf/conf.h
	mkdir -p docs
	cp -r sound/ docs
	cp -r music/ docs
	cp -r image/ docs
	${FINAL_CC} -O2 -include conf/conf.h ${DEFINES} ${BC} ${PLUGIN_BC} ${W_BC} ${FINAL_FLAGS} ${SHADER_PRELOAD} -o docs/index.html ${LIB}
create_shader_code:
	mkdir -p .hidden_code .plugin
	echo "struct _shader _shader_list[${NUMBER_OF_SHADERS}];" > .hidden_code/shader.h
	echo "{" > .hidden_code/initialize_shader.c
	if [ "$$(ls -A shaders/)" ]; then \
          echo "int number;" >> .hidden_code/initialize_shader.c; \
	  for i in shaders/*; do \
	    shader_name=$$(basename $${i}); \
	    echo "number = atoi(\"$${shader_name}\");" >> .hidden_code/initialize_shader.c; \
	    echo "if(number <= ${NUMBER_OF_SHADERS}){" >> .hidden_code/initialize_shader.c; \
	    echo "_compile_and_insert_new_shader(\"$${i}\", number - 1);" >> .hidden_code/initialize_shader.c; \
	    echo "}" >> .hidden_code/initialize_shader.c; \
	  done; \
	fi; \
	echo "}" >> .hidden_code/initialize_shader.c
%.o: src/%.c ${HEADERS}
	${EMCC} -include conf/conf.h ${DEFINES} ${FLAGS} -c $< -o $$(basename $< .c).o
.weaver/%.o: src/weaver/%.c ${HEADERS}
	${EMCC} -include conf/conf.h ${DEFINES} ${FLAGS} -c $< -o $(subst src/weaver/,.weaver/,$(subst .c,.o,$<))
