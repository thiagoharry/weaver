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

Por exemplo, para produzir este PDF, utiliza-se um conjunto de
programas denominados de CWEB, a qual foi desenvolvida por Donald
Knuth e Silvio Levy. Um programa chamado CWEAVE é responsável por
gerar por meio do código-fonte do programa um código \MaGiTeX, o qual é
compilado para um formato DVI, e finalmente para este formato PDF
final. Para produzir o motor de desenvolvimento de jogos em si
utiliza-se sobre os mesmos arquivos fonte um programa chamado CTANGLE,
que extrai o código C (além de um punhado de códigos GLSL) para os
arquivos certos. Em seguida, utiliza-se um compilador como GCC ou
CLANG para produzir os executáveis. Felizmente, há \monoespaco{Makefiles}
para ajudar a cuidar de tais detalhes de construção.

Os pré-requisitos para se compreender este material são ter uma boa
base de programação em C e ter experiência no desenvolvimento de
programas em C para Linux. Alguma noção do funcionamento de OpenGL
também ajuda.

@*1 Copyright e licenciamento.

Weaver é desenvolvida pelo programador Thiago ``Harry'' Leucz
Astrizi. Abaixo segue a licença do software.

\alinhaverbatim
Copyright (c) Thiago Leucz Astrizi 2015

This program is free software: you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public
License along with this program.  If not, see
<http://www.gnu.org/licenses/>.
\alinhanormal

A tradução não-oficial da licença é:

\alinhaverbatim
Copyright (c) Thiago Leucz Astrizi 2015

Este programa é um software livre; você pode redistribuí-lo e/ou 
modificá-lo dentro dos termos da Licença Pública Geral GNU como 
publicada pela Fundação do Software Livre (FSF); na versão 3 da 
Licença, ou (na sua opinião) qualquer versão.

Este programa é distribuído na esperança de que possa ser útil, 
mas SEM NENHUMA GARANTIA; sem uma garantia implícita de ADEQUAÇÃO
a qualquer MERCADO ou APLICAÇÃO EM PARTICULAR. Veja a
Licença Pública Geral GNU para maiores detalhes.

Você deve ter recebido uma cópia da Licença Pública Geral GNU
junto com este programa. Se não, veja
<http://www.gnu.org/licenses/>.
\alinhanormal

A versão completa da licença pode ser obtida junto ao código-fonte
Weaver ou consultada no link mencionado.

@*1 Filosofia Weaver.

Estes são os princípios filosóficos que guiam o desenvolvimento deste
software. Qualqer coisa que vá de encontro à eles devem ser tratados
como \italico{bugs}.



\negrito{Software é conhecimento sobre como realizar algo escrito em
  linguagens formais de computadores. E o conhecimento deve ser livre
  para todos. Portanto, Weaver deverá ser um software livre e deverá
  também ser usada para a criação de jogos livres.}

A arte de um jogo pode ter direitos de cópia. Ela deveria ter uma
licença permisiva, pois arte é cultura, e portanto, também não deveria
ser algo a ser tirado das pessoas. Mas weaver não tem como impedi-lo
de licenciar a arte de um jogo da forma que for escolhida. Mas como
Weaver funciona injetando estaticamente seu código em seu jogo e
Weaver está sob a licença GPL, isso significa que seu jogo também
deverá estar sob esta mesma licença (ou alguma outra compatível).

Basicamente isso significa que você pode fazer quase qualquer coisa
que quiser com este software. Pode copiá-lo. Usar seu código-fonte
para fazer qualquer coisa que queira (assumindo as
responsabilidades). Passar para outras pessoas. Modificá-lo. A única
coisa não permitida é produzir com ele algo que não dê aos seus
usuários exatamente as mesmas liberdades.


\negrito{Como corolário da filosofia anterior, Weaver deve estar
  bem-documentado.}


A escolha de CWEB para a criação de Weaver é um reflexo desta
filosofia. Naturalmente, outra questão que surge é: documentado para
quem?

Estudei por anos demais em universidade pública e minha educação foi
paga com dinheiro do povo brasileiro. Por isso acho que minhas
contribuições devem ser pensadas sempre em como retribuir à isto. O
motivo de eu escrever em português neste manual é este. Mas ao mesmo
tempo quero que meu programa seja acessível ao mundo todo. Isso me
leva a escrever o site do projeto em inglês e dar prioridade para a
escrita de tutoriais em inglês lá. Os nomes das variáveis também serão
em inglês. Com isso tento conciliar as duas coisas, por mais difícil
que isso seja.


\negrito{Weaver deve ter muitas opções de configuração para que
  possa atender à diferentes necessidades.}


Cada projeto deve ter um arquivo de configuração e muito da
funcionalidade pode ser escolhida lá. Escolhas padrão sãs devem ser
escolhidas e estar lá, de modo que um projeto funcione bem mesmo que
seu autor não mude nada nas configurações. E concentrando
configurações em um arquivo, retiramos complexidade das funções. Que
Weaver nunca tenha funções abomináveis como a API do Windows, com 10
ou mais argumentos.

