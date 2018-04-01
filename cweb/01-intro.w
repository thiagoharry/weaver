@* Introdução.

Este é o código-fonte de \monoespaco{weaver}, uma \italico{engine} (ou
motor) para desenvolvimento de jogos feita em C utilizando-se da
técnica de programação literária.

Um motor é um conjunto de bibliotecas e programas utilizado para
facilitar e abstrair o desenvolvimento de um jogo. Jogos de
computador, especialmente jogos em 3D são programas sofisticados demais
e geralmente é inviável começar a desenvolver um jogo do zero. Um
motor fornece uma série de funcionalidades genéricas que facilitam o
desenvolvimento, tais como gerência de memória, renderização de
gráficos bidimensionais e tridimensionais, um simulador de física,
detector de colisão, suporte à animações, som, fontes, linguagem de
script e muito mais.

Programação literária é uma técnica de desenvolvimento de programas de
computador que determina que um programa deve ser especificado
primariamente por meio de explicações didáticas de seu
funcionamento. Desta forma, escrever um software que realiza
determinada tarefa não deveria ser algo diferente de escrever um livro
que explica didaticamente como resolver tal tarefa. Tal livro deveria
apenas ter um rigor maior combinando explicações informais em prosa
com explicações formais em código-fonte. Programas de computador podem
então extrair a explicação presente nos arquivos para gerar um livro
ou manual (no caso, este PDF) e também extrair apenas o código-fonte
presente nele para construir o programa em si. A tarefa de montar o
programa na ordem certa é de responsabilidade do programa que extrai o
código. Um programa literário deve sempre apresentar as coisas em uma
ordem acessível para humanos, não para máquinas.

Por exemplo, para produzir este PDF, utiliza-se um programa chamado
\TeX, o qual por meio do formato \MaGiTeX\ instalado, compreende
código escrito em um formato específico de texto e o formata de
maneira adequada.  O \TeX\ gera um arquivo no formato DVI, o qual é
convertido para PDF. Para produzir o motor de desenvolvimento de jogos
em si utiliza-se sobre os mesmos arquivos fonte um programa chamado
CTANGLE, que extrai o código C (além de um punhado de códigos GLSL)
para os arquivos certos. Em seguida, utiliza-se um compilador como GCC
ou CLANG para produzir os executáveis. Felizmente, há
\monoespaco{Makefiles} para ajudar a cuidar de tais detalhes de
construção.

Os pré-requisitos para se compreender este material são ter uma boa
base de programação em C e ter experiência no desenvolvimento de
programas em C para Linux. Alguma noção do funcionamento de OpenGL
também ajuda.

@*1 Copyright e licenciamento.

Weaver é desenvolvida pelo programador Thiago ``Harry'' Leucz
Astrizi. Abaixo segue a licença do software:

\espaco{5mm}\linha
\alinhaverbatim
Copyright (c) Thiago Leucz Astrizi 2015

This program is free software: you can redistribute it and/or
modify it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see
<http://www.gnu.org/licenses/>.
\alinhanormal
\linha\espaco{5mm}

A tradução não-oficial da licença é:

\quebra\linha
\alinhaverbatim
Copyright (c) Thiago Leucz Astrizi 2015

Este programa é um software livre; você pode redistribuí-lo e/ou
modificá-lo dentro dos termos da Licença Pública Geral GNU Affero como
publicada pela Fundação do Software Livre (FSF); na versão 3 da
Licença, ou (na sua opinião) qualquer versão.

Este programa é distribuído na esperança de que possa ser útil,
mas SEM NENHUMA GARANTIA; sem uma garantia implícita de ADEQUAÇÃO
a qualquer MERCADO ou APLICAÇÃO EM PARTICULAR. Veja a
Licença Pública Geral GNU Affero para maiores detalhes.

Você deve ter recebido uma cópia da Licença Pública Geral GNU Affero
junto com este programa. Se não, veja
<http://www.gnu.org/licenses/>.
\alinhanormal
\linha\espaco{5mm}

A versão completa da licença pode ser obtida junto ao código-fonte
Weaver ou consultada no link mencionado.

@*1 Filosofia Weaver.

Estes são os princípios filosóficos que guiam o desenvolvimento deste
software. Qualquer coisa que vá de encontro à eles devem ser tratados
como \italico{bugs}.

\negrito{1- Software é conhecimento sobre como realizar algo escrito em
  linguagens formais de computadores. O conhecimento deve ser livre
  para todos. Portanto, Weaver deverá ser um software livre e deverá
  também ser usada para a criação de jogos livres.}

A arte de um jogo pode ter direitos de cópia. Ela deveria ter uma
licença permisiva, pois arte é cultura, e portanto, também não deveria
ser algo a ser tirado das pessoas. Mas weaver não tem como impedi-lo
de licenciar a arte de um jogo da forma que for escolhida. Mas como
Weaver funciona injetando estaticamente seu código em seu jogo e
Weaver está sob a licença Affero GPL, isso significa que seu jogo
também deverá estar sob esta mesma licença (ou alguma outra
compatível).

Basicamente isso significa que você pode fazer quase qualquer coisa
que quiser com este software. Pode copiá-lo. Usar seu código-fonte
para fazer qualquer coisa que queira (assumindo as
responsabilidades). Passar para outras pessoas. Modificá-lo. A única
coisa não permitida é produzir com ele algo que não dê aos seus
usuários exatamente as mesmas liberdades. Se você criar um jogo usando
Weaver e distribui-lo ou colocá-lo em uma página na Internet para
outras pessoas jogarem, um link para o download do código-fonte do
jogo deve ser fornecido. Mas não é necessário fornecer junto os
arquivos de áudio, texturas e outros elementos que constituem a parte
artística, sem códigos de programação.

As seguintes quatro liberdades devem estar presentes em Weaver e nos
jogos que ele desenvolve:

Liberdade 0: A liberdade para executar o programa, para qualquer
propósito.

Liberdade 1: A liberdade de estudar o software.

Liberdade 2: A liberdade de redistribuir cópias do programa de modo
que você possa ajudar ao seu próximo.

Liberdade 3: A liberdade de modificar o programa e distribuir estas
modificações, de modo que toda a comunidade se beneficie.

\negrito{2- Weaver deve estar bem-documentado.}

As quatro liberdades anteriores não são o suficiente para que as
pessoas realmente possam estudar um software. Código ofuscado ou de
difícil compreensão dificulta que as pessoas a exerçam. Weaver deve
estar completamente documentada. Isso inclui explicação para todo o
código-fonte que o projeto possui. O uso de \MaGiTeX\ e CWEB é um
reflexo desta filosofia.

Algumas pessoas podem estranhar também que toda a documentação do
código-fonte esteja em português. Estudei por anos demais em
universidade pública e minha educação foi paga com dinheiro do povo
brasileiro. Por isso acho que minhas contribuições devem ser pensadas
sempre em como retribuir à isto. Por isso, o português brasileiro será
o idioma principal na escrita deste software.

Infelizmente, isso tamém conflita com o meu desejo de que este projeto
seja amplamente usado no mundo todo. Geralmente espera-se que código e
documentação esteja em inglês. Para lidar com isso, pretendo que a
documentação on-line e guia de referência das funções esteja em
inglês. Os nomes de funções e de variáveis estarão em inglês. Mas as
explicações aqui serão em português.

Com isso tento conciliar as duas coisas, por mais difícil que isso
seja.

\negrito{3- Weaver deve ter muitas opções de configuração para que
  possa atender à diferentes necessidades.}

É terrível quando você tem que lidar com abominações como:

