
@* Gerenciamento de memória.

Alocar memória dinamicamente de uma heap é uma operação cujo tempo
gasto nem sempre pode ser previsto. Isso é algo que depende da
quantidade de blocos contínuos de memória presentes na heap que o
gerenciador organiza. Por sua vez, isso depende muito do padrão de uso
das funções \texttt{malloc} e \texttt{free}, e por isso não é algo
fácil de ser previsto.

Jogos de computador tradicionalmente evitam o uso contínuo de
\texttt{malloc} e \texttt{free} por causa disso. Tipicamente jogos
programados para ter um alto desempenho alocam toda (ou a maior parte)
da memória de que vão precisar logo no início da execução gerando um
\textit{pool} de memória e gerenciando ele ao longo da execução. De
fato, esta preocupação direta com a memória é o principal motivo de
linguagens sem \textit{garbage collectors} como C++ serem tão
preferidas no desenvolvimento de grandes jogos comerciais.

O gerenciador de memória do Weaver, com o objetivo de permitir que um
programador tenha um controle sobre a quantidade máxima de memória que
será usada, espera que a quantidade máxima sempre seja declarada
previamente. E toda a memória é preparada e alocada durante a
inicialização do programa. Caso tente-se alocar mais memória do que o
disponível desta forma, uma mensagem de erro será impressa na saída de
erro para avisar o que está acontecendo ao programador. Desta forma é
difícil deixar passar vazamentos de memória e pode-se estabelecer mais
facilmente se o jogo está dentro dos requisitos de sistema esperados.

Weaver de fato aloca mais de uma região contínua de memória onde
pode-se alocar coisas. Uma das regiões contínuas será alocada e usada
pela própria API Weaver à medida que for necessário. A segunda região
de memória contínua, cujo tamanho deve ser declarada em
\texttt{conf/conf.h} é a região dedicada para que o usuário possa
alocar por meio de |Walloc| (que funciona como o |malloc|). Além
disso, o usuário deve poder criar novas regiões contínuas de
memória. O nome que tais regiões recebem é \textbf{arena}.

Além de um |Walloc|, também existe um |Wfree|. Entretanto, o jeito
recomendável de desalocar na maioria das vezes é usando uma outra
função chamada |Wtrash|. Para explicar a ideia de seu funcionamento,
repare que tipicamente um jogo funciona como uma máquina de estados
onde mudamos várias vezes de estado. Por exemplo, em um jogo de RPG
clássico como Final Fantasy, podemos encontrar os seguintes estados:

\noindent
\includegraphics[width=\textwidth]{cweb/diagrams/estados.eps}

E cada um dos estados pode também ter os seus próprios
sub-estados. Por exemplo, o estado ``Jogo'' seria formado pela
seguinte máquina de estados interna:

\noindent
\includegraphics[width=\textwidth]{cweb/diagrams/estados2.eps}

Cada estado precisará fazer as suas próprias alocações de
memória. Algumas vezes, ao passar de um estado pro outro, não
precisamos lembrar do quê havia no estado anterior. Por exemplo,
quando passamos da tela inicial para o jogo em si, não precisamos mais
manter na memória a imagem de fundo da tela inicial. Outras vezes,
podemos precisar memorizar coisas.  Se estamos andando pelo mundo e
somos atacados por monstros, passamos para o estado de combate. Mas
uma vez que os monstros sejam derrotados, devemos voltar ao estado
anterior, sem esquecer de informações como as coordenadas em que
estávamos. Mas quando formos esquecer um estado, iremos querer sempre
desalocar toda a memória relacionada à ele.

Por causa disso, um jogo pode ter um gerenciador de memória que
funcione como uma pilha. Primeiro alocamos dados globais que serão
úteis ao longo de todo o jogo. Todos estes dados só serão desalocados
ao término do jogo. Em seguida, podemos criar um \textbf{breakpoint} e
alocamos todos os dados referentes à tela inicial. Quando passarmos da
tela inicial para o jogo em si, podemos desalocar de uma vez tudo o
que foi alocado desde o último \textit{breakpoint} e removê-lo. Ao
entrar no jogo em si, criamos um novo \textit{breakpoint} e alocamos
tudo o que precisamos. Se entramos em tela de combate, criamos outro
\textit{breakpoint} (sem desalocar nada e sem remover o
\textit{breakpoint} anterior) e alocamos os dados referentes à
batalha. Depois que ela termina, desalocamos tudo até o último
\textit{breakpoint} para apagarmos os dados relacionados ao combate e
voltamos assim ao estado anterior de caminhar pelo mundo. Ao longo
destes passos, nossa memória terá aproximadamente a seguinte
estrutura:

\begin{verbatim}
.                                                    +---------+
.                                                    ; Combate ;
.           +--------------+             +---------+ +---------;
.           ; Tela Inicial ;             ;  Jogo   ; ;  Jogo   ;
+---------+ +--------------+ +---------+ +---------+ +---------+
; Globais ; ;    Globais   ; ; Globais ; ; Globais ; ; Globais ;
+---------+ +--------------+ +---------+ +---------+ +---------+
\end{verbatim}

Sendo assim, nosso gerenciador de memória torna-se capaz de evitar
completamente fragmentação tratando a memória alocada na heap como uma
pilha. O desenvolvedor só precisa desalocar a memória na ordem inversa
da alocação (se não o fizer, então haverá fragmentação). Entretanto, a
desalocação pode ser um processo totalmente automatizado. Toda vez que
encerramos um estado, podemos ter uma função que desaloca tudo o que
foi alocado até o último \textit{breakpoint} na ordem correta e
elimina aquele \textit{breakpoint} (exceto o último na base da pilha
que não pode ser eliminado). Fazendo isso, o gerenciamento de memória
fica mais simples de ser usado, pois o próprio gerenciador poderá
desalocar tudo que for necessário, sem esquecer e sem deixar
vazamentos de memória. O que a função |Wtrash| faz então é desalocar
na ordem certa toda a memória alocada até o último \textit{breakpoint}
e destrói o \textit{breakpoint} (exceto o primeiro que nunca é
removido). Para criar um novo \textit{breakpoint}, usamos a função
|Wbreakpoint|.

