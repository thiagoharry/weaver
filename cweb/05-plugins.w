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

Além disso, um \italico{plugin} não pode manter qualquer tipo de
estado em variáveis globais, mesmo que seja em variáveis
estáticas. Esta é uma restrição bastante séria, mas precis ser
cumprida especialmente se a ideia é usar \negrito{programação
interativa}. Qualquer tipo de informação global seria perdida no
momento em que o \italico{plugin} fôsse modificado urante a execução
do programa.

Se a ideia não é suportar a modificação do programa durante a
execução, então as variáveis globais não são um problema tão grave. De
qualquer forma, a restrição ainda será mantida a \ialico{engine}
Weaver não irá fornecer em seu \italico{site} ou qualquer outro canal
oficial \italico{plugins} que não adotem a restrição. Mesmo que na
ausência de modificação interativa tais \italico{plugins} funcionem
sem \italico{bugs}.

Variáveis globais podem ser inseridas por meio de bibliotecas
externas, então deve-se tomar cuidado com o que se adiciona em
um \italico{plugin}. Este é um dos motivos pelo qual Weaver adiciona
estaticamente sua própria versão de funcionalidades de outras
bibliotecas.