@(/tmp/dummy.c@>=
  CreateWindow("nome da classe", "nome da janela", WS_BORDER | WS_CAPTION |
               WS_MAXIMIZE, 20, 20, 800, 600, handle1, handle2, handle3, NULL);
@

Cada projeto deve ter um arquivo de configuração e muito da
funcionalidade pode ser escolhida lá. Escolhas padrão sãs devem ser
escolhidas e estar lá, de modo que um projeto funcione bem mesmo que
seu autor não mude nada nas configurações. E concentrando
configurações em um arquivo, retiramos complexidade das funções. As
funções não precisam então receber mais de 10 argumentos diferentes e
não é necessário também ficar encapsulando os 10 argumentos em um
objeto de configuração, o qual é mais uma distração que solução para a
complexidade.

Em todo projeto Weaver haverá um arquivo de
configuração \monoespaco{conf/conf.h}, que modifica o funcionamento do
motor. Como pode ser deduzido pela extensão do nome do arquivo, ele é
basicamente um arquivo de cabeçalho C onde poderão ter
vários |#define|s que modificarão o funcionamento de seu
jogo.

\negrito{4- Weaver não deve tentar resolver problemas sem solução. Ao
  invés disso, é melhor propor um acordo mútuo entre usuários.}

Computadores tornam-se coisas complexas porque pessoas tentam resolver
neles problemas insolúveis. É como tapar o sol com a peneira. Você na
verdade consegue fazer isso. Junte um número suficientemente grande de
peneiras, coloque uma sobre a outra e você consegue gerar uma sombra o
quão escura se queira. Assim são os sistemas modernos que usamos nos
computadores.

Como exemplo de tais tentativas de solucionar problemas insolúveis,
temos a tentativa de fazer com que Sistemas Operacionais proprietários
sejam seguros e livres de vírus, garantir privacidade, autenticação e
segurança sobre HTTP e até mesmo coisas como o gerenciamento de
memória. Pode-se resolver tais coisas apenas adicionando camadas e
mais camadas de complexidade, e mesmo assim, não funcionará em
realmente 100\% dos casos.

Quando um problema não tem uma solução satisfatória, isso jamais deve
ser escondido por meio de complexidades que tentam amenizar ou sufocar
o problema. Ao invés disso, a limitação natural da tarefa deve ficar
clara para o usuário, e deve-se trabalhar em algum tipo de
comportamento que deve ser seguido pela engine e pelo usuário para que
se possa lidar com o problema combinando os esforços de humanos e
máquinas naquilo que cada um dos dois é melhor em fazer.

\negrito{5- Um jogo feito usando Weaver deve poder ser instalado em
  um computador simplesmente distribuindo-se um instalador, sem
  necessidade de ir atrás de dependências.}

Este é um exemplo de problema insolúvel mencionado anteriormente. Para
isso a API Weaver é inserida estaticamente em cada projeto Weaver ao
invés de ser na forma de bibliotecas compartilhadas. Mesmo assim ainda
haverão dependências externas. Iremos então tentar minimizar elas e
garantir que as duas maiores distribuições Linux no DistroWatch sejam
capazes de rodar os jogos sem dependências adicionais além daquelas
que já vem instaladas por padrão.

\negrito{6- Wever deve ser fácil de usar. Mais fácil que a maioria
  das ferramentas já existentes.}

Isso é obtido mantendo as funções o mais simples possíveis e
fazendo-as funcionar seguindo padrões que são bons o bastante para a
maioria dos casos. E caso um programador saiba o que está fazendo, ele
deve poder configurar tais padrões sem problemas por meio do arquivo
\monoespaco{conf/conf.h}.

Desta forma, uma função de inicialização poderia se chamar
\monoespaco{Winit()} e não precisar de nenhum argumento. Coisas como
gerenciar a projeção das imagens na tela devem ser transparentessem
precisar de uma função específica após os objetos que compõe o
ambiente serem definidos.

@*1 Instalando Weaver.

% Como Weaver ainda está em construção, isso deve ser mudado bastante.

Para instalar Weaver em um computador, assumindo que você está fazendo
isso à partir do código-fonte, basta usar o comando \monoespaco{make} e
\monoespaco{make install} (o segundo comando como \italico{root}).

Atualmente, os seguintes programas são necessários para se compilar
Weaver:

\negrito{ctangle} ou \negrito{notangle}: Extrai o código C dos arquivos de
  \monoespaco{cweb/}.

\negrito{clang} ou \negrito{gcc}: Um compilador C que gera executáveis à
partir de código C.

\negrito{make:} Interpreta e executa comandos do Makefile.


Os dois primeiros programas podem vir em pacotes chamados
de \negrito{cweb} ou \negrito{noweb}. Adicionalmente, os seguintes
programas são necessários para se gerar a documentação:

\negrito{\TeX\ e \MaGiTeX}: Usado para ler o código-fonte CWEB e gerar um
 arquivo DVI.

\negrito{dvipdf}: Usado para converter um arquivo \monoespaco{.dvi} em
  um \monoespaco{.pdf}.

\negrito{graphviz}: Gera representações gráficas de grafos.


Além disso, para que você possa efetivamente usar Weaver criando seus
próprios projetos, você também poderá precisar de:

\negrito{emscripten:} Compila código C para Javascript e assim
rodar em um navegador.

\negrito{opengl:} Permite gerar executáveis nativos com gráficos em 3D.

\negrito{xlib:} Permite gerar executáveis nativos gráficos.

\negrito{xxd:} Gera representação hexadecimal de arquivos. Insere
 o código dos shaders no programa. Por motivos obscuros, algumas
 distribuições trazem este último programa no mesmo pacote
 do \negrito{vim}.


@*1 O programa \monoespaco{weaver}.

Weaver é uma engine para desenvolvimento de jogos que na verdaade é
formada por várias coisas diferentes. Quando falamos em código do
Weaver, podemos estar nos referindo à código de algum dos programas
executáveis usados para se gerenciar a criação de seus jogos, podemos
estar nos referindo ao código da API Weaver que é inserida em cada um
de seus jogos ou então podemos estar nos referindo ao código de algum
de seus jogos.

Para evitar ambigüidades, quando nos referimos ao programa executável,
nos referiremos ao \negrito{programa Weaver}. Seu código-fonte será
apresentado inteiramente neste capítulo. O programa é usado
simplesmente para criar um novo projeto Weaver. E um projeto é um
diretório com vários arquivos de desenvolvimento contendo código-fonte
e multimídia. Por exemplo, o comando abaixo cria um novo projeto de um
jogo chamado \monoespaco{pong}:

\alinhaverbatim
weaver pong

\alinhanormal

A árvore de diretórios exibida parcialmente abaixo é o que é criado
pelo comando acima (diretórios são retângulos e arquivos são
círculos):

\imagem{cweb/diagrams/project_dir.eps}

Quando nos referimos ao código que é inserido em seus projetos,
falamos do código da \negrito{API Weaver}. Seu código é sempre inserido
dentro de cada projeto no diretório \monoespaco{src/weaver/}. Você terá
aceso à uma cópia de seu código em cada novo jogo que criar, já que
tal código é inserido estaticamente em seus projetos.

Já o código de jogos feitos com Weaver são tratados por
\negrito{projetos Weaver}. É você quem escreve o seu código, ainda que
a engine forneça como um ponto de partida o código inicial de
inicialização, criação de uma janela e leitura de eventos do teclado e
mouse.

@*2 Casos de Uso do Programa Weaver.

Além de criar um projeto Weaver novo, o programa Weaver tem outros
casos de uso. Eis a lista deles:

\negrito{Caso de Uso 1: Mostrar mensagem de ajuda de criação de
  novo projeto:} Isso deve ser feito toda vez que o usuário estiver
  fora do diretório de um Projeto Weaver e ele pedir ajuda
  explicitamente passando o parâmetro \monoespaco{--help} ou quando ele
  chama o programa sem argumentos (caso em que assumiremos que ele não
  sabe o que fazer e precisa de ajuda).

\negrito{Caso de Uso 2: Mostrar mensagem de ajuda do gerenciamento
  de projeto:} Isso deve ser feito quando o usuário estiver dentro de
  um projeto Weaver e pedir ajuda explicitamente com o argumento
  \monoespaco{--help} ou se invocar o programa sem argumentos (caso em que
  assumimos que ele não sabe o que está fazendo e precisa de ajuda).

\negrito{Caso de Uso 3: Mostrar a versão de Weaver instalada no
  sistema:} Isso deve ser feito toda vez que Weaver for invocada com o
  argumento \monoespaco{--version}.

\negrito{Caso de Uso 4: Atualizar um projeto Weaver existente:}
  Para o caso de um projeto ter sido criado com a versão 0.4 e
  tenha-se instalado no computador a versão 0.5, por exemplo. Para
  atualizar, basta passar como argumento o caminho absoluto ou
  relativo de um projeto Weaver. Independente de estarmos ou não
  dentro de um diretório de projeto Weaver. Atualizar um projeto
  significa mudar os arquivos com a API Weaver para que reflitam
  versões mais recentes.

\negrito{Caso de Uso 5: Criar novo módulo em projeto Weaver:} Para
  isso, devemos estar dentro do diretório de um projeto Weaver e
  devemos passar como argumento um nome para o módulo que não deve
  começar com pontos, traços, nem ter o mesmo nome de qualquer arquivo
  de extensão \monoespaco{.c} presente em \monoespaco{src/} (pois para um
  módulo de nome XXX, serão criados arquivos \monoespaco{src/XXX.c} e
  \monoespaco{src/XXX.h}).

\negrito{Caso de Uso 6: Criar um novo projeto Weaver:} Para isso
  ele deve estar fora de um diretório Weaver e deve passar como
  primeiro argumento um nome válido e não-reservado para seu novo
  projeto. Um nome válido deve ser qualquer um que não comece com
  ponto, nem traço, que não tenha efeitos negativos no terminal (tais
  como mudar a cor de fundo) e cujo nome não pode conflitar com
  qualquer arquivo necessário para o desenvolvimento (por exemplo, não
  deve-se poder criar um projeto chamado \monoespaco{Makefile}).

\negrito{Caso de Uso 7: Criar um novo plugin:} Para isso devemos estar
nno diretório Weaver e devemos receber dois argumentos. O primeiro deve
ser \monoespaco{--plugin} e o segundo deve ser o nome do plugin, o
qual deve ser um nome válido seguindo as mesmas regras dos módulos.

\negrito{Caso de Uso 8: Criar um novo Shader:} Para isso devemos estar
no diretório Weaver e devemos receber dois argumentos. O primeiro deve
ser \monoespaco{--shader} e o segundo deve ser o nome do shader, o
qual deve ser um nome válido seguindo as mesmas regras dos módulos.

\negrito{Caso de Uso 9: Criar um Novo Loop Principal:} Para isso
devemos estar em um diretório Weaver e devemos receber dois
argumentos. O primeiro deve ser \monoespaco{--loop} e o segundo deve
ser o nome do novo loop principal, que também deve ter um nome válido
segundo nossas regras e também as regras de identificadores da
linguagem C.

@*2 Variáveis do Programa Weaver.

O comportamento de Weaver deve depender das seguintes variáveis:

|inside_weaver_directory|: Indicará se o programa está sendo
  invocado de dentro de um projeto Weaver.

|argument|: O primeiro argumento, ou NULL se ele não existir

|argument2|: O segundo argumento, ou NULL se não existir.

|project_version_major|: Se estamos em um projeto Weaver, qual o
  maior número da versão do Weaver usada para gerar o
  projeto. Exemplo: se a versão for 0.5, o número maior é 0. Em
  versões de teste, o valor é sempre 0.

|project_version_minor|: Se estamos em um projeto Weaver, o valor
  do menor número da versão do Weaver usada para gerar o
  projeto. Exemplo, se a versão for 0.5, o número menor é 5. Em
  versões de teste o valor é sempre 0.

|weaver_version_major|: O número maior da versão do Weaver sendo
  usada no momento.

|weaver_version_minor|: O número menor da versão do Weaver sendo
  usada no momento.

|arg_is_path|: Se o primeiro argumento é ou não um caminho
  absoluto ou relativo para um projeto Weaver.

|arg_is_valid_project|: Se o argumento passado seria válido como
  nome de projeto Weaver.

|arg_is_valid_module|: Se o argumento passado seria válido como
  um novo módulo no projeto Weaver atual.

|arg_is_valid_plugin|: Se o segundo argumento existe e se ele é um
 nome válido para um novo plugin.

|arg_is_valid_function|: Se o segundo argumento existe e se ele seria
 um nome válido para um loop principal e também para um arquivo.

|project_path|: Se estamos dentro de um diretório de projeto
  Weaver, qual o caminho para a sua base (onde há o Makefile)

|have_arg|: Se o programa é invocado com argumento.

|shared_dir|: Deverá armazenar o caminho para o diretório onde
  estão os arquivos compartilhados da instalação de Weaver. Por
  padrão, será igual à "\monoespaco{/usr/share/weaver}", mas caso exista a
  variável de ambiente \monoespaco{WEAVER\_DIR}, então este será
  considerado o endereço dos arquivos compartilhados.

|author_name|,|project_name| e |year|: Conterão respectivamente o
  nome do usuário que está invocando Weaver, o nome do projeto atual
  (se estivermos no diretório de um) e o ano atual. Isso será
  importante para gerar as mensagens de Copyright em novos projetos
  Weaver.

|return_value|: Que valor o programa deve retornar caso o programa
  seja interrompido no momento atual.


@*2 Estrutura Geral do Programa Weaver.

Todas estas variáveis serão inicializadas no começo, e se precisar
serão desalocadas no fim do programa, que terá a seguinte estrutura:

@(src/weaver.c@>=
@<Cabeçalhos Incluídos no Programa Weaver@>
@<Macros do Programa Weaver@>
@<Funções auxiliares Weaver@>
int main(int argc, char **argv){@/
  int return_value = 0; /* Valor de retorno. */
  bool inside_weaver_directory = false, arg_is_path = false,
    arg_is_valid_project = false, arg_is_valid_module = false,
    have_arg = false, arg_is_valid_plugin = false,
    arg_is_valid_function = false; /* Variáveis booleanas. */
  unsigned int project_version_major = 0, project_version_minor = 0,
    weaver_version_major = 0, weaver_version_minor = 0,
    year = 0;
  /* Strings UTF-8: */
  char *argument = NULL, *project_path = NULL, *shared_dir = NULL,
    *author_name = NULL, *project_name = NULL, *argument2 = NULL;
  @<Inicialização@>
  @<Caso de uso 1: Imprimir ajuda de criação de projeto@>
  @<Caso de uso 2: Imprimir ajuda de gerenciamento@>
  @<Caso de uso 3: Mostrar versão@>
  @<Caso de uso 4: Atualizar projeto Weaver@>
  @<Caso de uso 5: Criar novo módulo@>
  @<Caso de uso 6: Criar novo projeto@>
  @<Caso de uso 7: Criar novo plugin@>
  @<Caso de uso 8: Criar novo shader@>
  @<Caso de uso 9: Criar novo loop principal@>
END_OF_PROGRAM:
  @<Finalização@>
  return return_value;
}
@

@*2 Macros do Programa Weaver.

O programa precisará de algumas macros. A primeira delas deverá conter
uma string com a versão do programa. A versão pode ser formada só por
letras (no caso de versões de teste) ou por um número seguido de um
ponto e de outro número (sem espaços) no caso de uma versão final do
programa.

Para a segunda macro, observe que na estrutura geral do programa vista
acima existe um rótulo chamado |END_OF_PROGRAM| logo na parte de
finalização. Uma das formas de chegarmos lá é por meio da execução
normal do programa, caso nada dê errado. Entretanto, no caso de um
erro, nós podemos também chegar lá por meio de um desvio incondicional
após imprimirmos a mensagem de erro e ajustarmos o valor de retorno do
programa. A responsabilidade de fazer isso será da segunda macro.

Por outro lado, podemos também querer encerrar o programa previamente,
mas sem que tenha havido um erro. A responsabilidade disso é da
terceira macro que definimos.

@<Macros do Programa Weaver@>=
#define VERSION "Alpha"
#define ERROR() {perror(NULL); return_value = 1; goto END_OF_PROGRAM;}
#define END() goto END_OF_PROGRAM;
@

@*2 Cabeçalhos do Programa Weaver.

@<Cabeçalhos Incluídos no Programa Weaver@>=
#include <sys/types.h> // stat, getuid, getpwuid, mkdir
#include <sys/stat.h> // stat, mkdir
#include <stdbool.h> // bool, true, false
#include <unistd.h> // get_current_dir_name, getcwd, stat, chdir, getuid
#include <string.h> // strcmp, strcat, strcpy, strncmp
#include <stdlib.h> // free, exit, getenv
#include <dirent.h> // readdir, opendir, closedir
#include <libgen.h> // basename
#include <stdarg.h> // va_start, va_arg
#include <stdio.h> // printf, fprintf, fopen, fclose, fgets, fgetc, perror
#include <ctype.h> // isanum
#include <time.h> // localtime, time
#include <pwd.h> // getpwuid
@

@*2 Inicialização e Finalização do Programa Weaver.

Inicializar Weaver significa inicializar as 14 variáveis que serão
usadas para definir o seu comportamento.

@*3 Inicializando Variáveis \monoespaco{inside\_weaver\_directory} e
\monoespaco{project\_path}.

A primeira das variáveis é |inside_weaver_directory|, que deve valer
|false| se o programa foi invocado de fora de um diretório de projeto
Weaver e |true| caso contrário.

Como definir se estamos em um diretório que pertence à um projeto
Weaver? Simples. São diretórios que contém dentro de si ou em um
diretório ancestral um diretório oculto
chamado \monoespaco{.weaver}. Caso encontremos este diretório oculto,
também podemos aproveitar e ajustar a variável |project_path| para
apontar para o local onde ele está. Se não o encontrarmos, estaremos
fora de um diretório Weaver e não precisamos mudar nenhum valor das
duas variáveis, pois elas deverão permanecer com o valor padrão
|NULL|.

Em suma, o que precisamos é de um loop com as seguintes
características:


\negrito{Invariantes}: A variável |complete_path| deve sempre
  possuir o caminho completo do diretório \monoespaco{.weaver} se ele
  existisse no diretório atual.

\negrito{Inicialização:} Inicializamos tanto o |complete_path|
  para serem válidos de acordo com o diretório em que o programa é
  invocado.

\negrito{Manutenção:} Em cada iteração do loop nós verificamos se
  encontramos uma condição de finalização. Caso contrário, subimos
  para o diretório pai do qual estamos, sempre atualizando as
  variáveis para que o invariante continue válido.

\negrito{Finalização}: Interrompemos a execução do loop se uma das
  duas condições ocorrerem:

a) |complete_path == "/.weaver"|: Neste caso não podemos subir mais na
árvore de diretórios, pois estamos na raiz do sistema de arquivos. Não
encontramos um diretório \monoespaco{.weaver}. Isso significa que não
estamos dentro de um projeto Weaver.

b) |complete_path == ".weaver"|: Neste caso encontramos um diretório
\monoespaco{.weaver} e descobrimos que estamos dentro de um projeto
Weaver. Podemos então atualizar a variável |project_path| para o
diretório em que paramos.

