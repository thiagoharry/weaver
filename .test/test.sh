#!/bin/bash

NUMBER_OF_TESTS=0
OK=0
FAIL=0

function assertEqual(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if [ "${2}" == "${3}" ]; then
	echo "[OK]"
	OK=$((${OK}+1))
    else
	echo "[FAIL]"
	FAIL=$((${FAIL}+1))
    fi
}

function print_result(){
    echo ${NUMBER_OF_TESTS}" tests: "${OK}" sucess, "${FAIL}" fails"
    echo
}

function test_invocation(){
    OUTPUT=$(./.test/bin/weaver)
    TEXT="    .  .     You are outside a Weaver Directory.
   .|  |.    The following command uses are available:
   ||  ||
   \\\\()//  weaver
   .={}=.      Print this message and exits.
  / /\`'\\ \\
  \` \\  / '  weaver PROJECT_NAME
     \`'        Creates a new Weaver Directory with a new
               project."
    assertEqual "Testing simple invocation" "${OUTPUT}" "${TEXT}"
}

test_invocation
print_result