Tudo isso sempre é feito na arena padrão. Mas pode-se criar uma nova
arena (|Wcreate_arena|) bem como destruir uma arena
(|Wdestroy_arena|). E pode-se então alocar memória na arena
personalizada criada (|Walloc_arena|) e desalocar (|Wfree_arena|). Da
mesmo forma, pode-se também criar um \textit{breakpoint} na arena
personalizada (|Wbreakpoint_arena|) e descartar tudo que foi alocado
nela até o último \textit{breakpoint} (|Wtrash_arena|).

Para garantir a inclusão da definição de todas estas funções e
estruturas, usamos o seguinte código:

@<Cabeçalhos Weaver@>=
#include "memory.h"

@ E também criamos o cabeçalho de memória. À partir de agora, cada
novo módulo de Weaver terá um nome associado à ele. O deste é
``Memória''. E todo cabeçalho \texttt{.h} dele conterá, além das
macros comuns para impedir que ele seja inserido mais de uma vez e
para que ele possa ser usado em C++, uma parte na qual será inserido o
cabeçalho de configuração (visto no fim do capítulo anterior) e a
parte de declarações, com o nome \texttt{Declarações de
  NOME\_DO\_MODULO}.

@(project/src/weaver/memory.h@>=
#ifndef _memory_h_
#define _memory_h_
#ifdef __cplusplus
  extern "C" {
#endif@;
@<Inclui Cabeçalho de Configuração@>@;
@<Declarações de Memória@>@;
#ifdef __cplusplus
  }
#endif
#endif

@

No caso, as Declarações de Memória que usaremos aqui começam com os
cabeçalhos que serão usados, e posteriormente passaraão para as
declarações das funções e estruturas de dado a serem usadas nele:

@<Declarações de Memória@>=
#include <sys/mman.h> // |mmap|, |munmap|
#include <pthread.h> // |pthread_mutex_init|, |pthread_mutex_destroy|
#include <string.h> // |strncpy|
#include <unistd.h> // |sysconf|
#include <stdlib.h> // |size_t|
#include <stdio.h> // |perror|
#include <math.h> // |ceil|
#include <stdbool.h>
@

Outra coisa relevante a mencionar é que à partir de agora assumiremos
que as seguintes macros são definidas em \texttt{conf/conf.h}:

\begin{itemize}
\item|W_MAX_MEMORY|: O valor máximo em bytes de memória que iremos
  alocar por meio da função |Walloc| de alocação de memória na arena
  padrão.
\item|W_WEB_MEMORY|: A quantidade de memória adicional em bytes que
  reservaremos para uso caso compilemos o nosso jogo para a Web ao
  invés de gerar um programa executável. O Emscripten precisará de
  memória adicional e a quantidade pode depender do quanto outras
  funções como |malloc| e |Walloc_arena| são usadas. Este valor deve
  ser aumentado se forem encontrados problemas de falta de memória na
  web. Esta macro será consultada na verdade por um dos
  \texttt{Makefiles}, não por código que definiremos neste PDF.
\end{itemize}

@*1 Estruturas de Dados Usadas.

Vamos considerar primeiro uma \textbf{arena}. Toda \textbf{arena} terá
a seguinte estrutura:

\begin{verbatim}
+-----------+------------+-------------------------+-------------+
; Cabeçalho ; Breakpoint ; Breakpoints e alocações ; Não alocado ;
+-----------+------------+-------------------------+-------------+
\end{verbatim}

O cabeçalho conterá todas as informações que precisamos para usar a
arena. Chamaremos sua estrutura de dados de |struct arena_header|. O
primeiro \textit{breakpoint} nunca pode ser removido e ele é útil para
que o comando |Wtrash| sempre funcione e seja definido, pois sempre
existirá um último \textbf{breakpoint}. Em seguida, virá uma lista que
talvez seja vazia (para arenas recém-criadas) de \textit{breakpoints}
e regiões de memória alocadas. E por fim, haverá uma região de memória
desalocada.

\begin{enumerate}
\item\textbf{Total:} A quantidade total em bytes de memória que a
  arena possui. Como precisamos garantir que ele tenha um tamanho
  suficientemente grande para que alcance qualquer posição que possa
  ser alcançada por um endereço, ele precisa ser um |size_t|. Pelo
  padrão ISO isso será no mínimo 2 bytes, mas em computadores pessoais
  atualmente está chegando a 8 bytes.

  Esta informação será preenchida na inicialização da arena e nunca
  mais será mudada.
\item\textbf{Usado:} A quantidade de memória que já está em uso nesta
  arena. Isso nos permite verificar se temos espaço disponível ou não
  para cada alocação. Pelo mesmo motivo do anterior, precisa ser um
  |size_t|.

  Esta informação precisará ser atualizada toda vez que mais memória
  for alocada ou desalocada. Ou quando um \textbf{breakpoint} for
  criado ou destruído.
\item\textbf{Último Breakpoint:} Armazenar isso nos permite saber à
  partir de qual posição podemos começar a desalocar memória em caso
  de um |Wtrash|. Outro |size_t|.

  Eta informaçção precisa ser atualizada toda vez que um
  \textbf{breakpoint} for criado ou destruído. Um último breakpoint
  sempre existirá, pois o primeiro breakpoint nunca pode ser removido.
\item\textbf{Último Elemento:} Endereço do último elemento
  que foi armazenado. É útil guardar esta informação porque quando
  criamos um novo elemento com |Walloc| ou |Wbreakpoint|, o novo
  elemento precisa apontar para o último que havia antes dele.
  
  Esta informação precisa ser atualizada após qualquer operação de
  alocação, desalocação ou \textbf{breakpoint}. Sempre existirá um
  último elemento na arena, pois um primeiro breakpoint sempre estará
  posicionado após o cabeçalho.
\item\textbf{Posição Vazia:} Um ponteiro para a próxima região
  contínua de memória não-alocada. É preciso saber disso para podermos
  criar novas estruturas e retornar um espaço ainda não-utilizado em
  caso de |Walloc|. Outro |size_t|.

  Novamente é algo que precisa ser atualizado após qualquer uma das
  operações de memória sobre a arena. É possível que não hajam mais
  regiões vazias caso tudo já tenha sido alocado. Neste caso, o
  ponteiro deverá ser |NULL|.
\item\textbf{Mutex:} Opcional. Só precisamos definir isso se
  estivermos usando mais de uma thread. Neste caso, o mutex servirá
  para prevenir que duas threads tentem modificar qualquer um destes
  valores ao mesmo tempo. 

  Caso seja usado, o mutex precisa ser usado em qualquer operação de
  memória, pois todas elas precisam modificar elementos da arena.
\item\textbf{Uso Máximo:} Opcional. Só precisamos definir isso se
  estamos rodando o programa em um nível alto de depuração e por isso
  queremos saber ao fim do uso da arena qual a quantidade máxima de
  memória que alocamos nela ao longo da execução do programa. Um
  |size_t|.

  Se estivermos monitorando o valor, precisamos verificar se ele
  precisa ser atualizado após qualquer alocação ou criação de
  \textbf{breakpoint}.
\item\textbf{Arquivo:} Opcional. Só precisa ser usado e definido se o
  programa ainda está sendo depurado. É uma string com o nome do
  arquivo no qual a arena foi criada. Saber disso é útil para que
  possamos escrever na tela mensagens de depuração úteis. Usaremos uma
  string de 32 bytes para armazenar tal informação. Este tamanho exato
  é escolhido para manter o alinhamento da memória.

  Esta informação só precisa ser escrita durante a inicialização da
  arena.
\item\textbf{Linha:} opcional. Só precisamos disso se o programa está
  sendo depurado. Ele deve armazenar o número da linha na qual esta
  arena foi criada. Definimos como |unsigned long|.

  Este valor só precisa ser escrito e modificado durante a
  inicialização.
\end{enumerate}

Então, assim podemos definir o nosso cabeçalho para arenas. Toda
arena terá tal estrutura em seu início.

@<Declarações de Memória@>+=
struct _arena_header{@#
  size_t total, used;
  struct _breakpoint *last_breakpoint;
  void *empty_position, *last_element;
#ifdef W_MULTITHREAD
  pthread_mutex_t mutex;
#endif
#if W_DEBUG_LEVEL >= 3
  size_t max_used;
#endif
#if W_DEBUG_LEVEL >= 1
  char file[32];@;
  unsigned int line;
#endif
};
@

Pela definição, existem algumas restrições sobre os valores presentes
em cabeçalhos de arena: ${\it total} \geq {\it max\_used} \geq {\it
  used}$, ${\it last\_element} \geq {\it last\_breakpoint}$, $({\it
  empty\_position} = {\it NULL}) \vee ({\it empty\_position >
  last\_element})$ e ${\it used > 0}$ (o breakpoint e o cabeçalho usam
o espaço).

Quando criamos a arena e desejamos inicializar o valor de seu
cabeçalho, tudo o que precisamos saber é o tamanho total que a arena
tem. Os demais valores podem ser deduzidos. Portanto, podemos usar
esta função interna para a tarefa:

@<Declarações de Memória@>+=
bool _initialize_arena_header(struct _arena_header *header,
			      size_t total, char *file, int line);
@
@(project/src/weaver/memory.c@>=
#include "memory.h"

bool _initialize_arena_header(struct _arena_header *header,
				     size_t total, char *file,
				     int line){
  header -> total = total;
  header -> used = sizeof(struct _arena_header) - sizeof(struct _breakpoint);
  header -> last_breakpoint = (struct _breakpoint *) (header + 1);
  header -> last_element = (void *) header -> last_breakpoint;
  header -> empty_position = (void *) (header -> last_breakpoint + 1);
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&(header -> mutex), NULL) != 0){
    return false;
  }  
#endif
#if W_DEBUG_LEVEL >= 3
  header -> max_used = header -> used;
#endif
#if W_DEBUG_LEVEL >= 1
  strncpy(header -> file, file, 32);
  header -> line = line;
#endif
  return true;
}
@