Para manipularmos o caminho da árvore de diretórios, usaremos uma
função auxiliar que recebe como entrada uma string com um caminho na
árvore de diretórios e apaga todos os últimos caracteres até apagar
dois ``/''. Assim em ``/home/alice/projeto/diretorio/'' ele retornaria
``/home/alice/projeto'' efetivamente subindo um nível na árvore de
diretórios:

@<Funções auxiliares Weaver@>=
void path_up(char *path){
  int erased = 0;
  char *p = path;
  while(*p != '\0') p ++; // Vai até o fim
  while(erased < 2 && p != path){
    p --;
    if(*p == '/') erased ++;
    *p = '\0'; // Apaga
  }
}
@

Note que caso a função receba uma string que não possua dois ``/'' em
seu nome, obtemos um ``buffer overflow'' onde percorreríamos regiões
de memória indevidas preenchendo-as com zero. Esta função é bastante
perigosa, mas se limitarmos as strings que passamos para somente
arquivos que não estão na raíz e diretórios diferentes da própria raíz
que terminam sempre com ``/'', então não teremos problemas pois a
restrição do número de barras será cumprida. Ex: ``/etc/'' e
``/tmp/file.txt''.

Para checar se o diretório \monoespaco{.weaver} existe, definimos
|directory_exist(x)| como uma função que recebe uma string
correspondente à localização de um arquivo e que deve retornar 1 se
|x| for um diretório existente, -1 se |x| for um arquivo existente e 0
caso contrário. Primeiro criamos as macros para não nos esquecermos do
que significa cada número de retorno:

@<Macros do Programa Weaver@>+=
#define NAO_EXISTE             0
#define EXISTE_E_EH_DIRETORIO  1
#define EXISTE_E_EH_ARQUIVO   -1
@

@<Funções auxiliares Weaver@>+=
int directory_exist(char *dir){
  struct stat s; // Armazena status se um diretório existe ou não.
  int err; // Checagem de erros
  err = stat(dir, &s); // .weaver existe?
  if(err == -1) return NAO_EXISTE;
  if(S_ISDIR(s.st_mode)) return EXISTE_E_EH_DIRETORIO;
  return EXISTE_E_EH_ARQUIVO;
}
@

A última função auxiliar da qual precisaremos é uma função para
concatenar strings. Ela deve receber um número arbitrário de srings
como argumento, mas a última string deve ser uma string vazia. E irá
retornar a concatenação de todas as strings passadas como argumento.

A função irá alocar sempre uma nova string, a qual deverá ser
desalocada antes do programa terminar. Como exemplo,
|concatenate("tes", " ", "te", "")| retorna |"tes te"|.

@<Funções auxiliares Weaver@>+=
char *concatenate(char *string, ...){
  va_list arguments;
  char *new_string, *current_string = string;
  size_t current_size = strlen(string) + 1;
  char *realloc_return;
  va_start(arguments, string);
  new_string = (char *) malloc(current_size);
  if(new_string == NULL) return NULL;
  strcpy(new_string, string); // Copia primeira string
  while(current_string[0] != '\0'){ // Pára quando copiamos o ""
    current_string = va_arg(arguments, char *);
    current_size += strlen(current_string);
    realloc_return = (char *) realloc(new_string, current_size);
    if(realloc_return == NULL){
      free(new_string);
      return NULL;
    }
    new_string = realloc_return;
    strcat(new_string, current_string); // Copia próxima string
  }
  return new_string;
}
@

É importante lembrarmos que a função |concatenate| sempre deve receber
como último argumento uma string vazia ou teremos um \italico{buffer
overflow}. Esta função também é perigosa e deve ser usada sempre
tomando-se este cuidado.

Por fim, podemos escrever agora o código de inicialização. Começamos
primeiro fazendo |complete_path| ser igual à \monoespaco{./.weaver/}:

@<Inicialização@>=
char *path = NULL, *complete_path = NULL;
path = getcwd(NULL, 0);
if(path == NULL) ERROR();
complete_path = concatenate(path, "/.weaver", "");
free(path);
if(complete_path == NULL) ERROR();
@

Agora iniciamos um loop que terminará quando |complete_path| for igual
à \monoespaco{/.weaver} (chegamos no fim da árvore de diretórios e não
encontramos nada) ou quando realmente existir o
diretório \monoespaco{.weaver/} no diretório examinado. E no fim do
loop, sempre vamos para o diretório-pai do qual estamos:

@<Inicialização@>+=
while(strcmp(complete_path, "/.weaver")){ // Testa se chegamos ao fim
  if(directory_exist(complete_path) == EXISTE_E_EH_DIRETORIO){
    inside_weaver_directory = true;
    complete_path[strlen(complete_path)-7] = '\0'; // Apaga o '.weaver'
    project_path = concatenate(complete_path, "");
    if(project_path == NULL){ free(complete_path); ERROR(); }
    break;
  }
  else{
    path_up(complete_path);
    strcat(complete_path, "/.weaver");
  }
}
free(complete_path);
@

Como alocamos memória para |project_path| armazenar o endereço do
projeto atual se estamos em um projeto Weaver, no final do programa
teremos que desalocar a memória:

@<Finalização@>=
if(project_path != NULL) free(project_path);

@*3 Inicializando variáveis \monoespaco{weaver\_version\_major} e
\quebra\monoespaco{weaver\_version\_minor}.

Para descobrirmos a versão atual do Weaver que temos, basta consultar
o valor presente na macro |VERSION|. Então, obtemos o número de versão
maior e menor que estão separados por um ponto (se existirem). Note
que se não houver um ponto no nome da versão, então ela é uma versão
de testes. Mesmo neste caso o código abaixo vai funcionar, pois a
função |atoi| iria retornar 0 nas duas invocações por encontrar
respectivamente uma string sem dígito algum e um fim de string sem
conteúdo:

@<Inicialização@>+=
{
  char *p = VERSION;
  while(*p != '.' && *p != '\0') p ++;
  if(*p == '.') p ++;
  weaver_version_major = atoi(VERSION);
  weaver_version_minor = atoi(p);
}


@*3 Inicializando variáveis \monoespaco{project\_version\_major} e
\quebra\monoespaco{project\_version\_minor}.

Se estamos dentro de um projeto Weaver, temos que inicializar
informação sobre qual versão do Weaver foi usada para atualizá-lo pela
última vez. Isso pode ser obtido lendo o arquivo
\italico{.weaver/version} localizado dentro do diretório Weaver. Se não
estamos em um diretório Weaver, não precisamos inicializar tais
valores. O número de versão maior e menor é separado por um ponto.

@<Inicialização@>+=
if(inside_weaver_directory){
  FILE *fp;
  char *p, version[10];
  char *file_path = concatenate(project_path, ".weaver/version", "");
  if(file_path == NULL) ERROR();
  fp = fopen(file_path, "r");
  free(file_path);
  if(fp == NULL) ERROR();
  p = fgets(version, 10, fp);
  if(p == NULL){ fclose(fp); ERROR(); }
  while(*p != '.' && *p != '\0') p ++;
  if(*p == '.') p ++;
  project_version_major = atoi(version);
  project_version_minor = atoi(p);
  fclose(fp);
}