Como reflexo disso, faremos com que em todo projeto Weaver haja um
arquivo de configuração \monoespaco{conf/conf.h}, que modifica o
funcionamento do motor. Como pode ser deduzido pela extensão do nome
do arquivo, ele é basicamente um arquivo de cabeçalho C onde poderão
ter vários \monoespaco{\#define}s que modificarão o funcionamento de seu
jogo.


\negrito{Weaver não deve tentar resolver problemas sem solução. Ao
  invés disso, é melhor propor um acordo mútuo entre usuários.}


Computadores são coisas complexas primariamente porque pessoas tentam
resolver neles problemas insolúveis. É como tapar o sol com a
peneira. Você até consegue fazer isso. Junte um número suficientemente
grande de peneiras, coloque uma sobre a outra e você consegue gerar
uma sombra o quão escura se queira. Assim são os sistemas de
computador modernos.

Como exemplo de tais tentativas de solucionar problemas insolúveis,
que fazem com que arquiteturas monstruosas e ineficientes sejam
construídas temos a tentativa de fazer com que Sistemas Operacionais
proprietários sejam seguros e livres de vírus, garantir privacidade,
autenticação e segurança sobre HTTP e até mesmo coisas como o
gerenciamento de memória.

Quando um problema não tem uma solução satisfatória, isso jamais deve
ser escondido por meio de complexidades que tentam amenizar ou sufocar
o problema. Ao invés disso, a limitação natural da tarefa deve ficar
clara para o usuário, e deve-se trabalhar em algum tipo de
comportamento que deve ser seguido pela engine e pelo usuário para que
se possa lidar com o problema combinando os esforços de humanos e
máquinas.


\negrito{Um jogo feito usando Weaver deve poder ser instalado em
  um computador simplesmente distribuindo-se um instalador, sem
  necessidade de ir atrás de dependências.}


Isso está por trás da decisão do código da API Weaver ser inserido
estaticamente nos projetos ao invés de compilado como bibliotecas
compartilhadas. À rigor, este é um exemplo de problema insolúvel
mencionado anteriormente. Por causa disso, o acordo proposto é que
Weaver garanta que jogos possam ser instalados por meio de pacotes nas
2 distribuições Linux mais populares segundo o Distro Watch, sem a
instalação de pacotes adicionais, desde que as distribuições em si
suportem interfaces gráficas. Da parte do usuário, ele deverá usar uma
destas distribuições ou deverá concordar em instalar por conta própria
as dependências antes de instalar um jogo Weaver.

Naturalmente, caso alguma dependência esteja faltando, a mensagem de
erro na instalação deve ser tão clara como em qualquer outro pacote.

Ferramentas para gerar instaladores nas 2 distribuições mais usadas
devem ser fornecidas, desde que elas possuam gerenciador de pacotes.


\negrito{Wever deve ser fácil de usar. Mais fácil que a maioria
  das ferramentas já existentes.}


Isso é obtido mantendo as funções o mais simples possíveis e
fazendo-as funcionar seguindo padrões que são bons o bastante para a
maioria dos casos. E caso um programador saiba o que está fazendo, ele
deve poder configurar tais padrões sem problemas por meio do arquivo
\monoespaco{conf/conf.h}.

Desta forma, uma função de inicialização poderia se chamar
\monoespaco{Winit()} e não precisar de nenhum argumento. Coisas como
gerenciar a projeção das imagens na tela devem ser transparentes e nem
precisar de uma função específica após os objetos que compõe o nosso
ambiente 3D sejam definidos.

@*1 Instalando Weaver.

% Como Weaver ainda está em construção, isso deve ser mudado bastante.

Para instalar Weaver em um computador, assumindo que você está fazendo
isso à partir do código-fonte, basta usar o comando \monoespaco{make} e
\monoespaco{make install}.

Atualmente, os seguintes programas são necessários para se compilar
Weaver:


\negrito{ctangle:} Extrai o código C dos arquivos de
  \monoespaco{cweb/}.
\negrito{clang:} Um compilador C que gera executáveis à partir de
  código C. Pode-se usar o GCC (abaixo) ao invés dele.
\negrito{gcc:} Um compilador que gera executáveis à partir de
  código C. Pode-se usar o CLANG (acima) ao invés dele.
\negrito{make:} Interpreta e executa comandos do Makefile.


Adicionalmente, os seguintes programs são necessários para se gerar a
documentação:


\negrito{cweave:} Usado para gerar código \MaGiTeX\ usado para gerar
  este PDF.
\negrito{dvipdf:} Usado para converter um arquivo \monoespaco{.dvi} em
  um \monoespaco{.pdf}, que é o formato final deste manual. Dependendo da
  sua distribuição este programa vem em algum pacote com o nome
  \monoespaco{texlive}.
\negrito{graphviz:} Um conjunto de programas usado para gerar
  representações gráficas em diferentes formatos de estruturas como
  grafos.
\negrito{latex:} Usado para converter um arquivo \monoespaco{.tex} em
  um \monoespaco{.dvi}. Também costuma vir em pacotes chamados
  \monoespaco{texlive}.


Além disso, para que você possa efetivamente usar Weaver criando seus
próprios projetos, você também poderá precisar de:


\negrito{emscripten:} Isso é opcional. Mas é necessário caso você
  queira usar Weaver para construir jogos que possam ser jogados em
  navegadores Web após serem compilados para Javascript.
\negrito{opengl:} Você precisa de arquivos de desenvolvimento da
  biblioteca gráfica OpenGL caso queira gerar programas executáveis
  para Linux.
\negrito{xlib:} Você precisa dos arquivos de desenvolvimento Xlib
  caso você queira usar Weaver para gerar programas executáveis para
  Linux.
\negrito{xxd:} Um programa capaz de gerar representação
  hexadecimal de arquivos quaisquer. É necessário para inserir o
  código dos shaders no programa. Por motivos obscuros, algumas
  distribuições trazem este programa no mesmo pacote do \negrito{vim}.



@*1 O programa \monoespaco{weaver}.

Weaver é uma engine para desenvolvimento de jogos que na verdaade é
formada por várias coisas diferentes. Quando falamos em código do
Weaver, podemos estar nos referindo à código de algum dos programas
executáveis usados para se gerenciar a criação de seus jogos, podemos
estar nos referindo ao código da API Weaver que é inserida em cada um
de seus jogos ou então podemos estar nos referindo ao código de algum
de seus jogos.

Para evitar ambigüidades, quando nos referimos ao programa executável,
nos referiremos ao \negrito{programa Weaver}. Seu código-fonte pode ser
encontrado junto ao código da engine em si. O programa é usado
simplesmente para criar um novo projeto Weaver. E um projeto é um
diretório com vários arquivos e diretórios necessários para gerar um
novo jogo Weaver. Por exemplo, o comando abaixo cria um novo projeto
de um jogo chamado \monoespaco{pong}:

\alinhaverbatim
weaver pong
\alinhanormal

A árvore de diretórios exibida parcialmente abaixo é o que é criado
pelo comando acima (diretórios são retângulos e arquivos são
círculos):

%\noindent
%\includegraphics[width=\textwidth]{cweb/diagrams/project_dir.eps}

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
  significa mudar os arquivos com a API Weaver para ue reflitam
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


@*2 Variáveis do Programa Weaver.

O comportamento de Weaver deve depender das seguintes variáveis:


|inside_weaver_directory|: Indicará se o programa está sendo
  invocado de dentro de um projeto Weaver.
|argument|: O primeiro argumento, ou NULL se ele não existir
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
    have_arg = false; /* Variáveis booleanas. */
  unsigned int project_version_major = 0, project_version_minor = 0,
    weaver_version_major = 0, weaver_version_minor = 0,
    year = 0; /* Usa-se o inteiro mais simples para tais valores. O
		 padrão garante que o podemos representar até o número
		 65536 aqui. Provavelmente será o suficiente para toda
		 a história deste projeto.*/
  char *argument = NULL, *project_path = NULL, *shared_dir = NULL,
    *author_name = NULL, *project_name = NULL; /* Strings UTF-8 */

  @<Inicialização@>

  @<Caso de uso 1: Imprimir ajuda de criação de projeto@>
  @<Caso de uso 2: Imprimir ajuda de gerenciamento de projeto@>
  @<Caso de uso 3: Mostrar versão@>
  @<Caso de uso 4: Atualizar projeto Weaver@>
  @<Caso de uso 5: Criar novo módulo@>
  @<Caso de uso 6: Criar novo projeto@>

  finalize:
  @<Finalização@>

  return return_value;
}