É importante notar que tal função de inicialização só pode falhar se
ocorrer algum erro inicializando o mutex. Por isso podemos representar
o seu sucesso ou fracasso fazendo-a retornar um valor booleano.

\begin{enumerate}
\item\textbf{Tipo:} Um número mágico que corresponde sempre à um valor
  que identifica o elemento como sendo um \textit{breakpoint}, e não
  um fragmento alocado de memória;
\item\textbf{Último breakpoint:} No caso do primeiro breakpoint, isso
  deve apontar para ele próprio (e assim o primeiro breakpoint pode
  ser reconhecido). nos demais casos, ele irá apontar para o
  breakpoint anterior. Desta forma, em caso de |Wtrash|, poderemos
  restaurar o cabeçalho da arena para apontar para o breakpoint
  anterior, já que o atual está sendo apagado.
\item\textbf{Último Elemento:} Para que a lista de elementos de uma
  arena possa ser percorrida, cada elemento deve ser capaz de apontar
  para o elemento anterior. Desta forma, se o breakpoint for removido
  e o elemento anterior da arena foi marcado para ser apagado, mas
  ainda não foi, então ele deve ser apagado.
\item\textbf{Arena:} Um ponteiro para a arena à qual pertence a
  memória.
\item\textbf{Tamanho:} A quantidade de memória alocada até o
  breakpoint em questão.