@*3 Inicializando \monoespaco{have\_arg}, \monoespaco{argument} e
\monoespaco{argument2}.

Uma das variáveis mais fáceis e triviais de se inicializar. Basta
consultar |argc| e |argv|.

@<Inicialização@>+=
have_arg = (argc > 1);
if(have_arg) argument = argv[1];
if(argc > 2) argument2 = argv[2];
@

@*3 Inicializando \monoespaco{arg\_is\_path}.

Agora temos que verificar se no caso de termos um argumento, se ele é
um caminho para um projeto Weaver existente ou não. Para isso,
checamos se ao concatenarmos \monoespaco{/.weaver} no argumento
encontramos o caminho de um diretório existente ou não.

@<Inicialização@>+=
if(have_arg){
  char *buffer = concatenate(argument, "/.weaver", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) == EXISTE_E_EH_DIRETORIO){
    arg_is_path = 1;
  }
  free(buffer);
}

@*3 Inicializando \monoespaco{shared\_dir}.

A variável |shared_dir| deverá conter onde estão os arquivos
compartilhados da instalação de Weaver. Se existir a variável de
ambiente \monoespaco{WEAVER\_DIR}, este será o caminho. Caso contrário,
assumiremos o valor padrão de \monoespaco{/usr/share/weaver}.

@<Inicialização@>+=
{
  char *weaver_dir = getenv("WEAVER_DIR");
  if(weaver_dir == NULL){
    shared_dir = concatenate("/usr/share/weaver/", "");
    if(shared_dir == NULL) ERROR();
  }
  else{
    shared_dir = concatenate(weaver_dir, "");
    if(shared_dir == NULL) ERROR();
  }
}

@ E isso requer que tenhamos que no fim do programa desalocar a
memória alocada para |shared_dir|:

@<Finalização@>+=
if(shared_dir != NULL) free(shared_dir);

@*3 Inicializando \monoespaco{arg\_is\_valid\_project}.

A próxima questão que deve ser averiguada é se o que recebemos como
argumento, caso haja argumento, pode ser o nome de um projeto Weaver
válido ou não. Para isso, três condições precisam ser
satisfeitas:

1) O nome base do projeto deve ser formado somente por caracteres
alfanuméricos e underline (embora uma barra possa aparecer para passar
o caminho completo de um projeto).

2) Não pode existir um arquivo com o mesmo nome do projeto no local
indicado para a criação.

3) O projeto não pode ter o nome de nenhum arquivo que costuma ficar
no diretório base de um projeto Weaver (como ``Makefile''). Do
contrário, na hora da compilação comandos como ``\monoespaco{gcc
game.c -o Makefile}'' poderiam ser executados e sobrescreveriam
arquivos importantes.

Para isso, usamos o seguinte código:

@<Inicialização@>+=
if(have_arg && !arg_is_path){
  char *buffer;
  char *base = basename(argument);
  int size = strlen(base);
  int i;
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(base[i]) && base[i] != '_'){
      goto NOT_VALID;
    }
  }
  // Checando se arquivo existe:
  if(directory_exist(argument) != NAO_EXISTE){
    goto NOT_VALID;
  }
  // Checando se conflita com arquivos de compilação:
  buffer = concatenate(shared_dir, "project/", base, "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID;
  }
  free(buffer);
  arg_is_valid_project = true;
}
NOT_VALID:

@*3 Inicializando \monoespaco{arg\_is\_valid\_module}.

Checar se o argumento que recebemos pode ser um nome válido para um
módulo só faz sentido se estivermos dentro de um diretório Weaver e se
um argumento estiver sendo passado. Neste caso, o argumento é um nome
  válido se ele contiver apenas caracteres alfanuméricos, underline e se não
existir no projeto um arquivo \monoespaco{.c} ou \monoespaco{.h} em
\monoespaco{src/} que tenha o mesmo nome do argumento passado:

@<Inicialização@>+=
if(have_arg && inside_weaver_directory){
  char *buffer;
  int i, size;
  size = strlen(argument);
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(argument[i]) && argument[i] != '_'){
      goto NOT_VALID_MODULE;
    }
  }
  // Checando por conflito de nomes:
  buffer = concatenate(project_path, "src/", argument, ".c", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID_MODULE;
  }
  buffer[strlen(buffer) - 1] = 'h';
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID_MODULE;
  }
  free(buffer);
  arg_is_valid_module = true;
}
NOT_VALID_MODULE:

@*3 Inicializando \monoespaco{arg\_is\_valid\_plugin}.

Para que um argumento seja um nome válido para plugin, ele deve ser
composto só por caracteres alfanuméricos ou underline e não existir no
diretório
\monoespaco{plugin} um arquivo com a extensão \monoespaco{.c} de mesmo
nome. Também precisamos estar naturalmente, em um diretório Weaver.

@<Inicialização@>+=
if(argument2 != NULL && inside_weaver_directory){
  int i, size;
  char *buffer;
  size = strlen(argument2);
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(argument2[i]) && argument2[i] != '_'){
      goto NOT_VALID_PLUGIN;
    }
  }
  // Checando se já existe plugin com mesmo nome:
  buffer = concatenate(project_path, "plugins/", argument2, ".c", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID_PLUGIN;
  }
  free(buffer);
  arg_is_valid_plugin = true;
}
NOT_VALID_PLUGIN:
@

@*3 Inicializando \monoespaco{arg\_is\_valid\_function}.

Para que essa variável seja verdadeira, é preciso existir um segundo
argumento e ele deve ser formado somente por caracteres alfanuméricos
ou underline. Além disso, o primeiro caractere precisa ser uma letra e
ele não pode ter o mesmo nome de alguma palavra reservada em C.

@<Inicialização@>+=
if(argument2 != NULL && inside_weaver_directory && !strcmp(argument, "--loop")){
  int i, size;
  char *buffer;
  // Primeiro caractere não pode ser dígito
  if(isdigit(argument2[0]))
    goto NOT_VALID_FUNCTION;
  size = strlen(argument2);
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(argument2[i]) && argument2[i] != '_'){
      goto NOT_VALID_PLUGIN;
    }
  }
  // Checando se existem arquivos com o nome indicado:
  buffer = concatenate(project_path, "src/", argument2, ".c", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID_FUNCTION;
  }
  buffer[strlen(buffer)-1] = 'h';
  if(directory_exist(buffer) != NAO_EXISTE){
    free(buffer);
    goto NOT_VALID_FUNCTION;
  }
  free(buffer);
  // Checando se recebemos como argumento uma palavra reservada em C:
  if(!strcmp(argument2, "auto") || !strcmp(argument2, "break") ||
     !strcmp(argument2, "case") || !strcmp(argument2, "char") ||
     !strcmp(argument2, "const") || !strcmp(argument2, "continue") ||
     !strcmp(argument2, "default") || !strcmp(argument2, "do") ||
     !strcmp(argument2, "int") || !strcmp(argument2, "long") ||
     !strcmp(argument2, "register") || !strcmp(argument2, "return") ||
     !strcmp(argument2, "short") || !strcmp(argument2, "signed") ||
     !strcmp(argument2, "sizeof") || !strcmp(argument2, "static") ||
     !strcmp(argument2, "struct") || !strcmp(argument2, "switch") ||
     !strcmp(argument2, "typedef") || !strcmp(argument2, "union") ||
     !strcmp(argument2, "unsigned") || !strcmp(argument2, "void") ||
     !strcmp(argument2, "volatile") || !strcmp(argument2, "while") ||
     !strcmp(argument2, "double") || !strcmp(argument2, "else") ||
     !strcmp(argument2, "enum") || !strcmp(argument2, "extern") ||
     !strcmp(argument2, "float") || !strcmp(argument2, "for") ||
     !strcmp(argument2, "goto") || !strcmp(argument2, "if"))
    goto NOT_VALID_FUNCTION;
  arg_is_valid_function = true;
}
NOT_VALID_FUNCTION:
@

@*3 Inicializando \monoespaco{author\_name}.

A variável |author_name| deve conter o nome do usuário que está
invocando o programa. Esta informação é útil para gerar uma mensagem
de Copyright nos arquivos de código fonte de novos módulos.

Para obter o nome do usuário, começamos obtendo o seu UID. De posse
dele, obtemos todas as informações de login com um |getpwuid|. Se o
usuário tiver registrado um nome em \monoespaco{/etc/passwd}, obtemos tal
nome na estrutura retornada pela função. Caso contrário, assumiremos o
login como sendo o nome:

@<Inicialização@>+=
{
  struct passwd *login;
  int size;
  char *string_to_copy;
  login = getpwuid(getuid()); // Obtém dados de usuário
  if(login == NULL) ERROR();
  size = strlen(login -> pw_gecos);
  if(size > 0)
    string_to_copy = login -> pw_gecos;
  else
    string_to_copy = login -> pw_name;
  size = strlen(string_to_copy);
  author_name = (char *) malloc(size + 1);
  if(author_name == NULL) ERROR();
  strcpy(author_name, string_to_copy);
}
@

Depois, precisaremos desalocar a memória ocupada por |author_name|:

\quebra

@<Finalização@>+=
if(author_name != NULL) free(author_name);
@

@*3 Inicializando \monoespaco{project\_name}.

Só faz sendido falarmos no nome do projeto se estivermos dentro de um
projeto Weaver. Neste caso, o nome do projeto pode ser encontrado em
um dos arquivos do diretório base de tal projeto em
\monoespaco{.weaver/name}:

@<Inicialização@>+=
if(inside_weaver_directory){
  FILE *fp;
  char *c, *filename = concatenate(project_path, ".weaver/name", "");
  if(filename == NULL) ERROR();
  project_name = (char *) malloc(256);
  if(project_name == NULL){
    free(filename);
    ERROR();
  }
  fp = fopen(filename, "r");
  if(fp == NULL){
    free(filename);
    ERROR();
  }
  c = fgets(project_name, 256, fp);
  fclose(fp);
  free(filename);
  if(c == NULL) ERROR();
  project_name[strlen(project_name)-1] = '\0';
  project_name = realloc(project_name, strlen(project_name) + 1);
  if(project_name == NULL) ERROR();
}
@

Depois, precisaremos desalocar a memória ocupada por |project_name|:

@<Finalização@>+=
if(project_name != NULL) free(project_name);
@

@*3 Inicializando \monoespaco{year}.

O ano atual é trivial de descobrir usando a função |localtime|:

@<Inicialização@>+=
{
  time_t current_time;
  struct tm *date;
  time(&current_time);
  date = localtime(&current_time);
  year = date -> tm_year + 1900;
}
@

@*2 Caso de uso 1: Imprimir ajuda de criação de projeto.

O primeiro caso de uso sempre ocorre quando Weaver é invocado fora de
um diretório de projeto e a invocação é sem argumentos ou com
argumento \monoespaco{--help}. Nesse caso assumimos que o usuário não sabe
bem como usar o programa e imprimimos uma mensagem de ajuda. A mensagem
de ajuda terá uma forma semelhante a esta:

