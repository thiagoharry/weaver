@* Plugins.

Um projeto Weaver pode suportar \italico{plugins}. Mas o que isso
significa depende se o projeto está sendo compilado para ser um
executável ELF ou uma página web.

Do ponto de vista de um usuário, o que chamamos de \italico{plugin}
deve ser um único arquivo com código C (digamos que
seja \monoespaco{myplugin.c}). Este arquivo pode ser copiado e colado
para o diretório \monoespaco{plugins} de um Projeto Weaver e então
subitamente o projeto passa a ter acesso à duas funções. Uma delas que
ativa o \italico{plugin} (que no caso será
|Wenable_plugin("myplugin")|) e uma que desativa (no caso,
|Wdisable_plugin("myplugin")|).

Quando um \italico{plugin} está ativo, ele pode passar a executar
alguma atividade durante todo \italico{loop} principal e também pode
executar atividades de inicialização no momento em que é ativado. No
momento em que é desativado, ele executa suas atividades de
finalização. Um plugin também pode se auto-ativar automaticamente
durante a inicialização dependendo de sua natureza.

Uma atividade típica que podem ser implementadas via \italico{plugin}
é um esquema de tradução de teclas do teclado para que teclados com
símbolos exóticos sejam suportados. Ele só precisaria definir o
esquema de tradução na inicialização e nada precisaria ser feito em
cada iteração do \italico{loop} principal. Ou pode ser feito
um \italico{plugin} que não faça nada em sua inicialização, mas em
todo \italico{loop} principal mostre no canto da tela um indicador de
quantos \italico{frames} por segundo estão sendo executados.

Mas as possibilidades não param nisso. Uma pessoa pode projetar um
jogo de modo que a maior parte das entidades que existam nele sejam na
verdade \italico{plugins}. Desta forma, um jogador poderia
personalizar sua instalação do jogo removendo elementos não-desejados
do jogo ou adicionando outros meramente copiando arquivos.

Neste ponto, esbarramos em algumas limitações do ambiente
Web. Programas compilados por meio de Emscripten só podem ter os tais
``\italico{plugins}'' definidos durante a compilação. Para eles, o
código do \italico{plugin} deve ser injetado em seu proprio código
durante a compilação. De fato, pode-se questionar se podemos realmente
chamar tais coisas de \italico{plugins}.

Já programas compilados para executáveis Linux possuem muito mais
liberdade. Eles podem checar por seus \italico{plugins} em tempo de
execução, não de compilação. De fato, isso nos permite recompilar os
plugins enquanto o nosso programa está executando e assim modificar um
jogo em desenvolvimento sem a necessidade de interromper sua
execução. Essa técnica é chamada de \negrito{programação interativa}.

@*1 Interface dos Plugins.

Todo \italico{plugin}, cujo nome é |MYPLUGIN|, e cujo código está
em \monoespaco{plugins/MYPLUGIN.c}, deve definir as seguintes funções:

\macronome|void _init_plugin_MYPLUGIN(void)|: Esta função será
executada toda vez que o \italico{plugin} for ativado por meio de
|Wenable_plugin|.

\macronome|void _fini_plugin_MYPLUGIN(void)|: Esta função será
executada toda vez que o \italico{plugin} for desativado por meio de
|Wdisable_plugin|.

\macronome|void _run_plugin_MYPLUGIN(void)|: Esta função será
executada toda vez que um \italico{plugin} estiver ativado e
estivermos em uma iteração do \italico{loop} principal.

Pode-se usar variáveis globais estáticas, mas deve-se ter em mente que
o seu conteúdo será perdido e reinicializado toda vez que se desativa
e ativa o \italico{plugin}. Como a nossa interface atualmente não
suporta em \italico{plugins} qualquer tipo de variável global ou
funções com retorno, embora o \italico{plugin} possa ler informações e
variáveis do programa, ele não tem como passar qualquer tipo de
informação para o programa principal. Isso talvez mude futuramente,
mas o formato em que é feita uma comunicação entre o programa
e \italico{plugins} precisa ser pensado com cuidado antes de
implementado.

Deve-se também tomar cuidado com funções de bibliotecas externas
usadas em \italico{plugins}. Algumas funções podem usar variáveis
globais que teriam seu valor perdido ao desativar um \italico{plugin}
e ativá-lo novamente. Este também é um dos motivos pelo qual
a \italico{engine} Weaver define a sua própria versão de muitas
bibliotecas.
