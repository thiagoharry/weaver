SHELL := /usr/bin/env bash
PROG=$(shell cat .weaver/name)
OBJ=$(shell for i in src/*.c; do echo $$(basename $${i%%.c}).o; done)
PLUGINS=$(shell shopt -s nullglob dotglob; for i in plugins/*.c; do\
         echo compiled_plugins/$$(basename $${i%%.c}).so; done)
W_OBJ=$(shell for i in src/weaver/*.c; do\
        echo .weaver/$$(basename $${i%%.c}).o; done)
#MISC_OBJ=.misc/sqlite3.o
HEADERS=$(shell echo src/*.h src/weaver/*.h)
DEFINES=-DW_PROG=\"${PROG}\"
FLAGS=-Wall -O2 -Os -Wextra -Wshadow -Wundef -std=gnu99  ${CPPFLAGS}
SOURCE_TEST=$(shell egrep "^\#define[ \t]+W_SOURCE[ \t]+W_" conf/conf.h | egrep -o "(W_C|W_CPP)")
DONT_USE_PNG=$(shell grep "^\#define[ \t]\+W_DISABLE_PNG" conf/conf.h)
DONT_USE_MP3=$(shell grep "^\#define[ \t]\+W_DISABLE_MP3" conf/conf.h)
#ifeq ($(DONT_USE_MP3),)
#LIBMP3=$(shell pkg-config --libs libmpg123)
#INCMP3=$(shell pkg-config --cflags libmpg123)
#else
#LIBMP3=
#endif
#ifeq ($(DONT_USE_PNG),)
#LIBPNG=$(shell pkg-config --libs libpng)
#INCPNG=$(shell pkg-config --cflags libpng)
#else
#LIBPNG=
#endif
#INCLUDES=-I$(shell pkg-config --cflags x11 gl glew openal) ${INCMP3} ${INCPNG}
INCLUDES=-include conf/conf.h
LIB=-lm -pthread -lX11 -lEGL -lGLESv2
all: ${OBJ} ${W_OBJ} ${HEADERS} ${PLUGINS} ${MISC_OBJ} conf/conf.h
	$(CC) ${INCLUDES} ${DEFINES} ${FLAGS} ${OBJ} ${W_OBJ} ${MISC_OBJ} -o ${PROG} ${LIB} ${LDFLAGS}
%.o : src/%.c ${HEADERS} conf/conf.h
	$(CC) ${DEFINES} ${INCLUDES} ${FLAGS} -c $<
compiled_plugins/%.so: plugins/%.c ${HEADERS} conf/conf.h
	$(CC) ${DEFINES} -DW_PLUGIN_CODE -Wno-unused-parameter ${FLAGS} -fPIC -shared -o $@ $<
.weaver/%.o : src/weaver/%.c ${HEADERS} conf/conf.h
	$(CC) ${DEFINES} ${INCLUDES} ${FLAGS} -c $< -o $(subst src/weaver/,.weaver/,$(subst .c,.o,$<))
.misc/sqlite3.o: src/misc/sqlite/sqlite3.c src/misc/sqlite/sqlite3.h
	mkdir -p .misc
	$(CC) ${DEFINES} -O2 -c src/misc/sqlite/sqlite3.c -o .misc/sqlite3.o
