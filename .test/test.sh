#!/bin/bash

NUMBER_OF_TESTS=0
OK=0
FAIL=0

function assert(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if [ "${2}" == "1" ]; then
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
    TEXT="..."
    R=0
    if [ "${OUTPUT}" == "${TEXT}" ] ; then
	R=1
    else
	R=0
    fi
    assert "Testing simple invocation" "${R}"
}

test_invocation
print_result