\item\textbf{Arquivo:} Opcional para depuração. O nome do arquivo onde
  esta região da memória foi alocada.
\item\textbf{Linha:} Opcional para depuração. O número da linha onde
  esta região da memória foi alocada.
\end{enumerate}

Sendo assim, a nossa definição de breakpoint é:

@<Declarações de Memória@>+=
struct _breakpoint{
  unsigned long type;
  void *last_element;
  void *arena;
  void *last_breakpoint;
  size_t size;
#if W_DEBUG_LEVEL >= 1
  char file[32];
  unsigned long line;
#endif
};

@ Por fim, vamos à definição da memória alocada. Ela é formada
basicamente por um cabeçalho, o espaço alocado em si e uma
finalização. No caso do cabeçalho, precisamos dos seguintes elementos:

\begin{enumerate}
\item\textbf{Tipo:} Um número que identifica o elemento como um
  cabeçalho de dados, não um breakpoint.
\item\textbf{Tamanho Real:} Quantos bytes tem a região alocada para
  dados. É igual ao tamanho pedido mais alguma quantidade adicional de
  bytes de preenchimento para podermos manter o alinhamento da
  memória.
\item\textbf{Tamanho Pedido:} Quantos bytes foram pedidos na alocação,
  ignorando o preenchimento.
\item\textbf{Último Elemento:} A posição do último elemento da
  arena. Pode ser outro cabeçalho de dado alocado ou um
  breakpoint. Este ponteiro nos permite acessar os dados como uma
  lista encadeada.
\item\textbf{Arena:} Um ponteiro para a arena à qual pertence a
  memória.
\item\textbf{Flags:} Permite que coloquemos informações adicionais. o
  último bit é usado para definir se a memória foi marcada para ser
  apagada ou não.
\item\textbf{Arquivo:} Opcional para depuração. O nome do arquivo onde
  esta região da memória foi alocada.
\item\textbf{Linha:} Opcional para depuração. O número da linha onde
  esta região da memória foi alocada.
\end{enumerate}

Sendo assim, a definição de nosso cabeçalho de dados é:

@<Declarações de Memória@>+=
struct _memory_header{
  unsigned long type;
  void *last_element;
  void *arena;
  size_t real_size, requested_size;
  unsigned long flags;
#if W_DEBUG_LEVEL >= 1
  char file[32];
  unsigned long line;
#endif
};


@ E por fim, precisamos definir os 2 números mágicos que mencionamos
em nossa descrição das estruturas de memória:

@<Declarações de Memória@>+=
#define _BREAKPOINT_T  0x1
#define _DATA_T        0x2

@*1 Criando e destruindo arenas.

Criar uma nova arena envolve basicamente alocar memória usando |mmap|
e tomando o cuidado para alocarmos sempre um número múltiplo do
tamanho de uma página (isso garante alinhamento de memória e também
nos dá um tamanho ótimo para paginarmos). Em seguida preenchemos o
cabeçalho da arena e colocamos o primeiro breakpoint nela.

A função que cria novas arenas deve receber como argumento o tamanho
mínimo que ela deve ter em bytes e também o nome do arquivo e número
de linha em que estamos para fins de depuração. Já destruir uma arena
requer um ponteiro para ela, bem como o arquivo e número de linha
atual:

@<Declarações de Memória@>+=
void *_create_arena(size_t, char *, unsigned long);
int _destroy_arena(void *);

@*2 Criando uma arena.

O processo de criar a arena funciona alocando todo o espaço de que
precisamos e em seguida preenchendo o cabeçalho inicial e breakpoint:

