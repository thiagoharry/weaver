@* Plugins.

Um projeto Weaver pode suportar \italico{plugins}. Mas o que isso
significa depende se o projeto está sendo compilado para ser um
executável ELF ou uma página web.

Do ponto de vista de um usuário, o que chamamos de \italico{plugin}
deve ser um único arquivo com código C (digamos que
seja \monoespaco{myplugin.c}). Este arquivo pode ser copiado e colado
para o diretório \monoespaco{plugins} de um Projeto Weaver e então
subitamente podemos passar a ativá-lo e desativá-lo por meio das funções
|W.enable_plugin("myplugin")| e |W.disable_plugin("myplugin")|.

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
do jogo ou adicionando outros meramente copiando arquivos. Da mesma
forma, ele poderia recompilar os \italico{plugins} enquanto o jogo
executa e as mudanças que ele faria poderiam ser refletidas
imediatamente no jogo em execução, sem precisar fechá-lo. Essa técnica
é chamada de \negrito{programação interativa}.

Neste ponto, esbarramos em algumas limitações do ambiente
Web. Programas compilados por meio de Emscripten só podem ter os tais
``\italico{plugins}'' definidos durante a compilação. Para eles, o
código do \italico{plugin} deve ser injetado em seu proprio código
durante a compilação. De fato, pode-se questionar se podemos realmente
chamar tais coisas de \italico{plugins}.

@*1 Interface dos Plugins.

Todo \italico{plugin}, cujo nome é |MYPLUGIN| (o nome deve ser único
para cada \italico{plugin}), e cujo código está
em \monoespaco{plugins/MYPLUGIN.c}, deve definir as seguintes funções:

\macronome|void _init_plugin_MYPLUGIN(void)|: Esta função será
executada somente uma vez quando o seu jogo detectar a presença do
\italico{plugin}. Tipicamente isso será durante a inicialização do
programa. Mas o \italico{plugin} pode ser adicionado à algum diretório
do jogo no momento em que ele está em execução. Neste caso, o jogo o
detectará assim que entrar no próximo \italico{loop} principal e
executará a função neste momento.

\macronome|void _fini_plugin_MYPLUGIN(W_PLUGIN)|: Esta função será
executada apenas uma vez quando o jogo for finalizado.

\macronome|void _run_plugin_MYPLUGIN(W_PLUGIN)|: Esta função será
executada toda vez que um \italico{plugin} estiver ativado e
estivermos em uma iteração do \italico{loop} principal.

\macronome|void _enable_MYPLUGIN(W_PLUGIN)|: Esta função será executada
toda vez que um plugin for ativado por meio de
|W.enable_plugin("MYPLUGIN")|.

\macronome|void _disable_MYPLUGIN(W_PLUGIN)|: Esta função será executada
toda vez que um plugin for ativado por meio de
|W.enable_plugin("MYPLUGIN")|.

Um \italico{plugin} terá acesso à todas as funções e variáveis que são
mencionadas no sumário de cada capítulo, com as notáveis exceções de
|Winit|, |Wquit|, |Wrest| e |Wloop|. Mesmo nos casos em que o plugin é
uma biblioteca compartilhada invocada dinamicamente, isso é possível
graças ao argumento |W_PLUGIN| recebido como argumento pelas
funções. Ele na verdade é a estrutura |W|:

@<Cabeçalhos Weaver@>+=
#define W_PLUGIN struct _weaver_struct *_W
@

A mágica para usar as funções e variáveis na forma |W.flush_input()| e
não na deselegante forma |W->flush_input()| será obtida por meio de
macros adicionais inseridas pelo \monoespaco{Makefile} ao invocar o
compilador para os \italico{plugins}.

Para saber onde encontrar os \italico{plugins} durante a execução,
definimos em \monoespaco{conf/conf.h} as seguintes macros:

\macronome|W_INSTALL_DIR|: O diretório em que o jogo será instalado.

\macronome|W_PLUGIN_PATH|: Uma string com lista de diretórios
separadas por dois pontos (``:'').
