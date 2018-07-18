SHELL := /bin/bash
INSTALL_BIN_DIR=/usr/bin/
INSTALL_SHARE_DIR=/usr/share/weaver
PROJECT_SHARE=${INSTALL_SHARE_DIR}/project
W_FILES=cweb/00-preambulo.w cweb/01-intro.w cweb/02-memoria.w cweb/03-numeros.w\
	cweb/04-gerais.w\
        cweb/05-janela.w cweb/06-entrada.w cweb/07-plugins.w\
	cweb/08-shaders.w cweb/09-resolucao.w cweb/10-som.w cweb/11-gifs.w \
	cweb/12-imagens.w cweb/13-arquivos.w cweb/14-musica.w \
	cweb/15-metafont.w cweb/99-fim.w
CORES=$(shell grep -c ^processor /proc/cpuinfo)

main: program
all: doc program
preprocess: ${W_FILES}
	@rm -f cweb/*~
	@rm -f cweb/weaver.w
	@cat ${W_FILES} > cweb/weaver.w
doc: test_cweave test_dot test_latex make-doc
make-doc: preprocess diagram
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f Makefile.doc; fi
diagram: cweb/diagrams/project_dir.dot cweb/diagrams/estados.dot cweb/diagrams/estados2.dot
	@dot -Teps cweb/diagrams/project_dir.dot -o cweb/diagrams/project_dir.eps
	@dot -Teps cweb/diagrams/estados.dot -o cweb/diagrams/estados.eps
	@dot -Teps cweb/diagrams/estados2.dot -o cweb/diagrams/estados2.eps
program: test_tangle test_cc preprocess make-program
make-program: preprocess
	@if [ -e .error ]; then	rm .error; \
	else make --no-print-directory -j ${CORES} -f Makefile.prog; fi
test_cweave: .build/have_cweave
.build/have_cweave:
	@echo -n "Testing CWEAVE..............."
	@(which cweave &> /dev/null && touch .build/have_cweave) || true
	@if [ -e .build/have_cweave ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install cweb to run this command.";\
	fi
test_dot: .build/have_dot
.build/have_dot:
	@echo -n "Testing DOT.................."
	@(which dot &> /dev/null && touch .build/have_dot) || true
	@if [ -e .build/have_dot ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install graphviz to run this command.";\
	fi
test_latex: .build/have_latex
.build/have_latex:
	@echo -n "Testing LaTeX................"
	@(which latex &> /dev/null && touch .build/have_latex) || true
	@if [ -e .build/have_latex ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install LaTeX to run this command.";\
	fi
test_tangle: .build/have_tangle
.build/have_tangle:
	@echo -n "Testing CTANGLE or NOTANGLE.."
	@(which ctangle &> /dev/null && touch .build/have_tangle) || \
	(which notangle &> /dev/null && touch .build/have_tangle) ||true
	@if [ -e .build/have_tangle ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install cweb or noweb to run this command.";\
	fi
test_cc: .build/have_cc
.build/have_cc:
	@echo -n "Testing GCC or CLANG........."
	@(which gcc &> /dev/null && touch .build/have_cc) || \
	(which clang &> /dev/null && touch .build/have_cc) ||true
	@if [ -e .build/have_cc ]; then \
	echo "OK";  \
	else /bin/echo -e "\033[31mFAILED\033[m";\
	touch .error;\
	echo "ERROR: Install gcc or clang to run this command.";\
	fi
install: uninstall
	install -c bin/weaver ${INSTALL_BIN_DIR}
	install -d ${INSTALL_SHARE_DIR}/base
	install -d ${PROJECT_SHARE}
	install -d ${PROJECT_SHARE}/conf
	install -d ${PROJECT_SHARE}/src/weaver
	install -d ${PROJECT_SHARE}/fonts
	install -d ${PROJECT_SHARE}/src/misc
	install -d ${PROJECT_SHARE}/src/misc/sqlite
	install -c project/fonts/init.mf ${PROJECT_SHARE}/fonts/
	install -c project/Makefile ${PROJECT_SHARE}
	install -c project/prog.Makefile ${PROJECT_SHARE}
	install -c project/web.Makefile ${PROJECT_SHARE}
	install -c project/basefile.c ${INSTALL_SHARE_DIR}
	install -c project/basefile.h ${INSTALL_SHARE_DIR}
	install -c project/COPYING ${PROJECT_SHARE}
	install -c project/conf/conf.h ${PROJECT_SHARE}/conf
	install -c project/src/misc/sqlite/sqlite3.h \
                             ${PROJECT_SHARE}/src/misc/sqlite/
	install -c project/src/misc/sqlite/sqlite3.c \
                             ${PROJECT_SHARE}/src/misc/sqlite/
	install -c project/src/weaver/weaver.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/weaver.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/conf_begin.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/conf_end.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/memory.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/memory.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/window.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/window.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/canvas.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/canvas.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/vertex_interface.glsl \
						${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/fragment_interface.glsl \
	                                        ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/vertex_image_interface.glsl \
						${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/fragment_image_interface.glsl \
	                                        ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/vertex_interface_texture.glsl \
		${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/fragment_interface_texture.glsl \
		${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/plugins.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/plugins.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/interface.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/interface.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/shaders.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/shaders.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/sound.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/sound.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/numeric.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/numeric.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/gif.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/gif.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/database.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/database.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/metafont.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/metafont.c ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/trie.h ${PROJECT_SHARE}/src/weaver
	install -c project/src/weaver/trie.c ${PROJECT_SHARE}/src/weaver
uninstall:
	rm -rf ${INSTALL_SHARE_DIR}
	rm -f ${INSTALL_BIN_DIR}/weaver
clean:
	rm -rf *.o *~ src/*~
	rm -f bin/*
	rm -f project/src/weaver/*
	rm -f src/*
	rm -f cweb/weaver.w
	rm -f .log