@(project/src/weaver/memory.c@>+=
void *_create_arena(size_t size, char *filename, unsigned long line){
  void *arena;
  size_t real_size = 0;
  struct _breakpoint *breakpoint;

  @<Aloca 'arena' com cerca de 'size' bytes e preenche 'real\_size'@>@/

  if(arena != NULL){
    if(!_initialize_arena_header((struct _arena_header *) arena, real_size,
				 filename, line)){
      @<Desaloca 'arena'@>@/
    }
    //\\ Preenchendo o primeiro breakpoint\\
    breakpoint = (struct _breakpoint *) malloc(sizeof(struct _breakpoint));
    if(breakpoint == NULL){
      @<Desaloca 'arena'@>@/
    }
    breakpoint -> type = _BREAKPOINT_T;
    breakpoint -> last_breakpoint = breakpoint;
    breakpoint -> last_element = arena;
    breakpoint -> arena = arena;
    breakpoint -> size = sizeof (struct _arena_header);
#if W_DEBUG_LEVEL >= 1
    strncpy(breakpoint -> file, filename, 32);
    breakpoint -> line = line;
#endif
  }

  return arena;
}

@ alocar o espaço envolve primeiro estabelecer qual o tamanho que
queremos. Ele deverá ser o menor tamanho que é maior ou igual ao valor
pedido e que seja múltiplo do tamanho de uma página do sistema. Em
seguida, usamos a chamada de sistema |mmap| para obter a
memória. Outra opção seria o |brk|, mas usar tal chamada de sistema
criaria conflito caso o usuário tentasse usar o |malloc| da biblioteca
padrão ou usasse uma função de biblioteca que usa internamento o
|malloc|. Como até um simples |sprintf| usa |malloc|, devemos evitar
usar o |brk|:

@<Aloca 'arena' com cerca de 'size' bytes e preenche 'real\_size'@>=
{
  long page_size = sysconf(_SC_PAGESIZE);
  real_size = ((int) ceil((double) size / (double) page_size)) * page_size;
  arena = mmap(0, real_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS,
	       -1, 0);
  if(arena == MAP_FAILED){
    arena = NULL;
  }
}

@ E para desalocar uma arena:

@<Desaloca 'arena'@>=
{
  if(munmap(arena, ((struct _arena_header *) arena) -> total) == -1){
    arena = NULL;
  }
}

@ Para que possamos usar esta função sem termos que nos preocupar com
a verificação do nome do arquivo e número de linha, na prática
definimos a seguinte macro:

@<Declarações de Memória@>+=
#define Wcreate_arena(a) _create_arena(a, __FILE__, __LINE__)

@*2 Destruindo uma arena.

Destruir uma arena é uma simples questão de finalizar o seu mutex caso
estejamos criando um programa com muitas threads e usar um
|munmap|. Entretanto, se estamos rodando uma versão em desenvolvimento
do jogo, com depuração, este será o momento no qual informaremos a
existência de vazamentos de memória. E dependendo do nível da
depuração, podemos imprimir também a quantidade máxima de memória
usada:

@(project/src/weaver/memory.c@>+=
int _destroy_arena(void *arena){
#if W_DEBUG_LEVEL >= 1
  struct _arena_header *header = (struct _arena_header *) arena;
  @<Checa vazamento de memória em 'arena' dado seu 'header'@>@/
#endif
#if W_DEBUG_LEVEL >= 3
  fprintf(stderr,
	  "WARNING (3): Max memory used in arena %s:%lu: %lu/%lu\n",
	  header -> file, header -> line, (unsigned long) header -> max_used,
	  (unsigned long) header -> total);
#endif
#ifdef W_MULTITHREAD
  {
    struct _arena_header *header = (struct _arena_header *) arena;
    if(pthread_mutex_destroy(&(header -> mutex)) != 0){
      return 0;
    }
  }
#endif
  @<Desaloca 'arena'@>@/
  if(arena == NULL){
    return 0;
  }
  return 1;
}

@ Agora resta apenas definir como checamos a existência de vazamentos
de memória. Cada arena tem em seu cabeçalho um ponteiro para seu
último elemento. E cada elemento tem um ponteiro para um elemento
anterior. Sendo assim, basta percorrermos a lista encadeada e
verificarmos se encontramos um cabeçalho de memória alocada que não
foi desalocado. Tais cabeçalhos são identificados como tendo o último
bit de sua variável |flags| como sendo 1. E devemos percorrer a lista
até chegarmos ao primeiro breakpoint.

@<Checa vazamento de memória em 'arena' dado seu 'header'@>=
{
  struct _memory_header *p = (struct _memory_header *) header -> last_element;
  while(p -> type != _BREAKPOINT_T ||
	((struct _breakpoint *) p) -> last_breakpoint != p){
    if(p -> type == _DATA_T && p -> flags % 2){
      fprintf(stderr, "WARNING (1): Memory leak in data allocated in %s:%lu\n",
	      p -> file, p -> line);
    }
    p = (struct _memory_header *) p -> last_element;
  }
}

@ E agora uma função de macro construída em cima desta para que
possamos destruir arenas sem nos preocuparmos com o nome de arquivo e
número de linha:

@<Declarações de Memória@>+=
#define Wdestroy_arena(a) _destroy_arena(a)

@*1 Alocação e desalocação de memória.

@<Declarações de Memória@>+=
void *_alloc(void *arena, size_t size, char *filename, unsigned long line);
void _free(void *mem, char *filename, unsigned long line);

@ Alocar memória significa basicamente atualizar informações no
cabeçalho de sua arena indicando quanto de memória estamos pegando e
atualizando o ponteiro para o último elemento e para o próximo espaço
disponível para alocação. Podemos também ter que atualizar qual a
quantidade máxima de memória usada por tal arena. E podemos precisar
usar um mutex para isso.

Além do cabeçalho da arena, temos também que colocar o cabeçalho da
região alocada e o seu rodapé. Mas nesta parte não precisaremos mais
segurar o mutex.

Podemos ter que alocar uma quantidade ligeiramente maior que a pedida
para preservarmos o alinhamento dos dados na memória. A memória sempre
se manterá alinhada com um |long|. O verdadeiro tamanho alocado será
armazenado em |real_size|.

O que pode dar errado é que podemos não ter espaço na arena para fazer
a alocação. Neste caso, teremos que retornar |NULL| e se estivermos em
fase de depuração, imprimiremos uma mensagem avisando isso:

@(project/src/weaver/memory.c@>+=
void *_alloc(void *arena, size_t size, char *filename, unsigned long line){
  struct _arena_header *header = arena;
  struct _memory_header *mem_header;
  void *mem = NULL, *old_last_element;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
  mem_header = header -> empty_position;
  old_last_element = header -> last_element;
  //Parte 1: Calcular o verdadeiro tamanho a se alocar:\\
  size_t real_size = (size_t) (ceil((float) size / (float) sizeof(long)) *
			       sizeof(long));
  //Parte 2: Atualizar o cabeçalho da arena:\\
  if(header -> used + real_size + sizeof(struct _memory_header) > 
     header -> total){
#if W_DEBUG_LEVEL >= 1
    fprintf(stderr, "WARNING (1): No memory enough to allocate in %s:%lu.\n",
      filename, line);
#endif
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(header -> mutex));
#endif
    return NULL;
  }
  header -> used += real_size + sizeof(struct _memory_header);
  mem = (void *) ((char *) header -> empty_position +
		  sizeof(struct _memory_header));
  header -> last_element = header -> empty_position;
  header -> empty_position = (void *) ((char *) mem + real_size);
#if W_DEBUG_LEVEL >= 3
  if(header -> used > header -> max_used){
    header -> max_used = header -> used;
  }
#endif
  //Parte 3: Preencher o cabeçalho do dado a ser alocado:\\
  mem_header -> type = _DATA_T;
  mem_header -> last_element = old_last_element;
  mem_header -> real_size = real_size;
  mem_header -> requested_size = size;
  mem_header -> flags = 0x1;
  mem_header -> arena = arena;
#if W_DEBUG_LEVEL >= 1
  strncpy(mem_header -> file, filename, 32);
  mem_header -> line = line;
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
  return mem;
}

@ E agora precisamos só de uma função de macro para cuidar
automaticamente da tarefa de coletar o nome de arquivo e número de
linha para mensagens de depuração:

@<Declarações de Memória@>+=
#define Walloc_arena(a, b) _alloc(a, b, __FILE__, __LINE__)

@ Para desalocar a memória, existem duas possibilidades. Podemos estar
desalocando a última memória alocada ou não. No primeiro caso, tudo é
uma questão de atualizar o cabeçalho da arena modificando o valor do
último elemento armazenado e também um ponteiro pra o próximo espaço
vazio. No segundo caso, tudo o que fazemos é marcar o elemento para
ser desalocado no futuro.

Caso o elemento realmente seja desalocado (seja o último elemento
alocado), temos que percorrer os elementos anteriores desalocando
todos aqueles que foram marcados para desalocar e parar no primeiro
elemento que ainda estiver em uso.

@(project/src/weaver/memory.c@>+=
void _free(void *mem, char *filename, unsigned long line){
  struct _memory_header *mem_header = ((struct _memory_header *) mem) - 1;
  struct _arena_header *arena = mem_header -> arena;
  void *last_freed_element;
  size_t memory_freed = 0;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(arena -> mutex));
#endif
  // Primeiro checamos se não estamos desalocando a última memória. Se
  // é a última memória, precisamos manter o mutex ativo para impedir
  // que hajam novas escritas na memória depois dela no momento:
  if((struct _memory_header *) arena -> last_element != mem_header){
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(arena -> mutex));
#endif
    mem_header -> flags = 0x0;
#if W_DEBUG_LEVEL >= 2
    fprintf(stderr,
	    "WARNING (2): %s:%lu: Memory allocated in %s:%lu should be"
	    " freed first.\n", filename, line,
	    ((struct _memory_header *) (arena -> last_element)) -> file,
	    ((struct _memory_header *) (arena -> last_element)) -> line);
#endif
    return;
  }
  memory_freed = mem_header -> real_size + sizeof(struct _memory_header);
  last_freed_element = mem_header;
  mem_header = mem_header -> last_element;
  while(mem_header -> type != _BREAKPOINT_T && mem_header -> flags == 0x0){
    memory_freed += mem_header -> real_size + sizeof(struct _memory_header);
    last_freed_element = mem_header;
    mem_header = mem_header -> last_element;
  }
  arena -> last_element = mem_header;
  arena -> empty_position = last_freed_element;
  arena -> used -= memory_freed;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(arena -> mutex));
#endif
}

