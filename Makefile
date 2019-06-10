CC=gcc
FLAGS=-Wall -O2

doc:
	magitex-cweb weaver-memory-manager.tex
	dvipdf weaver-memory-manager.dvi
src: weaver-memory-manager.tex
	ctangle weaver-memory-manager.tex
	rm weaver-memory-manager.c
test: src tests/test.c src/memory.c
	${CC} ${FLAG} tests/test.c src/memory.c -o test
	./test
clean:
	rm -f *~ *.core *.scn *.dvi *.idx *.log tests/*~ rm test
distclean: clean
	rm -f test weaver-memory-manager.pdf src/*