@*2 Macros do Programa Weaver.

O programa precisará de algumas macros. A primeira delas deverá conter
uma string com a versão do programa. A versão pode ser formada só por
letras (no caso de versões de teste) ou por um número seguido de um
ponto e de outro número (sem espaços) no caso de uma versão final do
programa.

Para a segunda macro, observe que na estrutura geral do programa vista
acima existe um rótulo chamado |finalize| logo na parte de
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
#define ERROR() {perror(NULL); return_value = 1; goto finalize;}
#define END() goto finalize;


@*2 Cabeçalhos do Programa Weaver.

@<Cabeçalhos Incluídos no Programa Weaver@>=
#include <sys/types.h> // |stat|, |getuid|, |getpwuid|, |mkdir|
#include <sys/stat.h> // |stat|, |mkdir|
#include <stdbool.h> // |bool|, |true|, |false| 
#include <unistd.h> // |get_current_dir_name|, |getcwd|, |stat|, |chdir|, |getuid|
#include <string.h> // |strcmp|, |strcat|, |strcpy|, |strncmp|
#include <stdlib.h> // |free|, |exit|, |getenv|
#include <dirent.h> // |readdir|, |opendir|, |closedir|
#include <libgen.h> // |basename|
#include <stdarg.h> // |va_start|, |va_arg|
#include <stdio.h> // |printf|, |fprintf|, |fopen|, |fclose|, |fgets|, |fgetc|, |perror|
#include <ctype.h> // |isanum|
#include <time.h> // |localtime|, |time|
#include <pwd.h> // |getpwuid|


@*2 Inicialização e Finalização do Programa Weaver.

@*3 Inicializando \italico{inside\_weaver\_directory} e
\italico{project\_path}.

Inicializar Weaver significa inicializar as 14 variáveis que serão
usadas para definir o seu comportamento. A primeira delas é
|inside_weaver_directory|, que deve valer |false| se o programa foi
invocado de fora de um diretório de projeto Weaver e |true| caso
contrário.

Como definir se estamos em um diretório que pertence à um projeto
Weaver? Simples. São diretórios que contém dentro de si ou em um
diretório ancestral um diretório oculto chamado \monoespaco{.weaver}. Caso
encontremos este diretório oculto, também podemos aproveitar e ajustar
a variável |project_path| para apontar para o pai do
\monoespaco{.weaver}. Se não o encontrarmos, estaremos fora de um
diretório Weaver e não precisamos mudar nenhum valor das duas
variáveis.

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
  duas con\-di\-ções ocorrerem:
  
  |complete_path == "/.weaver"|: Neste caso não podemos subir
    mais na árvore de diretórios, pois estamos na raiz. Não
    encontramos um diretório \monoespaco{.weaver}. Isso significa que não
    estamos dentro de um projeto Weaver.
  |complete_path == ".weaver"|: Neste caso encontramos um diretório
    \monoespaco{.weaver} e descobrimos que estamos dentro de um projeto
    Weaver. Podemos então atualizar a variável |project_path|.
  


Para checar se o diretório \monoespaco{.weaver} existe, vamos assumir a
existência de uma função chamada |directry_exists(x)|, onde |x| é uma
string e tal função deve retornar 1 se |x| for um diretório existente,
-1 se |x| for um arquivo existente e 0 caso contrário. Para checarmos
os diretórios acima dos atuais, assumiremos que existe uma função
chamada |path_up(x)| que dada uma string |x|, apaga todos os
caracteres dela de trás pra frente até remover dois ``/''. Desta
forma, removemos em cada execução desta função o ``/.weaver'' presente
no fim de cada string e também subimos um diretório na hierarquia na
variável |complete_path|. O comportamento da função é indefinido se
não existirem dois ``/'' na string, mas cuidaremos para que isto nunca
aconteça no teste de finalização do loop.

Por fim, a tradução para a linguagem C da implementação que
propomos. Vamos assumir que existe uma função |concatenate|, que
recebe como argumento um número qualquer de strings como argumento,
sendo que a última delas deve ser vazia. A função retorna uma nova
string que é a concatenação delas, ou |NULL| se não é possível alocar
espaço para isso.