@ E agora a macro que automatiza a obtenção do nome de arquivo e
número de linha:

@<Declarações de Memória@>+=
#define Wfree(a) _free(a, __FILE__, __LINE__)

@*1 Usando a heap descartável.

Graças ao conceito de \textit{breakpoints}, pode-se desalocar ao mesmo
tempo todos os elementos alocados desde o último \textit{breakpoint}
por meio do |Wtrash|.  A criação de um \textit{breakpoit} e descarte
de memória até ele se dá por meio das funções declaradas abaixo:

@<Declarações de Memória@>+=
int _new_breakpoint(void *arena, char *filename, unsigned long line);
void _trash(void *arena);

@ As funções precisam receber como argumento apenas um ponteiro para a
arena na qual realizar a operação. Além disso, elas recebem também o
nome de arquivo e número de linha como nos casos anteriores para que
isso ajude na depuração:

@(project/src/weaver/memory.c@>+=
int _new_breakpoint(void *arena, char *filename, unsigned long line){
  struct _arena_header *header = (struct _arena_header *) arena;
  struct _breakpoint *breakpoint, *old_breakpoint;
  void *old_last_element;
  size_t old_size;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
  if(header -> used + sizeof(struct _breakpoint) > header -> total){
#if W_DEBUG_LEVEL >= 1
    fprintf(stderr, "WARNING (1): No memory enough to allocate in %s:%lu.\n",
      filename, line);
#endif
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(header -> mutex));
#endif
    return 0;
  }
  old_breakpoint = header -> last_breakpoint;
  old_last_element = header -> last_element;
  old_size = header -> used;
  header -> used += sizeof(struct _breakpoint);
  breakpoint = (struct _breakpoint *) header -> empty_position;
  header -> last_breakpoint = breakpoint;
  header -> empty_position = ((struct _breakpoint *) header -> empty_position) +
    1;
  header -> last_element = header -> last_breakpoint;
#if W_DEBUG_LEVEL >= 3
  if(header -> used > header -> max_used){
    header -> max_used = header -> used;
  }
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
  breakpoint -> type = _BREAKPOINT_T;
  breakpoint -> last_element = old_last_element;
  breakpoint -> arena = arena;
  breakpoint -> last_breakpoint = (void *) old_breakpoint;
  breakpoint -> size = old_size;
#if W_DEBUG_LEVEL >= 1
  strncpy(breakpoint -> file, filename, 32);
  breakpoint -> line = line;
#endif
  return 1;
}