\alinhaverbatim
    .  .   You are outside a Weaver Directory.
   ./  \\.  The following command uses are available:
   \\\\  //
   \\\\()//  weaver
   .={}=.      Print this message and exits.
  / /`'\\ \\
  ` \\  / '  weaver PROJECT_NAME
     `'        Creates a new Weaver Directory with a new
               project.
\alinhanormal

O que é feito com o código abaixo:

@<Caso de uso 1: Imprimir ajuda de criação de projeto@>=
if(!inside_weaver_directory && (!have_arg || !strcmp(argument, "--help"))){
  printf("    .  .     You are outside a Weaver Directory.\n"
  "   .|  |.    The following command uses are available:\n"
  "   ||  ||\n"
  "   \\\\()//  weaver\n"
  "   .={}=.      Print this message and exits.\n"
  "  / /`'\\ \\\n"
  "  ` \\  / '  weaver PROJECT_NAME\n"
  "     `'        Creates a new Weaver Directory with a new\n"
  "                project.\n");
  END();
}

@*2 Caso de uso 2: Imprimir ajuda de gerenciamento.

O segundo caso de uso também é bastante simples. Ele é invocado quando
já estamos dentro de um projeto Weaver e invocamos Weaver sem
argumentos ou com um \monoespaco{--help}. Assumimos neste caso que o
usuário quer instruções sobre a criação de um novo módulo. A mensagem
que imprimiremos é semelhante à esta:

\alinhaverbatim
       \\              You are inside a Weaver Directory.
        \\______/      The following command uses are available:
        /\\____/\\
       / /\\__/\\ \\       weaver
    __/_/_/\\/\\_\\_\\___     Prints this message and exits.
      \\ \\ \\/\\/ / /
       \\ \\/__\\/ /       weaver NAME
        \\/____\\/          Creates NAME.c and NAME.h, updating
        /      \\          the Makefile and headers
       /
                          weaver --loop NAME
                           Creates a new main loop in a new file src/NAME.c

                          weaver --plugin NAME
                           Creates new plugin in plugin/NAME.c

                          weaver --shader NAME
                           Creates a new shader directory in shaders/
\alinhanormal

O que é obtido com o código:

@<Caso de uso 2: Imprimir ajuda de gerenciamento@>=
if(inside_weaver_directory && (!have_arg || !strcmp(argument, "--help"))){
  printf("       \\                You are inside a Weaver Directory.\n"
  "        \\______/        The following command uses are available:\n"
  "        /\\____/\\\n"
  "       / /\\__/\\ \\       weaver\n"
  "    __/_/_/\\/\\_\\_\\___     Prints this message and exits.\n"
  "      \\ \\ \\/\\/ / /\n"
  "       \\ \\/__\\/ /       weaver NAME\n"
  "        \\/____\\/          Creates NAME.c and NAME.h, updating\n"
  "        /      \\          the Makefile and headers\n"
  "       /\n"
  "                        weaver --loop NAME\n"
  "                         Creates a new main loop in a new file src/NAME.c\n\n"
  "                        weaver --plugin NAME\n"
  "                         Creates a new plugin in plugin/NAME.c\n\n"
  "                        weaver --shader NAME\n"
  "                         Creates a new shader directory in shaders/\n");
  END();
}

@*2 Caso de uso 3: Mostrar versão instalada de Weaver.

Um caso de uso ainda mais simples. Ocorrerá toda vez que o usuário
invocar Weaver com o argumento \monoespaco{--version}:

@<Caso de uso 3: Mostrar versão@>=
if(have_arg && !strcmp(argument, "--version")){
  printf("Weaver\t%s\n", VERSION);
  END();
}
@

@*2 Caso de Uso 4: Atualizar projetos Weaver já existentes.

Este caso de uso ocorre quando o usuário passar como argumento para
Weaver um caminho absoluto ou relativo para um diretório Weaver
existente. Assumimos então que ele deseja atualizar o projeto passado
como argumento. Talvez o projeto tenha sido feito com uma versão muito
antiga do motor e ele deseja que ele passe a usar uma versão mais
nova da API.

Naturalmente, isso só será feito caso a versão de Weaver instalada
seja superior à versão do projeto ou se a versão de Weaver instalada
for uma versão instável para testes. Entende-se neste caso que o
usuário deseja testar a versão experimental de Weaver no projeto. Fora
isso, não é possível fazer \italico{downgrades} de projetos, passando
da versão 0.2 para 0.1, por exemplo.

Versões experimentais sempre são identificadas como tendo um nome
formado somente por caracteres alfabéticos. Versões estáveis serão
sempre formadas por um ou mais dígitos, um ponto e um ou mais dígitos
(o número de versão maior e menor). Como o número de versão é
interpretado com um |atoi|, isso significa que se estamos usando uma
versão experimental, então o número de versão maior e menor serão
sempre identificados como zero.

Pela definição que fizemos até agora, isso significa também que
projetos em versões experimentais de Weaver sempre serão atualizados,
independente da versão ser mais antiga ou mais nova.

Uma atualização consiste em copiar todos os arquivos que estão no
diretório de arquivos compartilhados Weaver dentro de
\monoespaco{project/src/weaver} para o diretório \monoespaco{src/weaver} do
projeto em questão.

Mas para copiarmos os arquivos precisamos primeiro de uma função capaz
de copiar um único arquivo. A função |copy_single_file| tenta copiar o
arquivo cujo caminho é o primeiro argumento para o diretório cujo
caminho é o segundo argumento. Se ela conseguir, retorna 1 e retorna 0
caso contrário.

@<Funções auxiliares Weaver@>+=
int copy_single_file(char *file, char *directory){
  int block_size, bytes_read;
  char *buffer, *file_dst;
  FILE *orig, *dst;
  // Inicializa 'block_size':
  @<Descobre tamanho do bloco do sistema de arquivos@>
  buffer = (char *) malloc(block_size); // Aloca buffer de cópia
  if(buffer == NULL) return 0;
  file_dst = concatenate(directory, "/", basename(file), "");
  if(file_dst == NULL) return 0;
  orig = fopen(file, "r"); // Abre arquivo de origem
  if(orig == NULL){
    free(buffer);
    free(file_dst);
    return 0;
  }
  dst = fopen(file_dst, "w"); // Abre arquivo de destino
  if(dst == NULL){
    fclose(orig);
    free(buffer);
    free(file_dst);
    return 0;
  }
  while((bytes_read = fread(buffer, 1, block_size, orig)) > 0){
    fwrite(buffer, 1, bytes_read, dst); // Copia origem -> buffer -> destino
  }
  fclose(orig);
  fclose(dst);
  free(file_dst);
  free(buffer);
  return 1;
}
@

O mais eficiente é que o buffer usado para copiar arquivos tenha o
mesmo tamanho do bloco do sistema de arquivos. Para obter o valor
correto deste tamanho, usamos o seguinte trecho de código:

@<Descobre tamanho do bloco do sistema de arquivos@>=
{
  struct stat s;
  stat(directory, &s);
  block_size = s.st_blksize;
  if(block_size <= 0){
    block_size = 4096;
  }
}
@

De posse da função que copia um só arquivo, definimos uma função que
copia todo o conteúdo de um diretório para outro diretório:

@<Funções auxiliares Weaver@>+=
int copy_files(char *orig, char *dst){
  DIR *d = NULL;
  struct dirent *dir;
  d = opendir(orig);
  if(d){
    while((dir = readdir(d)) != NULL){ // Loop para ler cada arquivo
          char *file;
          file = concatenate(orig, "/", dir -> d_name, "");
          if(file == NULL){
            return 0;
          }
      #if (defined(__linux__) || defined(_BSD_SOURCE)) && defined(DT_DIR)@/
        // Se suportamos DT_DIR, não precisamos chamar a função 'stat':
        if(dir -> d_type == DT_DIR){
      #else
        struct stat s;
        int err;
        err = stat(file, &s);
        if(err == -1) return 0;
        if(S_ISDIR(s.st_mode)){
      #endif
        // Se concluirmos estar lidando com subdiretório via 'stat' ou 'DT_DIR':
          char *new_dst;
          new_dst = concatenate(dst, "/", dir -> d_name, "");
          if(new_dst == NULL){
            return 0;
          }
          if(strcmp(dir -> d_name, ".") && strcmp(dir -> d_name, "..")){
            if(directory_exist(new_dst) == NAO_EXISTE) mkdir(new_dst, 0755);
            if(copy_files(file, new_dst) == 0){
              free(new_dst);
              free(file);
              closedir(d);
              return 0; // Não fazemos nada para diretórios '.' e '..'
            }
          }
          free(new_dst);
        }
        else{
          // Se concluimos estar diante de um arquivo usual:
          if(copy_single_file(file, dst) == 0){
            free(file);
            closedir(d);
            return 0;
          }
        }
      free(file);
    } // Fim do loop para ler cada arquivo
    closedir(d);
  }
  return 1;
}
@

A função acima presumiu que o diretório de destino tem a mesma
estrutura de diretórios que a origem.

De posse de todas as funções podemos escrever o código do caso
de uso em que iremos realizar a atualização:

@<Caso de uso 4: Atualizar projeto Weaver@>=
if(arg_is_path){
  if((weaver_version_major == 0 && weaver_version_minor == 0) ||
     (weaver_version_major > project_version_major) ||
     (weaver_version_major == project_version_major &&
      weaver_version_minor > project_version_minor)){
    char *buffer, *buffer2;
    // |buffer| passa a valer  SHARED_DIR/project/src/weaver
    buffer = concatenate(shared_dir, "project/src/weaver/", "");
    if(buffer == NULL) ERROR();
    // |buffer2| passa a valer PROJECT_DIR/src/weaver/
    buffer2 = concatenate(argument, "/src/weaver/", "");
    if(buffer2 == NULL){
      free(buffer);
      ERROR();
    }
    if(copy_files(buffer, buffer2) == 0){
      free(buffer);
      free(buffer2);
      ERROR();
    }
    free(buffer);
    free(buffer2);
  }
  END();
}
@

@*2 Caso de Uso 5: Adicionando um módulo ao projeto Weaver.

Se estamos dentro de um diretório de projeto Weaver, e o programa
recebeu um argumento, então estamos inserindo um novo módulo no nosso
jogo. Se o argumento é um nome válido, podemos fazer isso. Caso
contrário,devemos imprimir uma mensagem de erro e sair.

Criar um módulo basicamente envolve:


a) Criar arquivos \monoespaco{.c} e \monoespaco{.h} base, deixando seus
nomes iguais ao nome do módulo criado.

b) Adicionar em ambos um código com copyright e licenciamento com o
nome do autor, do projeto e ano.

c) Adicionar no \monoespaco{.h} código de macro simples para evitar que
o cabeçalho seja inserido mais de uma vez e fazer com que o
\monoespaco{.c} inclua o \monoespaco{.h} dentro de si.

d) Fazer com que o \monoespaco{.h} gerado seja inserido
em \monoespaco{src/includes.h} e assim suas estruturas sejam
acessíveis de todos os outros módulos do jogo.

A parte de imprimir um código de copyright será feita usando a nova
função abaixo:

@<Funções auxiliares Weaver@>+=
void write_copyright(FILE *fp, char *author_name, char *project_name, int year){
  char license[] = "/*\nCopyright (c) %s, %d\n\nThis file is part of %s.\n\n%s\
 is free software: you can redistribute it and/or modify\nit under the terms of\
 the GNU Affero General Public License as published by\nthe Free Software\ 
 Foundation, either version 3 of the License, or\n(at your option) any later\
 version.\n\n\
%s is distributed in the hope that it will be useful,\nbut WITHOUT ANY\
  WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS\
  FOR A PARTICULAR PURPOSE.  See the\nGNU Affero General Public License for more\
  details.\n\nYou should have received a copy of the GNU Affero General Public License\
\nalong with %s. If not, see <http://www.gnu.org/licenses/>.\n*/\n\n";
  fprintf(fp, license, author_name, year, project_name, project_name,
          project_name, project_name);
}
@

Já o código de criação de novo módulo passa a ser:

@<Caso de uso 5: Criar novo módulo@>=
if(inside_weaver_directory && have_arg &&
   strcmp(argument, "--plugin") && strcmp(argument, "--shader") &&
   strcmp(argument, "--loop")){
  if(arg_is_valid_module){
    char *filename;
    FILE *fp;
    // Criando modulo.c
    filename = concatenate(project_path, "src/", argument, ".c", "");
    if(filename == NULL) ERROR();
    fp = fopen(filename, "w");
    if(fp == NULL){
      free(filename);
      ERROR();
    }
    write_copyright(fp, author_name, project_name, year);
    fprintf(fp, "#include \"%s.h\"", argument);
    fclose(fp);
    filename[strlen(filename)-1] = 'h'; // Criando modulo.h
    fp = fopen(filename, "w");
    if(fp == NULL){
      free(filename);
      ERROR();
    }
    write_copyright(fp, author_name, project_name, year);
    fprintf(fp, "#ifndef _%s_h_\n", argument);
    fprintf(fp, "#define _%s_h_\n\n#include \"weaver/weaver.h\"\n",
            argument);
    fprintf(fp, "#include \"includes.h\"\n\n#endif");
    fclose(fp);
    free(filename);

    // Atualizando src/includes.h para inserir modulo.h:
    fp = fopen("src/includes.h", "a");
    fprintf(fp, "#include \"%s.h\"\n", argument);
    fclose(fp);
  }
  else{
    fprintf(stderr, "ERROR: This module name is invalid.\n");
    return_value = 1;
  }
  END();
}
@

@*2 Caso de Uso 6: Criando um novo projeto Weaver.

Criar um novo projeto Weaver consiste em criar um novo diretório com o
nome do projeto, copiar para lá tudo o que está no diretório
\monoespaco{project} do diretório de arquivos compartilhados e criar um
diretório \monoespaco{.weaver} com os dados do projeto. Além disso,
criamos um \monoespaco{src/game.c} e \monoespaco{src/game.h} adicionando o
comentário de Copyright neles e copiando a estrutura básica dos
arquivos do diretório compartilhado \monoespaco{basefile.c} e
\monoespaco{basefile.h}. Também criamos um
\monoespaco{src/includes.h} que por hora estará vazio, mas será modificado
na criação de futuros módulos.

A permissão dos diretórios criados será \monoespaco{drwxr-xr-x} (|0755| em
octal).

@<Caso de uso 6: Criar novo projeto@>=
if(! inside_weaver_directory && have_arg){
  if(arg_is_valid_project){
    int err;
    char *dir_name;
    FILE *fp;
    err = mkdir(argument, S_IRWXU | S_IRWXG | S_IROTH);
    if(err == -1) ERROR();
    err = chdir(argument);
    if(err == -1) ERROR();
    mkdir(".weaver", 0755); mkdir("conf", 0755); mkdir("tex", 0755);
    mkdir("src", 0755); mkdir("src/weaver", 0755); mkdir ("fonts", 0755);
    mkdir("image", 0755); mkdir("sound", 0755); mkdir ("models", 0755);
    mkdir("music", 0755); mkdir("plugins", 0755); mkdir("src/misc/", 0755);
    mkdir("src/misc/sqlite", 0755); mkdir(".misc", 0755);
    mkdir("compiled_plugins", 0755);
    mkdir("shaders", 0755);
    dir_name = concatenate(shared_dir, "project", "");
    if(dir_name == NULL) ERROR();
    if(copy_files(dir_name, ".") == 0){
      free(dir_name);
      ERROR();
    }
    free(dir_name); //Criando arquivo com número de versão:
    fp = fopen(".weaver/version", "w");
    fprintf(fp, "%s\n", VERSION);
    fclose(fp); // Criando arquivo com nome de projeto:
    fp = fopen(".weaver/name", "w");
    fprintf(fp, "%s\n", basename(argv[1]));
    fclose(fp);
    fp = fopen("src/game.c", "w");
    if(fp == NULL) ERROR();
    write_copyright(fp, author_name, argument, year);
    if(append_basefile(fp, shared_dir, "basefile.c") == 0) ERROR();
    fclose(fp);
    fp = fopen("src/game.h", "w");
    if(fp == NULL) ERROR();
    write_copyright(fp, author_name, argument, year);
    if(append_basefile(fp, shared_dir, "basefile.h") == 0) ERROR();
    fclose(fp);
    fp = fopen("src/includes.h", "w");
    write_copyright(fp, author_name, argument, year);
    fprintf(fp, "\n#include \"weaver/weaver.h\"\n");
    fprintf(fp, "\n#include \"game.h\"\n");
    fclose(fp);
  }
  else{
    fprintf(stderr, "ERROR: %s is not a valid project name.", argument);
    return_value = 1;
  }
  END();
}
@

A única coisa ainda não-definida é a função usada acima
|append_basefile|. Esta é uma função bastante específica para
concatenar o conteúdo de um arquivo para o outro dentro deste trecho
de código. Não é uma função geral, pois ela recebe como argumento um
ponteiro para o arquivo de destino aberto e reebe como argumento o
diretório em que está a origem e o nome do arquivo de origem ao invés
de ter a forma mais intuitiva |cat(origem, destino)|.

Definimos abaixo a forma da |append_basefile|:

@<Funções auxiliares Weaver@>+=
int append_basefile(FILE *fp, char *dir, char *file){
  int block_size, bytes_read;
  char *buffer, *directory = ".";
  char *path = concatenate(dir, file, "");
  if(path == NULL) return 0;
  FILE *origin;
  @<Descobre tamanho do bloco do sistema de arquivos@>
  buffer = (char *) malloc(block_size);
  if(buffer == NULL){
    free(path);
    return 0;
  }
  origin = fopen(path, "r");
  if(origin == NULL){
    free(buffer);
    free(path);
    return 0;
  }
  while((bytes_read = fread(buffer, 1, block_size, origin)) > 0){
    fwrite(buffer, 1, bytes_read, fp);
  }
  fclose(origin);
  free(buffer);
  free(path);
  return 1;
}
@

E isso conclui todo o código do Programa Weaver. Todo o resto de
código que será apresentado à seguir, não pertence mais ao programa
Weaver, mas à Projetos Weaver e à API Weaver.

@*2 Caso de uso 7: Criar novo plugin.

Este aso de uso é invocado quando temos dois argumentos, o primeiro é
|"--plugin"| e o segundo é o nome de um novo plugin, o qual deve ser
um nome único, sem conflitar com qualquer outro dentro de
\monoespaco{plugins/}. Devemos estar em um diretório Weaver para fazer
isso.

@<Caso de uso 7: Criar novo plugin@>=
if(inside_weaver_directory && have_arg && !strcmp(argument, "--plugin") &&
   arg_is_valid_plugin){
  char *buffer;
  FILE *fp;
  /* Criando o arquivo: */
  buffer = concatenate("plugins/", argument2, ".c", "");
  if(buffer == NULL) ERROR();
  fp = fopen(buffer, "w");
  if(fp == NULL) ERROR();
  write_copyright(fp, author_name, project_name, year);
  fprintf(fp, "#include \"../src/weaver/weaver.h\"\n\n");
  fprintf(fp, "void _init_plugin_%s(W_PLUGIN){\n\n}\n\n", argument2);
  fprintf(fp, "void _fini_plugin_%s(W_PLUGIN){\n\n}\n\n", argument2);
  fprintf(fp, "void _run_plugin_%s(W_PLUGIN){\n\n}\n\n", argument2);
  fprintf(fp, "void _enable_plugin_%s(W_PLUGIN){\n\n}\n\n", argument2);
  fprintf(fp, "void _disable_plugin_%s(W_PLUGIN){\n\n}\n", argument2);
  fclose(fp);
  free(buffer);
  END();
}
@

@*2 Caso de uso 8: Criar novo shader.

Este caso de uso é similar ao anterior, mas possui algumas
diferenças. Todo shader que criamos na verdade é um diretório com dois
shaders: o de vértice e o de fragmento. O diretório precisa sempre ter
um nome no estilo \monoespaco{DD-XXXXXXX} onde \monoespaco{DD} é um
número de um ou mais dígitos que ao ser interpretado por um |atoi|
deve resultar em um número único, não usado pelos outros shaders
diferente de zero e de modo que todos os shaders possuam números
sequenciais: \monoespaco{1-primeiro\_shader}, \monoespaco{2-segundo\_shader},
$\ldots$

Depois do número do shader virá um traço e depois virá o seu nome para
ser facilmente identificado por humanos.

Então neste caso de uso, que será invocado somente quando o nosso
primeiro argumento for |"--shader"| e o segundo for um nome
qualquer. Não precisamos realmente forçar uma restrição nos nomes dos
shaders, pois sua convenção numérica garante que cada um terá um nome
único e não-conflitante.

O código deste caso de uso é então:"