@<Inicialização@>=
char *path = NULL, *complete_path = NULL;
path = getcwd(NULL, 0);
if(path == NULL) ERROR();
complete_path = concatenate(path, "/.weaver", "");
if(complete_path == NULL){
  free(path);
  ERROR();
}
free(path);
// O |while| abaixo testa a Finalização 1:
while(strcmp(complete_path, "/.weaver")){
  // O |if| abaixo testa a Finalização 2:
  if(directory_exist(complete_path) == 1){
    inside_weaver_directory = true;
    complete_path[strlen(complete_path)-7] = '\0'; // Apaga o \monoespaco{.weaver}
    project_path = concatenate(complete_path, "");
    if(project_path == NULL){
      free(complete_path);
      ERROR();
    }
    break;
  }
  else{
    // Dentro deste |else| está a manutenção do loop
    path_up(complete_path);
    strcat(complete_path, "/.weaver");
  }
}
free(complete_path);
@

Isso significa que agora na finalização do projeto, temos que
desalocar a memória de |path|:

@<Finalização@>=
if(project_path != NULL) free(project_path);

@*3 Inicializando \italico{weaver\_version\_major} e
\italico{weaver\_version\_minor}.

Para descobrirmos a versão atual do Weaver que temos, basta consultar
o valor presente na macro |VERSION|. Então, obtemos o número de versão
maior e menor que estão separados por um ponto (se existirem). Note
que se não houver um ponto no nome da versão, então ela é uma versão
de testes. De qualquer forma o código abaixo vai funcionar, pois a
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


@*3 Inicializando \italico{project\_version\_major} e
\italico{project\_version\_minor}.

Se estamos dentro de um projeto Weaver, queremos saber qual foi a
versão do Weaver usada para criar o projeto, ou então para atualizá-lo
pela última vez. Isso pode ser obtido lendo o arquivo
\italico{.weaver/version} localizado dentro do diretório Weaver. Se não
estamos em um diretório Weaver, não precisamos inicializar tais
valores. O número de versão maior e menor é separado por um ponto. Tal
como em ``0.5''.

@<Inicialização@>+=
if(inside_weaver_directory){
  FILE *fp;
  char *p;
  char version[10];
  char *file_path = concatenate(project_path, ".weaver/version", "");
  if(file_path == NULL) ERROR();
  fp = fopen(file_path, "r");
  free(file_path);
  if(fp == NULL) ERROR();
  fgets(version, 10, fp);
  p = version;
  while(*p != '.' && *p != '\0') p ++;
  if(*p == '.') p ++;
  project_version_major = atoi(version);
  project_version_minor = atoi(p);
  fclose(fp);
}

@*3 Inicializando \italico{have\_arg} e \italico{argument}.

Uma das variáveis mais fáceis e triviais de se inicializar. Basta
consultar |argc| e |argv|.

@<Inicialização@>+=
have_arg = (argc > 1);
if(have_arg) argument = argv[1];

@*3 Inicializando \italico{arg\_is\_path}.

Agora temos que verificar se no caso de termos um argumento, se ele é
um caminho para um projeto Weaver existente ou não. Para isso,
checamos se ao concatenarmos \monoespaco{/.weaver} no argumento
encontramos o caminho de um diretório existente ou não.

@<Inicialização@>+=
if(have_arg){
  char *buffer = concatenate(argument, "/.weaver", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) == 1){
    arg_is_path = 1;
  }
  free(buffer);
}

@*3 Inicializando \italico{shared\_dir}.

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

@*3 Inicializando \italico{arg\_is\_valid\_project}.

A próxima questão que deve ser averiguada é se o que recebemos como
argumento, caso haja argumento pode ser o nome de um projeto Weaver
válido ou não. Para isso, três condições precisam ser
satisfeitas:


 O nome base do projeto deve ser formado somente por caracteres
  alfanuméricos (embora uma barra possa aparecer para passar o caminho
  completo de um projeto).
 Não pode existir um arquivo com o mesmo nome do projeto no local
  indicado para a criação.
 O projeto não pode ter o nome de nenhum arquivo que costuma
  ficar no diretório base de um projeto Weaver (como ``Makefile''). Do
  contrário, na hora da compilação comandos como ``\monoespaco{gcc game.c
    -o Makefile}'' poderiam ser executados e sobrescreveriam arquivos
  importantes.


Para isso, usamos o seguinte código:

@<Inicialização@>+=
if(have_arg && !arg_is_path){
  char *buffer;
  char *base = basename(argument);
  int size = strlen(base);
  int i;
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(base[i])){
      goto not_valid;
    }
  }
  // Checando se arquivo existe:
  if(directory_exist(argument) != 0){
    goto not_valid;
  }
  // Checando se conflita com arquivos de compilação:
  buffer = concatenate(shared_dir, "project/", base, "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != 0){
    free(buffer);
    goto not_valid;
  }
  free(buffer);
  arg_is_valid_project = 1;
}
not_valid:

@*3 Inicializando \italico{arg\_is\_valid\_module}.

Checar se o argumento que recebemos pode ser um nome válido para um
módulo só faz sentido se estivermos dentro de um diretório Weaver e se
um argumento estiver sendo passado. Neste caso, o argumento é um nome
válido se ele contiver apenas caracteres alfanuméricos e se não
existir no projeto um arquivo \monoespaco{.c} ou \monoespaco{.h} em
\monoespaco{src/} que tenha o mesmo nome do argumento passado:

@<Inicialização@>+=
if(have_arg && inside_weaver_directory){
  char *buffer;
  int i, size;
  size = strlen(argument);
  // Checando caracteres inválidos no nome:
  for(i = 0; i < size; i ++){
    if(!isalnum(argument[i])){
      goto not_valid_module;
    }    
  }
  // Checando por conflito de nomes:
  buffer = concatenate(project_path, "src/", argument, ".c", "");
  if(buffer == NULL) ERROR();
  if(directory_exist(buffer) != 0){
    free(buffer);
    goto not_valid_module;
  }
  buffer[strlen(buffer) - 1] = 'h';
  if(directory_exist(buffer) != 0){
    free(buffer);
    goto not_valid_module;
  }
  free(buffer);
  arg_is_valid_module = 1;
}
not_valid_module:

@*3 Inicializando \italico{author\_name}.

A variável |author_name| deve conter o nome do usuário que está
invocando o programa. Esta informação é útil para gerar uma mensagem
de Copyright nos arquivos de código fonte de novos módulos, os quais
serão criados e escritos pelo usuário da Engine.

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
  if(size > 0){
    string_to_copy = login -> pw_gecos;
  }
  else{
    string_to_copy = login -> pw_name;
  }
  size = strlen(string_to_copy);
  author_name = (char *) malloc(size + 1);
  if(author_name == NULL) ERROR();
  strcpy(author_name, string_to_copy);
}

@ Depois, precisaremos desalocar a memória ocupada por |author_name|:

@<Finalização@>+=
if(author_name != NULL) free(author_name);

@*3 Inicializando \italico{project\_name}.

Só faz sendido falarmos no nome do projeto se estivermos dentro de um
projeto Weaver. Neste caso, o nome do projeto pode ser encontrado em
um dos arquivos do diretório base de tal projeto em
\monoespaco{.weaver/name}:

@<Inicialização@>+=
if(inside_weaver_directory){
  FILE *fp;
  char *filename = concatenate(project_path, ".weaver/name", "");
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
  fgets(project_name, 256, fp);
  fclose(fp);
  free(filename);
  project_name[strlen(project_name)-1] = '\0';
  project_name = realloc(project_name, strlen(project_name) + 1);
  if(project_name == NULL) ERROR();
}

@ Depois, precisaremos desalocar a memória ocupada por |project_name|:

@<Finalização@>+=
if(project_name != NULL) free(project_name);


@*3 Inicializando \italico{year}.

O ano atual é trivial de descobrir usando a função |localtime|:

@<Inicialização@>+=
{
  time_t current_time;
  struct tm *date;

  time(&current_time);
  date = localtime(&current_time);
  year = date -> tm_year + 1900;
}

@*3 Função auxiliar: Checando se diretório ou arquivo existe.

Definiremos agora a função |directory_exist| para verificarmos se um
caminho de diretório passado como argumento existe ou não. Os valores
de retorno possíveis desta função serão:

[-1]: Arquivo existe, mas não é um diretório.
[0]: Diretório ou arquivo não existe.
[1]: Arquivo existe e é um diretório.

@<Funções auxiliares Weaver@>=
int directory_exist(char *dir){
  struct stat s; /* Armazena status se um diretório existe ou não. */
  int err; /* Checagem de erros */
  err = stat(dir, &s); // \monoespaco{.weaver} existe?
  if(err != -1){
    if(S_ISDIR(s.st_mode)){
      return 1;
    }
    else{
      return -1;
    }
  }
  return 0;
}

@*3 Função auxiliar: Apagando caracteres até apagar duas barras.

Esta função é usada mais para manipular o caminho para arquivos no
sistema de arquivos. Apagar a primeira barra é ficar só com o endereço
do diretório, não do arquivo indicado pelo caminho. Apaga a segunda
barra significa subir um nível na árvore de diretórios:

@<Funções auxiliares Weaver@>+=
void path_up(char *path){
  int erased = 0;
  char *p = path;
  while(*p != '\0') p ++;
  while(erased < 2 && p != path){
    p --;
    if(*p == '/') erased ++;
    *p = '\0';
  }
}

@*3 Função auxiliar: Concatenando strings.

Esta é uma das funções auxiliares mais usadas. El recebe um número
variável de argumentos, todos strings sendo que o último é a string
vazia. Então, ela aloca espaço para uma nova string e retorna um
ponteiro para ela, sendo que a nova string é a concatenação de todos
os argumentos. Se algo falhar, |NULL| é retornado:

@<Funções auxiliares Weaver@>+=
char *concatenate(char *string, ...){
  va_list arguments;
  char *new_string, *current_string = string;
  size_t current_size = strlen(string) + 1;
  char *realloc_return;
  va_start(arguments, string);
  
  new_string = (char *) malloc(current_size);
  if(new_string == NULL) return NULL;
  strcpy(new_string, string);

  while(current_string[0] != '\0'){
    current_string = va_arg(arguments, char *);
    current_size += strlen(current_string);
    realloc_return = (char *) realloc(new_string, current_size);
    if(realloc_return == NULL){
      free(new_string);
      return NULL;
    }
    new_string = realloc_return;
    strcat(new_string, current_string);
  }
  return new_string;
}

@*2 Caso de uso 1: Imprimir ajuda de criação de projeto.

O primeiro caso de uso sempre ocorre quando Weaver é invocado fora de
um diretório de projeto e a invocação é sem argumentos ou com
argumento \monoespaco{--help}. Nesse caso assumimos que o usuário não sabe
bem como usar o programa e imprimimos uma mensagem de ajuda. A mensagem
de ajuda terá uma forma semelhante a esta:

