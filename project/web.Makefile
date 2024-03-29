SHELL := /usr/bin/env bash
EMCC=emcc
PROG=$(shell cat .weaver/name)
BC=$(shell for i in src/*.c; do echo $$(basename $${i%%.c}).bc; done)
W_BC=$(shell for i in src/weaver/*.c; do echo .weaver/$$(basename $${i%%.c}).bc; done)
HEADERS=$(shell echo src/*.h)
PLUGINS=$(shell [ "$(ls -A plugins/)" ] && echo plugins/*.c)
LIB= -lm
DEFINES=-DW_PROG=\"${PROG}\"
PLUGINS_NUM=$(shell ls -1 plugins | wc -l)
FLAGS=-Wall -O2 -D_W_NUMBER_OF_PLUGINS=${PLUGINS_NUM}
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
create_plugin_code:
	mkdir -p .hidden_code .plugin
	echo "" > .hidden_code/initialize_plugin.c
	echo "" > .hidden_code/header.h
	count=0; \
	if [ "$$(ls -A plugins/)" ]; then for i in plugins/*.c ; do \
        if [[ -z "$${i// }" ]]; then continue; fi; \
        filename=$$(basename $$i); \
        name=$${filename%??}; \
        if [ "$${name}" == "*" ]; then continue; fi; \
	echo "strcpy(_plugins[$${count}].plugin_name, \"$${name}\");" > .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}]._init_plugin = _init_plugin_$${name};" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}]._fini_plugin = _fini_plugin_$${name};" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}]._run_plugin = _run_plugin_$${name};" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}]._enable_plugin = _enable_plugin_$${name};" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}]._disable_plugin = _disable_plugin_$${name};" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}].plugin_data = NULL;" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}].enabled = false;" >> .hidden_code/initialize_plugin.c; \
	echo "_plugins[$${count}].defined = true;" >> .hidden_code/initialize_plugin.c; \
	echo "void _init_plugin_$${name}(struct _weaver_struct *);" > .hidden_code/header.h; \
	echo "void _fini_plugin_$${name}(struct _weaver_struct *);" >> .hidden_code/header.h; \
	echo "void _run_plugin_$${name}(struct _weaver_struct *);" >> .hidden_code/header.h; \
	echo "void _enable_plugin_$${name}(struct _weaver_struct *);" >> .hidden_code/header.h; \
	echo "void _disable_plugin_$${name}(struct _weaver_struct *);" >> .hidden_code/header.h; \
	${EMCC} ${DEFINES} ${FLAGS} -c plugins/$${filename} -o .plugin/$${name}.bc; \
        count=$$(($${count}+1)); \
        done; fi
%.bc: src/%.c ${HEADERS}
	${EMCC} -include conf/conf.h ${DEFINES} ${FLAGS} -c $< -o $$(basename $< .c).bc
.weaver/%.bc: src/weaver/%.c ${HEADERS}
	${EMCC} -include conf/conf.h ${DEFINES} ${FLAGS} -c $< -o $(subst src/weaver/,.weaver/,$(subst .c,.bc,$<))