@ E a função para descartar toda a memória presente na heap até o
último breakpoint:

@(project/src/weaver/memory.c@>+=
void _trash(void *arena){
  struct _arena_header *header = (struct _arena_header *) arena;
  struct _breakpoint *previous_breakpoint =
    ((struct _breakpoint *) header -> last_breakpoint) -> last_breakpoint;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
  if(header -> last_breakpoint == previous_breakpoint){
    header -> last_element = previous_breakpoint;
    header -> empty_position = (void *) (previous_breakpoint + 1);
    header -> used = previous_breakpoint -> size + sizeof(struct _breakpoint);
  }
  else{
    struct _breakpoint *last = (struct _breakpoint *) header -> last_breakpoint;
    header -> used = last -> size;
    header -> empty_position = last;
    header -> last_element = last -> last_element;
    header -> last_breakpoint = previous_breakpoint;;
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
}

@ E para finalizar, as macros necessárias para usarmos as funções sem
nos preocuparmos com o nome do arquivo e número de linha:

@<Declarações de Memória@>+=
#define Wbreakpoint_arena(a) _new_breakpoint(a, __FILE__, __LINE__)
#define Wtrash_arena(a) _trash(a)

@*1 Usando as arenas de memória padrão.

Ter que se preocupar com arenas muitas vezes é desnecessário. O
usuário pode querer simplesmente usar uma função |Walloc| sem ter que
se preocupar com qual arena usar. Usando simplesmente a arena
padrão. E associada à ela deve haver as funções |Wfree|, |Wbreakpoint|
e |Wtrash|.

Primeiro precisaremos declarar duas variáveis globais. Uma delas será
uma arena padrão do usuário, a outra deverá ser uma arena usada pelas
funções internas da própria API. Ambas as variáveis devem ficar
restritas ao módulo de memória, então serão declaradas como estáticas:

@(project/src/weaver/memory.c@>+=
static void *_user_arena, *_internal_arena;
@


@ Vamos precisar inicializar e finalizar estas arenas com as seguinte
funções:

@<Declarações de Memória@>+=
void _initialize_memory(char *filename, unsigned long line);
void _finalize_memory();

@ Note que são funções que sabem o nome do arquivo e número de linha
em que estão para propósito de depuração. Elas são definidas como
sendo:

@(project/src/weaver/memory.c@>+=
void _initialize_memory(char *filename, unsigned long line){
  _user_arena = _create_arena(W_MAX_MEMORY, filename, line);
  _internal_arena = _create_arena(4000, filename, line);
}
void _finalize_memory(){
  _destroy_arena(_user_arena);
  Wtrash_arena(_internal_arena);
  _destroy_arena(_internal_arena);
}


@ Passamos adiante o número de linha e nome do arquivo para a função
de criar as arenas. Isso ocorre porque um usuário nunca invocará
diretamente estas funções. Quem vai chamar tal função é a função de
inicialização da API. Se uma mensagem de erro for escrita, ela deve
conter o nome de arquivo e número de linha onde está a própria função
de inicialização da API. Não onde tais funções estão definidas.

A invocação destas funções se dá na inicialização da API, a qual é
mencionada na Introdução. Da mesma forma, na finalização da API,
chamamos a função de finalização:

@<API Weaver: Inicialização@>+=
_initialize_memory(filename, line);

@
@<API Weaver: Finalização@>+=

// Em ``desalocações'' desalocamos memória alocada com |Walloc|:
@<API Weaver: Desalocações@>@/
_finalize_memory();

@

Agora para podermos alocar e desalocar memória da arena padrão e da
arena interna, criaremos a seguinte funções:

@<Declarações de Memória@>+=
void *_Walloc(size_t size, char *filename, unsigned int line);
#define Walloc(n) _Walloc(n, __FILE__, __LINE__)
void *_Winternal_alloc(size_t size, char *filename, unsigned int line);
#define _iWalloc(n) _Winternal_alloc(n, __FILE__, __LINE__)
@

@(project/src/weaver/memory.c@>+=
void *_Walloc(size_t size, char *filename, unsigned int line){
  return _alloc(_user_arena, size, filename, line);
}
void *_Winternal_alloc(size_t size, char *filename, unsigned int line){
  return _alloc(_internal_arena, size, filename, line);
}
@

O |Wfree| já foi definido e irá funcionar sem problemas, independente
da arena à qual pertence o trecho de memória alocado. Sendo assim,
resta definir apenas o |Wbreakpoint| e |Wtrash|:

@<Declarações de Memória@>+=
int _Wbreakpoint(char *filename, unsigned long line);
void _Wtrash();
#define Wbreakpoint() _Wbreakpoint(__FILE__, __LINE__)
#define Wtrash() _Wtrash()
@

E a definição das funções segue abaixo:

@(project/src/weaver/memory.c@>+=
int _Wbreakpoint(char *filename, unsigned long line){
  return _new_breakpoint(_user_arena, filename, line);
}
void _Wtrash(){
  _trash(_user_arena);
}
@

@*1 Medindo o desempenho.

Existem duas macros que são úteis de serem definidas que podem ser
usadas para avaliar o desempenho do gerenciador de memória definido
aqui. Elas são:

@<Cabeçalhos Weaver@>+=
#include <stdio.h>
#include <sys/time.h>

#define W_TIMER_BEGIN() { struct timeval _begin, _end; \
gettimeofday(&_begin, NULL);
#define W_TIMER_END() gettimeofday(&_end, NULL); \
printf("%ld us\n", (1000000 * (_end.tv_sec - _begin.tv_sec) + \
_end.tv_usec - _begin.tv_usec)); \
}

@

Como a primeira macro inicia um bloco e a segunda termina, ambas devem
ser sempre usadas dentro de um mesmo bloco de código, ou um erro
ocorrerá. O que elas fazem nada mais é do que usar |gettimeofday| e
usar a estrutura retornada para calcular quantos microssegundos se
passaram entre uma invocação e outra. Em seguida, escreve-se na saída
padrão quantos microssegundos se passaram.

Como exemplo de uso das macros, podemos usar a seguinte função |main|
para obtermos uma medida de performance das funções |Walloc| e
|Wfree|:

\begin{verbatim}
int main(int argc, char **argv){
  unsigned long i;
  void *m[1000000];
  Winit();
  W_TIMER_BEGIN();
  for(i = 0; i < 1000000; i ++){
    m[i] = Walloc(1);
  }
  for(i = 0; i < 1000000; i ++){
    Wfree(m[i]);
  }
  Wtrash();
  W_TIMER_END();
  Wexit();
  return 0;
}
\end{verbatim}

Rodando este código em um Pentium B980 2.40GHz Dual Core, obtemos os
seguintes resultados para o |Walloc|/|Wfree| (em vermelho) comparado
com o |malloc|/|free| (em azul) da biblioteca padrão (Glibc 2.20)
comparado ainda com a substituição do segundo loop por uma única
chamada para |Wtrash| (em verde):

%\noindent
%\includegraphics[width=0.5\textwidth]{cweb/diagrams/benchmark_walloc_malloc.eps}

O alto desempenho do uso de |Walloc|/|Wtrash| é compreensível pelo
fato da função |Wtrash| desalocar todo o espaço ocupado pelo último
milhão de alocações no mesmo tempo que |Wfree| levaria para desalocar
uma só alocação. Isso explica o fato de termos reduzido pela metade o
tempo de execução do exemplo.

Entretanto, tais resultados positivos só são obtidos caso usemos a
macro |W_DEBUG_LEVEL| ajustada para zero, como é recomendado fazer ao
compilar um jogo pela última vez antes de distribuir. Caso o jogo
ainda esteja em desenvolvimento e tal macro tenha um valor maior do
que zero, o desempenho de |Walloc| e |Wfree| pode tornar-se de duas à
vinte vezes pior devido à estruturas adicionais estarem sendo usadas
para depuração e devido à mensagens poderem ser escritas na saída
padrão.

Os bons resultados são ainda mais visíveis caso compilemos nosso
programa para a Web (ajustando a macro |W_TARGET| para |W_WEB|). Neste
caso, o desempenho do |malloc| tem uma queda brutal. Ele passa a
executar 20 vezes mais lentamente no exemplo acima, enquanto as
funções que desenvolvemos ficam só 1,8 vezes mais lentas. É até
difícil mostrar isso em gráfico devido à diferença de escala entre as
medidas. Nos testes, usou-se o Emscripten versão 1.34.

Mas e se usarmos várias threads para realizarmos este milhão de
alocações nesta máquina com 2 processadores? Supondo que exista a
função |test| que realiza todas as alocações e desalocações de um
milhão de posições de memória divididas pelo número de threads e
supondo que executemos o seguinte código:

\begin{verbatim}
int main(int argc, char **argv){
  pthread_t threads[NUM_THREADS];
  int i;
  Winit();
  for(i = 0; i < NUM_THREADS; i ++)
    pthread_create(&threads[i], NULL, test, (void *) NULL);
  W_TIMER_BEGIN();
  for (i = 0; i < NUM_THREADS; i++)
    pthread_join(threads[i], NULL);
  W_TIMER_END();
  Wexit();
  pthread_exit(NULL);
  return 0;
}
\end{verbatim}

O resultado é este:

%\noindent
%\includegraphics[width=0.75\textwidth]{cweb/diagrams/benchmark_alloc_threads.eps}

O desempenho de |Walloc| e |Wfree| (em vermelho) passa a deixar muito
à desejar comparado com o uso de |malloc| e |free| (em azul). Isso
ocorre porque na nossa função de alocação, para alocarmos e
desalocarmos, precisamos bloquear um mutex. Desta forma, neste
exemplo, como tudo o que as threads fazem é alocar e desalocar, na
maior parte do tempo elas ficam bloqueadas. As funções |malloc| e
|free| da biblioteca padrão não sofrem com este problema, pois cada
thread sempre possui a sua própria arena para alocação. Nós não
podemos fazer isso automaticamente porque no nosso gerenciador de
memória, para que possamos realizar otimizações, precisamos saber com
antecedência qual a quantidade máxima de memória que iremos
alocar. Não temos como deduzir este valor para cada thread.

Mas nós podemos criar manualmente arenas ara as nossas threads por
meio de |Wcreate_arena| e depois podemos usar |Wdestroy_arena| pouco
antes da thread encerrar. Desta forma podemos usar |Walloc_arena| para
alocar a memória em uma arena particular da thread. Com isso,
conseguimos desempenho equivalente ao |malloc| para uma ou duas
threads. Para mais threads, conseguimos um desempenho ainda melhor em
relação ao |malloc|, já que nosso desempenho não sofre tanta
degradação se usamos mais threads que o número de
processadores. Podemos analisar o desempenho no gráfico mais abaixo
por meio da cor verde.

Mas se reservamos manualmente uma arena para cada thread, então somos
capazes de desalocar toda a memória da arena por meio da
|Wtrash_arena|. Sendo assim, economizamos o tempo que seria gasto
desalocando memória. O desempenho desta forma de uso do nosso alocador
pode ser visto no gráfico em amarelo.

O uso de threads na web por meio de Emscripten no momento da escrita
deste texto ainda está experimental. Somente o Firefox Nightly suporta
o recurso no momento. Por este motivo, testes de desempenho envolvendo
threads em programas web ficarão pendentes.