@<Caso de uso 8: Criar novo shader@>=
if(inside_weaver_directory && have_arg && !strcmp(argument, "--shader") &&
   argument2 != NULL){
    FILE *fp;
    DIR *shader_dir;
    struct dirent *dp;
    int i, number, number_of_files = 0, err;
    char *buffer, *buffer2;
    bool *exists;
    // Primeiro vamos iterar dentro do diretório de shaders apenas
    // para contar o número de diretórios:
    shader_dir = opendir("shaders/");
    if(shader_dir == NULL)
        ERROR();
    while((dp = readdir(shader_dir)) != NULL){
        if(dp -> d_name == NULL) continue;
        if(dp -> d_name[0] == '.') continue;
        if(dp -> d_name[0] == '\0') continue;
        buffer = concatenate("shaders/", dp -> d_name, "");
        if(buffer == NULL) ERROR();
        if(directory_exist(buffer) != EXISTE_E_EH_DIRETORIO){
            free(buffer);
            continue;
        }
        free(buffer);
        number_of_files ++;
    }
    closedir(shader_dir);
    // Agora que sabemos o número de arquivos existentes, precisamos
    // de um número 1 unidade maior para conter todos os arquivos mais
    // o próximo. Alocamos um vetor booleano para indicar se o shader
    // cujo número corresponde à tal posição existe ou não.
    exists = (bool *) malloc(sizeof(bool) * number_of_files + 1);
    if(exists == NULL) ERROR();
    for(i = 0; i < number_of_files + 1; i ++)
        exists[i] = false;
    // Iteramos novamente sobre os arquivos para saber quais números
    // já estão preenchidos e assim saber qual deve ser o número do
    // próximo shader. Provavelmente será o último. Mas vamos
    // considerar a possibilidade de haver um shader 1, um shader 3 e
    // não existir um 2, por exemplo. Neste caso, buscaremos tapar os
    // buracos.
    shader_dir = opendir("shaders/");
    if(shader_dir == NULL)
        ERROR();
    while((dp = readdir(shader_dir)) != NULL){
        if(dp -> d_name == NULL) continue;
        if(dp -> d_name[0] == '.') continue;
        if(dp -> d_name[0] == '\0') continue;
        buffer = concatenate("shaders/", dp -> d_name, "");
        if(buffer == NULL) ERROR();
        if(directory_exist(buffer) != EXISTE_E_EH_DIRETORIO){
            free(buffer);
            continue;
        }
        free(buffer);
        number = atoi(dp -> d_name);
        exists[number - 1] = true;
    }
    closedir(shader_dir);
    for(i = 0; exists[i] && i < number_of_files + 1; i ++);
    if(i == number_of_files + 1){
        fprintf(stderr, "ERROR: Shader directory changed during execution.\n");
        ERROR();
    }
    number = i + 1; // Este é o número do novo shader
    // Criando diretório do shader:
    buffer = (char *) malloc(strlen("shaders/") +
                             number / 10 + 2 + strlen(argument2));
    if(buffer == NULL) ERROR();
    buffer[0] = '\0';
    sprintf(buffer, "shaders/%d-%s", number, argument2);
    err = mkdir(buffer, S_IRWXU | S_IRWXG | S_IROTH);
    if(err == -1) ERROR();
    // Escrevendo o shader de vértice:
    buffer2 = concatenate(buffer, "/vertex.glsl", "");
    if(buffer2 == NULL) ERROR();
    fp = fopen(buffer2, "w");
    if(fp == NULL){
        free(buffer);
        free(buffer2);
        ERROR();
    }
    fprintf(fp, "#version 100\n\n");
    fprintf(fp, "#if GL_FRAGMENT_PRECISION_HIGH == 1\n");
    fprintf(fp, "  precision highp float;\n  precision highp int;\n");
    fprintf(fp, "#else\n");
    fprintf(fp, "  precision mediump float;\n  precision mediump int;\n");
    fprintf(fp, "#endif\n");
    fprintf(fp, "  precision lowp sampler2D;\n  precision lowp samplerCube;\n");
    fprintf(fp, "\n\nattribute vec3 vertex_position;\n\n");
    fprintf(fp, "uniform vec4 object_color;\nuniform mat4 model_view_matrix;");
    fprintf(fp, "\nuniform float time;\nuniform vec2 object_size;\n");
    fprintf(fp, "uniform int integer;\n\n");
    fprintf(fp, "varying mediump vec2 texture_coordinate;\n\n");
    fprintf(fp, "void main(){\n  gl_Position = model_view_matrix * ");
    fprintf(fp, "vec4(vertex_position, 1.0);\n");
    fprintf(fp, "texture_coordinate = vec2(vertex_position[0] + 0.5, "
            "vertex_position[1] + 0.5);\n}\n");
    free(buffer2);
    fclose(fp);
    // Escrevendo o shader de fragmento:
    buffer2 = concatenate(buffer, "/fragment.glsl", "");
    if(buffer2 == NULL) ERROR();
    fp = fopen(buffer2, "w");
    if(fp == NULL){
        free(buffer);
        free(buffer2);
        ERROR();
    }
    fprintf(fp, "#version 100\n\n");
    fprintf(fp, "#if GL_FRAGMENT_PRECISION_HIGH == 1\n");
    fprintf(fp, "  precision highp float;\n  precision highp int;\n");
    fprintf(fp, "#else\n");
    fprintf(fp, "  precision mediump float;\n  precision mediump int;\n");
    fprintf(fp, "#endif\n");
    fprintf(fp, "  precision lowp sampler2D;\n  precision lowp samplerCube;\n");
    fprintf(fp, "\nuniform vec4 object_color;\n");
    fprintf(fp, "\nuniform float time;\nuniform vec2 object_size;\n");
    fprintf(fp, "uniform int integer;\n");
    fprintf(fp, "\nuniform sampler2D texture1;\n");
    fprintf(fp, "varying mediump vec2 texture_coordinate;\n\n");
    fprintf(fp, "void main(){\n  ");
    fprintf(fp, "vec4 texture = texture2D(texture1, texture_coordinate);\n");
    fprintf(fp, "  float final_alpha = texture.a + object_color.a * "
            "(1.0 - texture.a);\n");
    fprintf(fp, "  gl_FragData[0] = vec4((texture.a * texture.rgb +\n");
    fprintf(fp, "                         object_color.rgb * object_color.a *"
            "\n");
    fprintf(fp, "                         (1.0 - texture.a)) /");
    fprintf(fp, "                        final_alpha, final_alpha);\n}\n");
    // Finalizando
    free(buffer);
    free(buffer2);
    END();
}
@

@*2 Caso de uso 9: Criar novo loop principal.

Este caso de uso ocorre quando o segundo argumento é
\monoespaco{--loop} e quando o próximo argumento for um nome válido
para uma função. Se não for, imprimimos uma mensagem de erro para
avisar:

@<Caso de uso 9: Criar novo loop principal@>=
if(inside_weaver_directory && !strcmp(argument, "--loop")){
  if(!arg_is_valid_function){
    if(argument2 == NULL)
      fprintf(stderr, "ERROR: You should pass a name for your new loop.\n");
    else
      fprintf(stderr, "ERROR: %s not a valid loop name.\n", argument2);
    ERROR();
  }
  char *filename;
  FILE *fp;
  // Criando LOOP_NAME.c
  filename = concatenate(project_path, "src/", argument2, ".c", "");
  if(filename == NULL) ERROR();
  fp = fopen(filename, "w");
  if(fp == NULL){
    free(filename);
    ERROR();
  }
  write_copyright(fp, author_name, project_name, year);
  fprintf(fp, "#include \"%s.h\"\n\n", argument2);
  fprintf(fp, "MAIN_LOOP %s(void){\n", argument2);
  fprintf(fp, " LOOP_INIT:\n\n");
  fprintf(fp, " LOOP_BODY:\n");
  fprintf(fp, "  if(W.keyboard[W_ANY])\n");
  fprintf(fp, "    Wexit_loop();\n");
  fprintf(fp, " LOOP_END:\n");
  fprintf(fp, "  return;\n");
  fprintf(fp, "}\n");
  fclose(fp);
  // Criando LOOP_NAME.h
  filename[strlen(filename)-1] = 'h';
  fp = fopen(filename, "w");
  if(fp == NULL){
    free(filename);
    ERROR();
  }
  write_copyright(fp, author_name, project_name, year);
  fprintf(fp, "#ifndef _%s_h_\n", argument2);
  fprintf(fp, "#define _%s_h_\n#include \"weaver/weaver.h\"\n\n", argument2);
  fprintf(fp, "#include \"includes.h\"\n\n");
  fprintf(fp, "MAIN_LOOP %s(void);\n\n", argument2);
  fprintf(fp, "#endif\n");
  fclose(fp);
  free(filename);
  // Atualizando src/includes.h
  fp = fopen("src/includes.h", "a");
  fprintf(fp, "#include \"%s.h\"\n", argument2);
  fclose(fp);  
}
@

@*1 O arquivo \monoespaco{conf\.h}.

Em toda árvore de diretórios de um projeto Weaver, deve existir um
arquivo cabeçalho C chamado\monoespaco{conf/conf.h}. Este cabeçalho
será incluído em todos os outros arquivos de código do Weaver no
projeto e que permitirá que o comportamento da Engine seja modificado
naquele projeto específico.

O arquivo deverá ter as seguintes macros (dentre outras):

\macronome|W_DEBUG_LEVEL|: Indica o que deve ser impresso na saída padrão
 durante a execução. Seu valor pode ser:

\macrovalor|0|) Nenhuma mensagem de depuração é impressa durante a
execução do programa. Ideal para compilar a versão final de seu
jogo.

\macrovalor|1|) Mensagens de aviso que provavelmente indicam erros
são impressas durante a execução. Por exemplo, um vazamento de memória
foi detectado, um arquivo de textura não foi encontrado, etc.

\macrovalor|2|) Mensagens que talvez possam indicar erros ou problemas, mas que
 talvez sejam inofensivas são impressas.

\macrovalor|3|) Mensagens informativas com dados sobre a execução, mas que não
 representam problemas são impressas.

\macrovalor|4|) Código de teste adicional é executado apenas para garantir que
 condições que tornem o código incorreto não estão presentes. Use só
 se você está depurando ou desenvolvendo a própria API Weaver, não o
 projeto de um jogo que a usa.

\macronome|W_SOURCE|: Indica a linguagem que usaremos em nosso projeto. As
opções são:

\macrovalor|W_C|) Nosso projeto é um programa em C.

\macrovalor|W_CPP|) Nosso projeto é um programa em C++.

\macronome|W_TARGET|: Indica que tipo de formato deve ter o jogo de saída. As
opções são:

\macrovalor|W_ELF|) O jogo deverá rodar nativamente em Linux. Após a
compilação, deverá ser criado um arquivo executável que poderá ser
instalado com \monoespaco{make install}.

\macrovalor|W_WEB|) O jogo deverá executar em um navegador de
Internet. Após a compilação deverá ser criado um diretório
chamado \monoespaco{web} que conterá o jogo na forma de uma página
HTML com Javascript. Não faz sentido instalar um jogo assim. Ele
deverá ser copiado para algum servidor Web para que possa ser jogado
na Internet. Isso é feito usando Emscripten.

Opcionalmente as seguintes macros podem ser definidas também (dentre
outras):

\macronome|W_MULTITHREAD|: Se a macro for definida, Weaver é compilado com
suporte à múltiplas threads acionadas pelo usuário. Note que de
qualquer forma vai existir mais de uma thread rodando no programa para
que música e efeitos sonoros sejam tocados. Mas esta macro garante que
mutexes e código adicional sejam executados para que o desenvolvedor
possa executar qualquer função da API concorrentemente.

Ao longo das demais seções deste documento, outras macros que devem
estar presentes ou que são opcionais serão apresentadas. Mudar os seus
valores, adicionar ou removê-las é a forma de configurar o
funcionamento do Weaver.

Junto ao código-fonte de Weaver deve vir também um arquivo
\monoespaco{conf/conf.h} que apresenta todas as macros possíveis em um só
lugar. Apesar de ser formado por código C, tal arquivo não será
apresentado neste PDF, pois é importante que ele tenha comentários e
CWEB iria remover os comentários ao gerar o código C.

O modo pelo qual este arquivo é inserido em todos os outros cabeçalhos
de arquivos da API Weaver é:

@<Inclui Cabeçalho de Configuração@>=
#include "conf_begin.h"
#include "../../conf/conf.h"
#include "conf_end.h"
@

Note que haverão também cabeçalhos \monoespaco{conf\_begin.h} que
cuidarão de toda declaração de inicialização que forem necessárias. E
um \monoespaco{conf\_end.h} para tratar de qualquer pós-processamento
necessário. Para começar, criaremos o \monoespaco{conf\_begin.h} para
inicializar as macros |W_WEB| e |W_ELF|:

