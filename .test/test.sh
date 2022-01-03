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

function assertEqualFiles(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if  cmp -s "${2}" "${3}" > /dev/null ; then
	    echo "[OK]"
	    OK=$((${OK}+1))
    else
	    echo "[FAIL]"
	    FAIL=$((${FAIL}+1))
    fi
}

function assertDirectoryExist(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if  [ -d "${2}" ]; then
	echo "[OK]"
	OK=$((${OK}+1))
    else
	echo "[FAIL]"
	FAIL=$((${FAIL}+1))
    fi
}

function assertExecutableExists(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if  [ -x "${2}" ]; then
	echo "[OK]"
	OK=$((${OK}+1))
    else
	echo "[FAIL]"
	FAIL=$((${FAIL}+1))
    fi
}

function assertExecutableRun(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if  ${2} 2> /dev/null; then
	echo "[OK]"
	OK=$((${OK}+1))
    else
	echo "[FAIL]"
	FAIL=$((${FAIL}+1))
    fi
}

function assertExecutableDontRun(){
    LENGTH_STRING=${#1}
    NUMBER_OF_TESTS=$((${NUMBER_OF_TESTS} + 1))
    echo -n ${1}
    for (( i=2; i <= $((65-${LENGTH_STRING})); ++i )); do
	echo -n "."
    done
    if  ${2} 2> /dev/null; then
	echo "[FAIL]"
	FAIL=$((${FAIL}+1))
    else
	echo "[OK]"
	OK=$((${OK}+1))
    fi
}


function print_result(){
    echo ${NUMBER_OF_TESTS}" tests: "${OK}" sucess, "${FAIL}" fails"
    echo
}

function test_invocation(){
    if [ "${OSTYPE}" == "msys" ]; then
        ./.test/bin/weaver > .test/file1.dat
        echo -ne "    .  .     You are outside a Weaver Directory.\r\n   .|  |.    The following command uses are available:\r\n   ||  ||\r\n   \\\\\\()//  weaver\r\n   .={}=.      Print this message and exits.\r\n  / /\`'\\ \\\\\r\n  \` \\  / '  weaver PROJECT_NAME\r\n     \`'        Creates a new Weaver Directory with a new\r\n               project.\r\n" > .test/file2.dat
        assertEqualFiles "Testing simple invocation" .test/file1.dat .test/file2.dat
        rm .test/file1.dat .test/file2.dat
    else
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
    fi
}

function test_new_project(){
    if [ "${OSTYPE}" == "msys" ]; then
        ./.test/bin/weaver .test\\test
    else
        ./.test/bin/weaver .test/test
    fi
    assertDirectoryExist "Testing new project creation" .test/test
    cd .test/test
    #######
    echo -e "#include \"game.h\"\n\nint main(void){\nWinit();\nWexit();\nreturn 0;\n}\n" > src/game.c
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make > /dev/null
    fi
    assertExecutableExists "Testing project compilation" test
    ########
    rm -f test
    cp ../test1.c src/game.c
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make &> /dev/null
    fi
    assertExecutableRun "Testing game main loops" ./test
    #######
    echo "#define W_MAX_SUBLOOP 2" > conf/conf.h
    rm -f test
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make &> /dev/null
    fi
    assertExecutableDontRun "Testing main loop limits" ./test
    #######
    rm -f test
    cp ../test2.c src/game.c
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make &> /dev/null
    fi
    assertExecutableRun "Testing main loop flow" ./test
    ####### Memory test
    rm -f test
    cp ../test3.c src/game.c
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make &> /dev/null
    fi
    assertExecutableRun "Testing memory subsystem" ./test
    ####### RNG test
    rm -f test
    echo "#include \"game.h\"" > src/game.c
    echo "#include <inttypes.h>" >> src/game.c
    echo "int main(void){" >> src/game.c
    echo "Winit();" >> src/game.c
    echo "printf(\"%\" PRIx64 \"\", W.rand());" >> src/game.c
    echo "Wexit();" >> src/game.c
    echo "}" >> src/game.c
    echo "#define W_RNG_CHACHA20" > conf/conf.h
    #echo "#define W_DEBUG_RNG" >> conf/conf.h
    echo "#define W_RNG_SEED {0x07cc385417a42d75, 0x0597cd50b285404e}" >> conf/conf.h
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make &> /dev/null
    fi
    ./test > file1.dat
    echo -ne "e9a250eea9e8bf94" > file2.dat
    assertEqualFiles "Testing RNG subsystem" file1.dat file2.dat
    #exit
    rm file1.dat file2.dat
    ####### Shader and user interface test
    rm -f test
    echo "#define W_MAX_MEMORY 16384" > conf/conf.h
    cp ../test4.c src/game.c
    cp ../shader.glsl shaders/
    if [[ ${OSTYPE} == *"bsd"* ]]; then
	gmake &> /dev/null
    elif [[ ${OSTYPE} ==  "msys" ]]; then
	MSBuild.exe &> /dev/null
    else
	make 1> /dev/null
    fi
    assertExecutableRun "Testing shader and user interface" ./test
    #######
    cd - > /dev/null
    rm -rf .test/test
}

echo -e "Running tests...\n"

test_invocation &&
    test_new_project

print_result

if [ "${OSTYPE}" == "msys" ]; then
    read
fi

if [[  ${FAIL} > 0 ]]; then
    exit 1
fi
