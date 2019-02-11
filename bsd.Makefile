TANGLE=ctangle
CC=gcc
FLAGS=-Wall -O2 -Os -Wextra -Wshadow -Wundef -std=c99 -pedantic -g
OBJ=main.o memory.o weaver.o
LINK=-lm

main-prog:
	@echo -n "Compiling...................."
	@${TANGLE} cweb/weaver.w > /dev/null
	@rm weaver.c
	@${CC} ${FLAGS} src/weaver.c -o bin/weaver > /dev/null
	@echo "OK"