@(project/src/weaver/conf_begin.h@>=
#define W_ELF 0
#define W_WEB 1
@

E vamos começar usando o \monoespaco{conf\_end.h} para impedir que
suportemos threads se estivermos compilando para Emscripten, já que as
threads não funcionam neste ambiente. E também determinamos que se o
|W_DEBUG_LEVEL| não estiver definido, ele deve ser tratado como zero
como valor padrão. Criamos os valore padrão para as demais macros
também, mas algumas devem imprimir avisos se não estiverem presentes.

@(project/src/weaver/conf_end.h@>=
#ifndef W_DEBUG_LEVEL
#define W_DEBUG_LEVEL 0
#endif
#if W_TARGET == W_WEB && defined(W_MULTITHREAD)
#undef W_MULTITHREAD
#warning "Threads won't be used when compiling the game to a web browser."
#endif
#ifndef W_SOURCE
#warning "Not W_SOURCE defined at conf/conf.h. Assuming W_C (C)."
#define W_SOURCE W_C
#endif
#ifndef W_TARGET
#warning "Not W_TARGET defined at conf/conf.h. Assuming W_ELF (linux executable)."
#define W_TARGET W_ELF
#endif
@

@*1 Funções básicas Weaver.

E agora começaremos a definir o começo do código para a API Weaver.

Primeiro criamos um \monoespaco{weaver.h} que irá incluir
automaticamente todos os cabeçalhos Weaver necessários:

@(project/src/weaver/weaver.h@>=
#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
  extern "C" {
#endif
@<Inclui Cabeçalho de Configuração@>
#include <stdlib.h>
#include <stdbool.h>
#if W_TARGET == W_WEB
#include <emscripten.h>
#endif
@<Cabeçalhos Weaver@>
// Todas as variáveis e funções globais ficarão no struct abaixo:
@<Estrutura Global@>
@<Cabeçalhos Gerais Dependentes da Estrutura Global@>
@<Declaração de Cabeçalhos Finais@>
#ifdef __cplusplus
  }
#endif
#endif
@

Neste cabeçalho, iremos também declarar quatro funções.

A primeira função servirá para inicializar a API Weaver. Seus
parâmetros devem ser o nome do arquivo em que ela é invocada e o
número de linha. Esta informação será útil para imprimir mensagens de
erro úteis em caso de erro.

A segunda função deve ser a última coisa invocada no programa. Ela
encerra a API Weaver.

As duas outras funções são executadas dentro do loop principal. Uma
delas executará no mesmo ritmo da engine de física e a outra executará
durante a renderização do jogo na tela.

Nenhuma destas funções foi feita para ser chamada por mais de uma
thread. Todas elas só devem ser usadas pela thread principal. Mesmo
que você defina a macro |W_MULTITHREAD|, todas as outras funções serão
seguras para threads, menos estas três.

@<Cabeçalhos Weaver@>+=
void _awake_the_weaver(void);
void _may_the_weaver_sleep(void) __attribute__ ((noreturn));
void _update(void);
void _render(void);
#define Winit() _awake_the_weaver()
#define Wexit() _may_the_weaver_sleep()
@

Definiremos melhor a responsabilidade destas funções ao longo dos
demais capítulos. A única função que começaremos a definir já será a
função de renderização.

Ela limpa os buffers OpenGL (|glClear|),troca os buffers de desenho na
tela (|glXSwapBuffers|, somente se formos um programa executável, não
algo compilado para Javascript) e pede que todos os comandos OpenGL
pendentes sejam executados (|glFlush|).

@(project/src/weaver/weaver.c@>=
#include "weaver.h"
@<API Weaver: Definições@>
void _awake_the_weaver(void){
  @<API Weaver: Inicialização@>
  @<API Weaver: Últimas Inicializações@>
}
void _may_the_weaver_sleep(void){
  @<API Weaver: Finalização@>
  exit(0);
}

void _update(void){
  @<Código a executar todo loop@>
}

void _render(void){
  // Limpando todos os buffers.
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  @<Antes da Renderização@>
  // TODO: Renderizar os objetos que fazem parte do jogo
  @<Renderizar Interface@>
  @<Depois da Renderização@>
#if W_TARGET == W_ELF
  glXSwapBuffers(_dpy, _window);
#else
  glFlush();
#endif
}
@

Mas isso é só uma amostra inicial e uma inicialização dos
arquivos. Estas funções todas serão mais ricamente definidas a cada
capítulo à medida que definimos novas responsabilidades para o nosso
motor de jogo. Embora a estrutura do loop principal seja vista logo
mais.

@<API Weaver: Finalização@>=
  // A definir...
@

@*1 A estrutura \monoespaco{W}.

As funções que definimos acima são atípicas. A maioria das variáveis e
funções que criaremos ao longo do projeto não serão definidas
globalmente, mas serão atribuídas à uma estrutura. Na prática estamos
aplicando técnica de orientação à objetos, criando o Objeto ``Weaver
API'' e definindo seus próprios atributos e métodos ao invés de termos
que definir variáveis globais.

O objeto terá a forma:

@<Estrutura Global@>=
// Esta estrutura conterá todas as variáveis e funções definidas pela
// API Weaver:
extern struct _weaver_struct{
  @<Variáveis Weaver@>
  @<Funções Weaver@>
} W;
@

@<API Weaver: Definições@>=
struct _weaver_struct W;
@

A vantagem de fazermos isso é evitarmos a poluição do espaço de
nomes. Fazendo isso diminuimos muito a chance de existir algum
conflito entre o nome que damos a uma variável global e um nome
exportado por alguma biblioteca. As únicas funções com as quais não
nos preocuparemos serão aquelas que começam com um ``|_|'', pois elas
serão internas à API. Nenhum usuário deve criar funções que começam
com o ``|_|''.

Uma vantagem ainda maior de fazermos isso é que passamos a ser capazes
de passar a estrutura |W| para \italico{plugins}, que normalmente não
teriam como acessar coisas que estão como variáveis globais. Mas
os \italico{plugins} podem definir funções que recebem como argumento
|W| e assim eles podem ler informações e manipular a API.

@*1 O Tempo.

Como exemplo de variável útil que pode ser colocada na estrutura,
temos o tempo $t$. Usaremos como unidade de medida de tempo o
microsegundo ($10^{-6}$s). Quando nosso programa é inicializado, a
variável \monoespaco{W.t} será inicializada como zero. Depois, em cada
iteração de loop principal, será atualizada para o valor que
corresponde quantos microsegundos se passaram desde o começo do
programa. Sendo assim, precisamos saber também o tempo do sistema de
cada última iteração (que deve ficar em uma variável interna, que
portanto não irá para dentro de |W|) e cuidar com
\italico{overflows}. É preciso que \monoespaco{W.t} tenha pelo menos
32 bits e seja sem sinal para garantir que ele nunca irá sofrer
\italico{overflow}, a menos que ocorra o absurdo do programa se manter
em execução sem ser fechado por mais de dois anos.

Por fim, iremos armazenar também uma variável $dt$, a qual mede a
diferença de tempo entre uma iteração e outra do loop principal (do
ponto de vista da engine de física).

O nosso valor de tempo e o tempo de sistema medido ficarão nestas
variáveis:

@<Variáveis Weaver@>=
// Isso fica dentro da estrutura W:
unsigned long long t;
unsigned long dt;
@

@<Cabeçalhos Weaver@>=
struct timeval _last_time;
@

Ambas as variáveis são inicializadas assim:

@<API Weaver: Inicialização@>=
W.t = 0;
gettimeofday(&_last_time, NULL);
@

Elas terão seus valores atualizados em vários momentos como veremos
mais adiante. Mas para nos ajudar, projetaremos agora uma função para
atualizar o valor de \monoespaco{W.t} e que retorna o número de
microsegundos que se passaram desde a última vez que atualizamos a
variável:

@<Cabeçalhos Weaver@>+=
unsigned long _update_time(void);
@

@<API Weaver: Definições@>=
unsigned long _update_time(void){
  int nsec;
  unsigned long result;
  struct timeval _current_time;
  gettimeofday(&_current_time, NULL);
  // Aqui temos algo equivalente ao "vai um" do algoritmo da subtração:
  if(_current_time.tv_usec < _last_time.tv_usec){
    nsec = (_last_time.tv_usec - _current_time.tv_usec) / 1000000 + 1;
    _last_time.tv_usec -= 1000000 * nsec;
    _last_time.tv_sec += nsec;
  }
  if(_current_time.tv_usec - _last_time.tv_usec > 1000000){
    nsec = (_current_time.tv_usec - _last_time.tv_usec) / 1000000;
    _last_time.tv_usec += 1000000 * nsec;
    _last_time.tv_sec -= nsec;
  }
  if(_current_time.tv_sec < _last_time.tv_sec){
    // Overflow
    result = (_current_time.tv_sec - _last_time.tv_sec) * (-1000000);
    result += (_current_time.tv_usec - _last_time.tv_usec); // Sempre positivo
  }
  else{
    result = (_current_time.tv_sec - _last_time.tv_sec) * 1000000;
    result += (_current_time.tv_usec - _last_time.tv_usec);
  }
  _last_time.tv_sec = _current_time.tv_sec;
  _last_time.tv_usec = _current_time.tv_usec;
  return result;
}
@

@*1 As Variáveis do Jogo.

Todo projeto Weaver define uma estrutura localizada em
\monoespaco{src/game.h} que pode ter qualquer tipo de variáveis e
estruturas de dados características do jogo. O nome de tal estrutura é
sempre |_game|.

É importante que esta estrutura possa ser acessada de dentro da
estrutura |W|. Para isso, colocamos a seguinte declaração:

@<Cabeçalhos Weaver@>+=
extern struct _game_struct _game;
@

@<Variáveis Weaver@>=
// Isso fica dentro da estrutura W:
struct _game_struct *game;
@

@<API Weaver: Inicialização@>=
W.game = &_game;
@

@*1 Sumário das Variáveis e Funções da Introdução.

Terminaremos todo capítulo deste livro/programa com um sumário de
todas as funções e variáveis definidas ao longo do capítulo que
estejam disponíveis na API Weaver. As funções do programa Weaver, bem
como variáveis e funções estáticas serão omitidas. O sumário conterá
uma descrição rápida e poderá ter algum código adicional que possa ser
necessário para inicializá-lo e defini-lo.

\macronome Este capítulo apresentou 2 novas variáveis da API Weaver:

\macrovalor|W|: Uma estrutura que irá armazenar todas as variáveis
globais da API Weaver, bem como as suas funções globais. Exceto as
três outras funções definidas neste capítulo.

\macrovalor|W.t\/|: O tempo em microsegundos que se passou
desde que o programa se inicializou. Valor somente para leitura.

\macrovalor|W.dt|: O intervalo de tempo que passa entre uma iteração e
outra no loop principal.

\macronome Este capítulo apresentou 2 novas funções da API Weaver:

\macrovalor|void Winit(void)|: Inicializa a API Weaver. Deve ser a
primeira função invocada pelo programa antes de usar qualquer coisa da
API Weaver.

\macrovalor|void Wexit(void)|: Finaliza a API Weaver. Deve ser chamada
antes de encerrar o programa.