\alinhaverbatim
.    .  .   You are outside a Weaver Directory.
.   ./  \\.  The following command uses are available:
.   \\\\  //
.   \\\\()//  weaver
.   .={}=.      Print this message and exits.
.  / /`'\\ \\
.  ` \\  / '  weaver PROJECT_NAME
.     `'        Creates a new Weaver Directory with a new
.               project.
\alinhanormal

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

@*2 Caso de uso 2: Imprimir ajuda de gerenciamento de projeto.

O segundo caso de uso também é bastante simples. Ele é invocado quando
já estamos dentro de um projeto Weaver e invocamos Weaver sem
argumentos ou com um \monoespaco{--help}. Assumimos neste caso que o
usuário quer instruções sobre a criação de um novo módulo. A mensagem
que imprimiremos é semelhante à esta:

\alinhaverbatim
.       \              You are inside a Weaver Directory.
.        \______/      The following command uses are available:
.        /\____/\
.       / /\__/\ \       weaver
.    __/_/_/\/\_\_\___     Prints this message and exits.
.      \ \ \/\/ / /
.       \ \/__\/ /       weaver NAME
.        \/____\/          Creates NAME.c and NAME.h, updating
.        /      \          the Makefile and headers
.       /
\alinhanormal

@<Caso de uso 2: Imprimir ajuda de gerenciamento de projeto@>=
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
  "       /\n");
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


@*2 Caso de Uso 4: Atualizar projetos Weaver já existentes.

Este caso de uso ocorre quando o usuário passar como argumento para
Weaver um caminho absoluto ou relativo para um diretório Weaver
existente. Assumimos então que ele deseja atualizar o projeto passado
como argumento. Talvez o projeto tenha sido feito com uma versão muito
antiga do motor e ele deseja que ele passe a usar uma versão mais
nova da API.

Naturalmente, isso só será feito caso a versão de Weaver instalada
seja superior à versão do projeto ou se a versão de Weaver instalada
for uma versão instável para testes. Afinal, entende-se neste caso que
o usuário deseja testar a versão experimental de Weaver no
projeto. Fora isso, não é possível fazer \italico{downgrades} de
projetos, passando da versão 0.2 para 0.1, por exemplo.

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

Assumindo que exista uma função |copy_files(a, b)| que copia todos os
arquivos de |a| para |b|, definimos este caso de uso como:

@<Caso de uso 4: Atualizar projeto Weaver@>=
if(arg_is_path){
  if((weaver_version_major == 0 && weaver_version_minor == 0) ||
     (weaver_version_major > project_version_major) ||
     (weaver_version_major == project_version_major &&
      weaver_version_minor > project_version_minor)){
    char *buffer, *buffer2;
    // |buffer| passa a valer  SHARED\_DIR/project/src/weaver 
    buffer = concatenate(shared_dir, "project/src/weaver/", "");
    if(buffer == NULL) ERROR();
    // |buffer2| passa a valer PROJECT\_DIR/src/weaver/
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

@ Resta então definirmos a função |copy_files| que usaremos para
copiar arquivos. Mas antes dela iremos definir uma função usada para
copiar um único arquivo, a qual chamaremos de |copy_single_file|:

@<Funções auxiliares Weaver@>+=
int copy_single_file(char *file, char *directory){
  int block_size;
  char *buffer;
  char *file_dst;
  FILE *orig, *dst;
  int bytes_read;

  @<Descobre tamanho do bloco do sistema de arquivos@>
  
  /* Nesta parte, |block_size| já foi inicializado com o tamanho do
  bloco do sistema de arquivos. Isso tornará a cópia seguinte mais
  eficiente.*/

  buffer = (char *) malloc(block_size);
  if(buffer == NULL) return 0;
  file_dst = concatenate(directory, "/", basename(file), "");
  if(file_dst == NULL) return 0;

  orig = fopen(file, "r");
  if(orig == NULL){
    free(buffer);
    free(file_dst);
    return 0;
  }
  dst = fopen(file_dst, "w");
  if(dst == NULL){
    fclose(orig);
    free(buffer);
    free(file_dst);
    return 0;
  }
  
  while((bytes_read = fread(buffer, 1, block_size, orig)) > 0){
    fwrite(buffer, 1, bytes_read, dst);
  }
  
  fclose(orig);
  fclose(dst);
  free(file_dst);
  free(buffer);
  return 1;
}

@

Para finalizar a função de cópia, basta descobrirmos agora como obter
o valor do tamanho do bloco do sistema de arquivos usado. Para isso,
usamos novamente a função |stat| em qualquer arquivo ou diretório do
sistema de arquivos do destino. Isso funcionará em qualquer sistema
POSIX. No código abaixo, tomamos também o cuidado de preencher um
valor padrão para o caso de algo ter dado errado.

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

Já tendo a função que copia um único arquivo para um destino, podemos
escrever agora a função que percorre recursivamente um diretório de
origem entrando nos diretórios e percorrendo todos os arquivos para
copiá-los. Ela assume que o diretório de destino possui a mesma
estrutura de diretórios que o de origem e copia os arquivos para os
seus locais respectivos.

Pode-se notar que é muito mais fácil fazer a tarefa no Linux e
sistemas BSD, pois a informação do tipo de arquivo (se é um diretório,
por exemplo) pode ser obtida pelo próprio retorno da função
|readdir|. Em outros sistemas que não adotam o mesmo padrão, é
necessário chamar uma função |stat| adicional para obter a informação.

@<Funções auxiliares Weaver@>+=
int copy_files(char *orig, char *dst){
  DIR *d = NULL;
  struct dirent *dir;

  d = opendir(orig);
  if(d){
    while((dir = readdir(d)) != NULL){
          char *file;
          file = concatenate(orig, "/", dir -> d_name, "");
          if(file == NULL){
            return 0;
          }
      #if (defined(__linux__) || defined(_BSD_SOURCE)) && defined(DT_DIR)@/
        if(dir -> d_type == DT_DIR){@/
      #else
        struct stat s;
        int err;
        err = stat(file, &s);
	if(err == -1) return 0;
        if(S_ISDIR(s.st_mode)){@/
      #endif
          // Aqui executamos se nesta iteração devemos copiar um diretório
          char *new_dst;
          new_dst = concatenate(dst, "/", dir -> d_name, "");
          if(new_dst == NULL){
            return 0;
          }
          if(strcmp(dir -> d_name, ".") && strcmp(dir -> d_name, "..")){
            if(copy_files(file, new_dst) == 0){
              free(new_dst);
              free(file);
              closedir(d);
              return 0;
            }
          }
          free(new_dst);
        }
        else{
          // Aqui executamos se nesta iteração devemos copiar um arquivo
          if(copy_single_file(file, dst) == 0){
            free(file);
            closedir(d);
            return 0;
          }          
        }
      free(file);
    }
    closedir(d);
  }
  return 1;
}

@

@*2 Caso de Uso 5: Adicionando um módulo ao projeto Weaver.

Se estamos dentro de um diretório de projeto Weaver, e o programa
recebeu um argumento, então estamos inserindo um novo módulo no nosso
jogo. Se o argumento é um nome válido, podemos fazer isso. Caso
contrário,devemos imprimir uma mensagem de erro e sair.

Criar um módulo basicamente envolve:


 Criar arquivos \monoespaco{.c} e \monoespaco{.h} base, deixando seus
  nomes iguais ao nome do módulo criado.
 Adicionar em ambos um código com copyright e licenciamento com o
  nome do autor, do projeto e ano.
 Adicionar no \monoespaco{.h} código de macro simples para evitar que
  o cabeçalho seja inserido mais de uma vez e fazer com que o
  \monoespaco{.c} inclua o \monoespaco{.h} dentro de si.
 Fazer com que o \monoespaco{.h} gerado seja inserido em
  \monoespaco{src/includes.h} e assim suas estruturas sejam acessíveis de
  todos os outros módulos do jogo.


O código para isso, assumindo que exista a função |write_copyright|
para imprimir o comentário de copyright e licenciamento é:

\vfil

@<Caso de uso 5: Criar novo módulo@>=
if(inside_weaver_directory && have_arg){
  if(arg_is_valid_module){
    char *filename;
    FILE *fp;
    // Creating the \monoespaco{.c}:
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
    filename[strlen(filename)-1] = 'h'; // Creating the \monoespaco{.h}:
    fp = fopen(filename, "w");
    if(fp == NULL){
      free(filename);
      ERROR();
    }
    write_copyright(fp, author_name, project_name, year);
    fprintf(fp, "#ifndef _%s_h_\n", argument);
    fprintf(fp, "#define _%s_h_\n\n\n#endif", argument);
    fclose(fp);
    free(filename);

    // Updating \monoespaco{src/includes.h}:
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

@*3 Função Auxiliar: Imprimir código de copyright e licenciamento.

Para preencher o código de copyright tanto em novos módulos como no
\monoespaco{main.c} de novos projetos, podemos usar a função abaixo:

@<Funções auxiliares Weaver@>+=
void write_copyright(FILE *fp, char *author_name, char *project_name,
int year){
  char license[] = "/*\nCopyright (c) %s, %d\n\nThis file is part of %s.\n\n%s is free\
software: you can redistribute it and/or modify\nit under the terms of the GNU\
General Public License as published by\nthe Free Software Foundation, either\
version 3 of the License, or\n(at your option) any later version.\n\n%s is\
distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY;\
without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A\
PARTICULAR PURPOSE.  See the\nGNU General Public License for more details.\n\n\
You should have received a copy of the GNU General Public License\nalong with %s.\
If not, see <http://www.gnu.org/licenses/>.*/\n\n";
  fprintf(fp, license, author_name, year, project_name, project_name, project_name, project_name);
}

@*2 Caso de Uso 6: Criando um novo projeto Weaver.

Criar um novo projeto Weaver consiste em criar um novo diretório com o
nome do projeto, copiar para lá tudo o que está no diretório
\monoespaco{project} do diretório de arquivos compartilhados e criar um
diretório \monoespaco{.weaver} com os dados do projeto. Além disso,
criamos um \monoespaco{src/game.c} e \monoespaco{src/game.h} adicionando o
comentário de Copyright neles e copiando a estrutura básica dos
arquivos do diretório compartilhado \monoespaco{basefile.c} e
\monoespaco{basefile.h} (assumindo que existe a função |append_basefile|
que faça isso para nos ajudar). Também criamos um
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
    chdir(argument);
    mkdir(".weaver", 0755); mkdir("conf", 0755);
    mkdir("src", 0755); mkdir("src/weaver", 0755);
    mkdir("image", 0755);  mkdir("sound", 0755);
    mkdir("music", 0755);

    dir_name = concatenate(shared_dir, "project", "");
    if(dir_name == NULL) ERROR();
    if(copy_files(dir_name, ".") == 0){
      free(dir_name);
      ERROR();
    }
    free(dir_name);// \\Criando arquivo com número de versão:
    fp = fopen(".weaver/version", "w");
    fprintf(fp, "%s\n", VERSION);
    fclose(fp);// Criando arquivo com nome de projeto:
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
    fclose(fp);
  }
  else{
    fprintf(stderr, "ERROR: %s is not a valid project name.", argument);
    return_value = 1;
  }
  END();
}

@*3 Função Auxiliar: Adicionando em arquivo aberto conteúdo de arquivo.

A função |append_basefile| deve receber 3 argumentos. Um ponteiro para
arquivo aberto, um endereço absoluto de diretório e um nome de
arquivo. Ela cuidará da parte de concatenar o nomed e diretório com o
de arquivo gerando um endereço absoluto de arquivo, abrirá tal arquivo
e escreverá no ponteiro para arquivo todo o conteúdo que houver. Se
houver algum erro, ela retorna 0. Caso contrário, retorna 1.

@<Funções auxiliares Weaver@>+=
int append_basefile(FILE *fp, char *dir, char *file){
  int block_size, bytes_read;
  char *buffer, *directory = ".";
  char *path = concatenate(dir, file, "");
  if(path == NULL) return 0;
  FILE *origin;

  @<Descobre tamanho do bloco do sistema de arquivos@>@/

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

@*1 O arquivo \monoespaco{conf.h}.

Em toda árvore de diretórios de um projeto Weaver, deve existir um
arquivo chamado \monoespaco{conf/conf.h}. Este arquivo é um arquivo de
cabeçalho C que será incluído em todos os outros arquivos de código do
Weaver no projeto e que permitirá que o comportamento da Engine seja
modificado naquele projeto específico.

O arquivo deverá ter as seguintes macros (dentre outras):


|W_DEBUG_LEVEL|: Indica o que deve ser impresso na saída padrão
  durante a execução. Seu valor pode ser:


|0|: Nenhuma mensagem de depuração é impressa durante a execução
  do programa. Ideal para compilar a versão final de seu jogo.
|1|: Mensagens de aviso que provavelmente indicam erros são
  impressas durante a execução. Por exemplo, um vazamento de memória
  foi detectado, um arquivo de textura não foi encontrado, etc.
|2|: Mensagens que talvez possam indicar erros ou problemas, mas
  que talvez sejam inofensivas são impressas.
|3|: Mensagens informativas com dados sobre a execução, mas que
  não representam problemas são impressas.

|W_SOURCE|: Indica a linguagem que usaremos em nosso projeto. As
  opções são:
  
    |W_C|: Nosso projeto é um programa em C.
    |W_CPP|: Nosso projeto é um programa em C++.
  
|W_TARGET|: Indica que tipo de formato deve ter o jogo de
  saída. As opções são:
  
    |W_ELF|: O jogo deverá rodar nativamente em Linux. Após a
      compilação, deverá ser criado um arquivo executável que poderá
      ser instalado com \monoespaco{make install}.
    |W_WEB|: O jogo deverá executar em um navegador de
      Internet. Após a compilação deverá ser criado um diretório
      chamado \monoespaco{web} que conterá o jogo na forma de uma página
      HTML com Javascript. Não faz sentido instalar um jogo assim. Ele
      deverá ser copiado para algum servidor Web para que possa ser
      jogado na Internet. Isso é feito usando Emscripten.
  


Opcionalmente as seguintes macros podem ser definidas também (dentre
outras):


  |W_MULTITHREAD|: Se a macro for definida, Weaver é compilado com
    suporte à múltiplas threads acionadas pelo usuário. Note que de
    qualquer forma vai existir mais de uma thread rodando no programa
    para que música e efeitos sonoros sejam tocados. Mas esta macro
    garante que mutexes e código adicional sejam executados para que o
    desenvolvedor possa executar qualquer função da API
    concorrentemente.


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

@

Note que haverão também cabeçalhos \monoespaco{conf\_begin.h} que cuidarão
de toda declaração de inicialização que forem necessárias. Para
começar, criaremos o \monoespaco{conf\_begin.h} para inicializar as macros
|W_WEB| e |W_ELF|:

@(project/src/weaver/conf_begin.h@>=
#define W_ELF 0
#define W_WEB 1

@*1 Funções básicas Weaver.

Vamos criar também um \monoespaco{weaver.h} que irá incluir
automaticamente todos os cabeçalhos Weaver necessários (inclusivve
este):

@(project/src/weaver/weaver.h@>=
#ifndef _weaver_h_
#define _weaver_h_
#ifdef __cplusplus
  extern "C" {
#endif
@<Inclui Cabeçalho de Configuração@>
@<Cabeçalhos Weaver@>
#ifdef __cplusplus
  }
#endif
#endif

@

Neste cabeçalho, iremos também declarar três funções. 

A primeira função servirá para inicializar a API Weaver. Seus
parâmetros devem ser o nome do arquivo em que ela é invocada e o
número de linha. Esta informação será útil para imprimir mensagens de
erro úteis em caso de erro.

A segunda função deve ser a última coisa invocada no programa. Ela
encerra a API Weaver.

E a terceira função deve ser chamada no loop principal do programa e
será responsável pro fazer coisas como desenhar na tela, ficar um
tempo ociosa para não consumir 100\% da CPU e coisas assim. O seu
argumento representa quantos milissegundos devemos ficar nela sem
fazer nada para evitar consumo de todo o tempo de CPU.

Nenhuma destas funções foi feita para ser chamada por mais de uma
thread. Todas elas só devem ser usadas pela thread principal. Mesmo
que você defina a macro |W_MULTITHREAD|, todas as outras funções serão
seguras para threads, menos estas três.

Como não é razoável pedir para que um programador se preocupar com
detalhes como o arquivo e linha de execução da função, abaixo das três
funções definiremos funções de macro que tornarão tais informações
transparentes e de responsabilidade do compilador. As três funções de
macro são como as três funções serão executadas na prática.

@<Cabeçalhos Weaver@>+=
void _awake_the_weaver(char *filename, unsigned long line);
void _may_the_weaver_sleep();
void _weaver_rest(unsigned long time);

#define Winit() _awake_the_weaver(__FILE__, __LINE__)
#define Wexit() _may_the_weaver_sleep()
#define Wrest(a) _weaver_rest(a)
@ 

Definiremos melhor a responsabilidade destas funções ao longo dos
demais capítulos. Mas colocaremos aqui a definição delas no arquivo
adequado. E no caso da função |_weaver_rest|, colocaremos aqui algum
código mínimo que faz todos os buffers usados para desenho OpenGL
devem ser limpos em cada frame de jogo (|glClear|) e que se nosso jogo
é um programa executável Linux, então precisamos usar |nanosleep| para
liberar a CPU um pouco (caso o jogo seja compilado para Javascript,
isso ocorre usando um mecanismo diferente, então não é necessário
especificar isso todo frame). Além disso, caso o jogo seja um programa
nativo, nós usamos \italico{double buffering}, e por isso precisamos do
|glXSwapBuffers| ao invés de um mais simples |glFlush|.

@(project/src/weaver/weaver.c@>=
#include "weaver.h"

@<API Weaver: Definições@>

void _awake_the_weaver(char *filename, unsigned long line){@/
  @<API Weaver: Inicialização@>
}

void _may_the_weaver_sleep(void){@/
  @<API Weaver: Finalização@>
  exit(0);
}

void _weaver_rest(unsigned long time){
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
#if W_TARGET == W_ELF
  struct timespec req = {0, time * 1000000};
#endif
  @<API Weaver: Loop Principal@>@/
#if W_TARGET == W_ELF
  glXSwapBuffers(_dpy, _window);
#else
  glFlush();
#endif
#if W_TARGET == W_ELF
  nanosleep(&req, NULL);
#endif
}
@
@<API Weaver: Loop Principal@>=
  // A definir...
