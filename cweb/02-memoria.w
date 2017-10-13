@* Gerenciamento de memória.

Alocar memória dinamicamente é uma operação cujo tempo nem sempre pode
ser previsto. Depende da quantidade de blocos contínuos de memória
presentes na heap que o gerenciador organiza. E isso depende muito do
padrão de uso das funções |malloc| e |free|.

Jogos de computador tradicionalmente evitam o uso contínuo de
\monoespaco{malloc} e \monoespaco{free} por causa disso. Tipicamente jogos
programados para ter um alto desempenho alocam toda (ou a maior parte)
da memória de que vão precisar logo no início da execução gerando um
\italico{pool} de memória e gerenciando ele ao longo da execução. De
fato, esta preocupação direta com a memória é o principal motivo de
linguagens sem \italico{garbage collectors} como C++ serem tão
preferidas no desenvolvimento de grandes jogos comerciais.

Um dos motivos para isso é que também nem sempre o |malloc| disponível
pela biblioteca padrão de algum sistema é muito eficiente para o que
está sendo feito. Como um exemplo, será mostrado posteriormente
gráficos de benchmarks que mostram que após ser compilado para
Javascript usando Emscripten, a função |malloc| da biblioteca padrão
do Linux torna-se terrivelmente lenta. Mas mesmo que não estejamos
lidando com uma implementação rápida, ainda assim há benefícios em ter
um alocador de memória próprio. Pelo menos a práica de alocar toda a
memória necessária logo no começo e depois gerenciar ela ajuda a
termos um programa mais rápido.

Por causa disso, Weaver exisge que você informe anteriormente quanto
de memória você irá usar e cuida de toda a alocação durante a
inicialização. Sabendo a quantidade máxima de memória que você vai
usar, isso também permite que vazamentos de memória sejam detectados
mais cedo e permitem garantir que o seu jogo está dentro dos
requisitos de memória esperados.

Weaver de fato aloca mais de uma região contínua de memória onde
pode-se alocar coisas. Uma das regiões contínuas será alocada e usada
pela própria API Weaver à medida que for necessário. A segunda região
de memória contínua, cujo tamanho deve ser declarada em
\monoespaco{conf/conf.h} é a região dedicada para que o usuário possa
alocar por meio de |Walloc| (que funciona como o |malloc|). Além
disso, o usuário deve poder criar novas regiões contínuas de memória
dentro das quais pode-se fazer novas alocações. O nome que tais
regiões recebem é \negrito{arena}.

Além de um |Walloc|, também existe um |Wfree|. Entretanto, o jeito
recomendável de desalocar na maioria das vezes é usando uma outra
função chamada |Wtrash|. Para explicar a ideia de seu funcionamento,
repare que tipicamente um jogo funciona como uma máquina de estados
onde mudamos várias vezes de estado. Por exemplo, em um jogo de RPG
clássico como Final Fantasy, podemos encontrar os seguintes estados:

\imagem{cweb/diagrams/estados.eps}

E cada um dos estados pode também ter os seus próprios
sub-estados. Por exemplo, o estado ``Jogo'' seria formado pela
seguinte máquina de estados interna:

\imagem{cweb/diagrams/estados2.eps}

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
ao término do jogo. Em seguida, podemos criar um \negrito{breakpoint} e
alocamos todos os dados referentes à tela inicial. Quando passarmos da
tela inicial para o jogo em si, podemos desalocar de uma vez tudo o
que foi alocado desde o último \italico{breakpoint} e removê-lo. Ao
entrar no jogo em si, criamos um novo \italico{breakpoint} e alocamos
tudo o que precisamos. Se entramos em tela de combate, criamos outro
\italico{breakpoint} (sem desalocar nada e sem remover o
\italico{breakpoint} anterior) e alocamos os dados referentes à
batalha. Depois que ela termina, desalocamos tudo até o último
\italico{breakpoint} para apagarmos os dados relacionados ao combate e
voltamos assim ao estado anterior de caminhar pelo mundo. Ao longo
destes passos, nossa memória terá aproximadamente a seguinte
estrutura:

\imagem{cweb/diagrams/exemplo_memoria.eps}

Sendo assim, nosso gerenciador de memória torna-se capaz de evitar
completamente fragmentação tratando a memória alocada na heap como uma
pilha. O desenvolvedor só precisa desalocar a memória na ordem inversa
da alocação (se não o fizer, então haverá fragmentação). Entretanto, a
desalocação pode ser um processo totalmente automatizado. Toda vez que
encerramos um estado, podemos ter uma função que desaloca tudo o que
foi alocado até o último \italico{breakpoint} na ordem correta e
elimina aquele \italico{breakpoint} (exceto o último na base da pilha
que não pode ser eliminado). Fazendo isso, o gerenciamento de memória
fica mais simples de ser usado, pois o próprio gerenciador poderá
desalocar tudo que for necessário, sem esquecer e sem deixar
vazamentos de memória. O que a função |Wtrash| faz então é desalocar
na ordem certa toda a memória alocada até o último \italico{breakpoint}
e destrói o \italico{breakpoint} (exceto o primeiro que nunca é
removido). Para criar um novo \italico{breakpoint}, usamos a função
|Wbreakpoint|.

Tudo isso sempre é feito na arena padrão. Mas pode-se criar uma nova
arena (|Wcreate_arena|) bem como destruir uma arena
(|Wdestroy_arena|). E pode-se então alocar memória na arena
personalizada criada (|Walloc_arena|) e desalocar (|Wfree_arena|). Da
mesmo forma, pode-se também criar um \italico{breakpoint} na arena
personalizada (|Wbreakpoint_arena|) e descartar tudo que foi alocado
nela até o último \italico{breakpoint} (|Wtrash_arena|).

Para garantir a inclusão da definição de todas estas funções e
estruturas, usamos o seguinte código:

\quebra

@<Cabeçalhos Weaver@>=
#include "memory.h"
@

E também criamos o cabeçalho de memória. À partir de agora, cada
novo módulo de Weaver terá um nome associado à ele. O deste é
``Memória''. E todo cabeçalho \monoespaco{.h} dele conterá, além das
macros comuns para impedir que ele seja inserido mais de uma vez e
para que ele possa ser usado em C++, uma parte na qual será inserido o
cabeçalho de configuração (visto no fim do capítulo anterior) e a
parte de declarações, com o nome \monoespaco{Declarações de
  NOME\_DO\_MODULO}.

@(project/src/weaver/memory.h@>=
#ifndef _memory_h_
#define _memory_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Declarações de Memória@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/memory.c@>=
#include "memory.h"
@

No caso, as Declarações de Memória que usaremos aqui começam com os
cabeçalhos que serão usados, e posteriormente passarão para as
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
que as seguintes macros são definidas em \monoespaco{conf/conf.h}:

\macronome|W_MAX_MEMORY|: O valor máximo em bytes de memória que iremos
  alocar por meio da função |Walloc| de alocação de memória na arena
  padrão.

\macronome|W_INTERNAL_MEMORY|: Quantidade de memória que será alocada apenas
para operações internas da engine.

\macronome|W_WEB_MEMORY|: A quantidade de memória adicional em bytes que
  reservaremos para uso caso compilemos o nosso jogo para a Web ao
  invés de gerar um programa executável. O Emscripten precisará de
  memória adicional e a quantidade pode depender do quanto outras
  funções como |malloc| e |Walloc_arena| são usadas. Este valor deve
  ser aumentado se forem encontrados problemas de falta de memória na
  web. Esta macro será consultada na verdade por um
  dos \monoespaco{Makefiles}, não por código que definiremos neste
  PDF.

\macronome|W_MAX_SUBLOOP|: O tamanho máximo da pilha de loops
principais que o jogo pode ter. No exemplo dado acima do Final
Fantasy, precisamos de um amanho de pelo menos 3 para conter os
estados ``Tela Inicial'', ``Jogo'' e ``Combate''.

Vamos agora definir os valores padrão para tais macros se elas não
 estiverem definidas. Vamos criar um valor padrão para
|W_INTERNAL_MEMORY| como sendo 1/10000 de |W_MAX_MEMORY|, but not less
than 16 KB:

@(project/src/weaver/conf_end.h@>+=
#ifndef W_MAX_MEMORY
#warning "W_MAX_MEMORY not defined at conf/conf.h. Assuming the smallest value possible"
#define W_MAX_MEMORY 1
#endif
#ifndef W_INTERNAL_MEMORY
#define W_INTERNAL_MEMORY \
  (((W_MAX_MEMORY)/10000>16384)?((W_MAX_MEMORY)/10000):(16384))
#endif
#if !defined(W_WEB_MEMORY) && W_TARGET == W_ELF
#warning "W_WEB_MEMORY not defined at conf/conf.h."
#endif
#ifndef W_MAX_SUBLOOP
#warning "W_MAX_SUBLOOP not defined at conf/conf.h. Assuming 1."
#define W_MAX_SUBLOOP 1
#endif
@
  
@*1 Estruturas de Dados Usadas.

Vamos considerar primeiro uma \negrito{arena}. Toda \negrito{arena} terá
a seguinte estrutura:

\alinhaverbatim
+-----------+------------+-------------------------+-------------+
| Cabeçalho | Breakpoint | Breakpoints e alocações | Não alocado |
+-----------+------------+-------------------------+-------------+
\alinhanormal

A terceira região é onde toda a ação de alocação e liberação de
memória ocorrerá. No começo estará vazia e a área não-alocada será a
maioria. À medida que alocações e desalocações ocorrerem, a região de
alocação e \italico{breakpoints} crescerá e diminuirá, sempre
substituindo o espaço não-alocado ao crescer. O cabeçalho
e \italico{breakpoint} inicial sempre existirão e não poderão ser
removidos. O primeiro \italico{breakpoint} é útil para que o comando
|Wtrash| sempre funcione e seja definido, pois sempre existirá um
último \italico{breakpoint}.

A memória pode ser vista de três formas diferentes:

1) Como uma pilha que cresce da última alocação até a região
não-alocada. Sempre que uma nova alocação é feita, ela será colocada
imediatamente após a última alocação feita. Se memória for desalocada,
caso a memória em questão esteja no fim da pilha, ela será
efetivamente liberada. Caso contrário, será marcada para ser removida
depois, o que infelizmente pode gerar fragmentação se o usuário não
tomar cuidado.

2) Como uma lista duplamente encadeada. Cada \italico{breakpoint} e
região alocada terá ponteiros para a próxima região e para a região
anterior (ou para |NULL|). Desta forma, pode-se percorrer rapidamente
em uma iteração todos os elementos da memória.

3) Como uma árvore. Cada elemento terá um ponteiro para o
último \italico{breakpoint}. Desta forma, caso queiramos descartar a
memória alocada até encontrarmos o último \italico{breakpoint},
podemos consultar este ponteiro.

@*2 Cabeçalho da Arena.

O cabeçalho conterá todas as informações que precisamos para usar a
arena. Chamaremos sua estrutura de dados de |struct arena_header|.

O tamanho total da arena nunca muda. O cabeçalho e primeiro breakpoint
também tem tamanho constante. A região de breakpoint e alocações pode
crescer e diminuir, mas isso sempre implica que a região não-alocada
respectivamente diminui e cresce na mesma proporção.

As informações encontradas no cabeçalho são:

\macronome \negrito{Total:} A quantidade total em bytes de memória que a
  arena possui. Como precisamos garantir que ele tenha um tamanho
  suficientemente grande para que alcance qualquer posição que possa
  ser alcançada por um endereço, ele precisa ser um |size_t|. Pelo
  padrão ISO isso será no mínimo 2 bytes, mas em computadores pessoais
  atualmente está chegando a 8 bytes.

  Esta informação será preenchida na inicialização da arena e nunca
  mais será mudada.

\macronome \negrito{Usado:} A quantidade de memória que já está em uso nesta
  arena. Isso nos permite verificar se temos espaço disponível ou não
  para cada alocação. Pelo mesmo motivo do anterior, precisa ser um
  |size_t|. Esta informação precisará ser atualizada toda vez que mais
  memória for alocada ou desalocada. Ou quando um \italico{breakpoint}
  for criado ou destruído.

\macronome \negrito{Último Breakpoint:} Armazenar isso nos permite saber à
  partir de qual posição podemos começar a desalocar memória em caso
  de um |Wtrash|. Outro |size_t|. Eta informação precisa ser
  atualizada toda vez que um \italico{breakpoint} for criado ou
  destruído. Um último breakpoint sempre existirá, pois o primeiro
  breakpoint nunca pode ser removido.

\macronome \negrito{Último Elemento:} Endereço do último elemento
  que foi armazenado. É útil guardar esta informação porque quando
  criamos um novo elemento com |Walloc| ou |Wbreakpoint|, o novo
  elemento precisa apontar para o último que havia antes dele. Esta
  informação precisa ser atualizada após qualquer operação de
  alocação, desalocação ou \italico{breakpoint}. Sempre existirá um
  último elemento na arena, pois se nada foi alocado um primeiro
  breakpoint sempre estará posicionado após o cabeçalho e este será
  nosso último elemento.

\macronome\negrito{Posição Vazia:} Um ponteiro para a próxima região
  contínua de memória não-alocada. É preciso saber disso para podermos
  criar novas estruturas e retornar um espaço ainda não-utilizado em
  caso de |Walloc|. Outro |size_t|. Novamente é algo que precisa ser
  atualizado após qualquer uma das operações de memória sobre a
  arena. É possível que não hajam mais regiões vazias caso tudo já
  tenha sido alocado. Neste caso, o ponteiro deverá ser |NULL|.

\macronome \negrito{Mutex:} Opcional. Só precisamos definir isso se
  estivermos usando mais de uma thread. Neste caso, o mutex servirá
  para prevenir que duas threads tentem modificar qualquer um destes
  valores ao mesmo tempo. Caso seja usado, o mutex precisa ser usado
  em qualquer operação de memória, pois todas elas precisam modificar
  elementos da arena. Em máquinas testadas, isso gasta cerca de 40
  bytes se usado.

\macronome \negrito{Uso Máximo:} Opcional. Só precisamos definir isso se
  estamos rodando o programa em um nível alto de depuração e por isso
  queremos saber ao fim do uso da arena qual a quantidade máxima de
  memória que alocamos nela ao longo da execução do programa. Desta
  forma, se nosso programa sempre disser que usamos uma quantidade
  pequena demais de memória, podemos ajustar o valor para alocar menos
  memória. Ou se chegarmos perto demais do valor máximo de alocação,
  podemos mudar o valor ou depurar o programa para gastarmos menos
  memória. Se estivermos monitorando o valor, precisamos verificar se
  ele precisa ser atualizado após qualquer alocação ou criação
  de \negrito{breakpoint}.

\macronome \negrito{Nome de Arquivo: }Opcional. Nome do arquivo onde a
arena é criada para podermos imprimir mensagens úteis para depuração.

\macronome \negrito{Linha: }Opcional. Número da linha em que a arena é
criada. Informação usada apenas para imprimir mensagens de depuração.

Caso usemos todos estes dados, nosso cabeçalho de memória ficará com
cerca de 124 bytes em máquinas típicas. Nosso cabeçalho de arena terá
então a seguinte definição na linguagem C:

@<Declarações de Memória@>+=
struct _arena_header{
  size_t total, used;
  struct _breakpoint *last_breakpoint;
  void *empty_position, *last_element;
#if W_DEBUG_LEVEL >= 1
  char file[32];
  unsigned long line;
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_t mutex;
#endif
#if W_DEBUG_LEVEL >= 3
  size_t max_used;
#endif
};
@

Pela definição, existem algumas restrições sobre os valores presentes
em cabeçalhos de arena. Vamos criar um código de depuração para testar
que qualquer uma destas restrições não é violada:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 4
void _assert__arena_header(struct _arena_header *);
#endif
@

@(project/src/weaver/memory.c@>=
#if W_DEBUG_LEVEL >= 4
void _assert__arena_header(struct _arena_header *header){
  // O espaço máximo disponível na arena sempre deve ser maior ou
  // igual ao máximo que já armazenamos nela.
  if(header -> total < header -> max_used){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header used more memory than allowed!\n");
    exit(1);
  }
  // Já o máximo que já armazenamos deve ser maior ou igual ao que
  // estamos armazenando no instante atual (pela definição de
  // 'máximo')
  if(header -> max_used < header -> used){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header not registering max usage!\n");
    exit(1);
  }
  // O último breakpoint é o último elemento ou está antes do último
  // elemento. Já que breakpoints são elementos, mas há outros
  // elementos além de breakpoints.
  if((void *) header -> last_element < (void *) header -> last_breakpoint){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header storing in wrong location!\n");
    exit(1);
  }
  // O espaço não-alocado não existe ou fica depois do último elemento
  // alocado.
  if(!(header -> empty_position == NULL ||
       (void *) header -> empty_position > (void *) header -> last_element)){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header confused about empty position!\n");
    exit(1);
  }
  // Toda arena ocupa algum espaço, nem que sejam os bytes gastos pelo
  // cabeçalho.
  if(header -> used <= 0){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header not occupying space!\n");
    exit(1);
  }
}
#endif
@

Quando criamos a arena e desejamos inicializar o valor de seu
cabeçalho, tudo o que precisamos saber é o tamanho total que a arena
tem, o nome od arquivo e número de linha. Os demais valores podem ser
deduzidos. Portanto, podemos usar esta função interna para a tarefa:

@(project/src/weaver/memory.c@>+=
static bool _initialize_arena_header(struct _arena_header *header,
                                     size_t total
#if W_DEBUG_LEVEL >= 1
                                     , char *filename,unsigned long line
#endif
                                     ){
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
#if W_DEBUG_LEVEL >= 1
  header -> line = line;
  strncpy(header -> file, filename, 31);
#endif
#if W_DEBUG_LEVEL >= 3
  header -> max_used = header -> used;
#endif
#if W_DEBUG_LEVEL >= 4
  _assert__arena_header(header);
#endif
  return true;
}
@

É importante notar que tal função de inicialização só pode falhar se
ocorrer algum erro inicializando o mutex. Por isso podemos representar
o seu sucesso ou fracasso fazendo-a retornar um valor booleano.

@*2 Breakpoints.

A função primária de um breakpoint é interagir com as função
|Wbreakpoint| e |Wtrash|. As informações que devem estar presentes
nele são:

\macronome \negrito{Tipo:} Um número mágico que corresponde sempre à um valor
  que identifica o elemento como sendo um \italico{breakpoint}, e não
  um fragmento alocado de memória. Se o elemento realmente for um
  breakpoint e não possuir um número mágico correspondente, então
  ocorreu um \italico{buffer overflow} em memória alocada e podemos
  acusar isso. Definiremos tal número como |0x11010101|.

\macronome \negrito{Último breakpoint:} No caso do primeiro breakpoint, isso
  deve apontar para ele próprio (e assim o primeiro breakpoint pode
  ser identificado diante dos demais). nos demais casos, ele irá
  apontar para o breakpoint anterior. Desta forma, em caso de
  |Wtrash|, poderemos restaurar o cabeçalho da arena para apontar para
  o breakpoint anterior, já que o atual está sendo apagado.

\macronome \negrito{Último Elemento:} Para que a lista de elementos de uma
  arena possa ser percorrida, cada elemento deve ser capaz de apontar
  para o elemento anterior. Desta forma, se o breakpoint for removido,
  podemos restaurar o último elemento da arena para o elemento antes
  dele (assumindo que não tenha sido marcado para remoção como será
  visto adiante). O último elemento do primeiro breakpoint é ele próprio.

\macronome \negrito{Arena:} Um ponteiro para a arena à qual pertence a
  memória.

\macronome \negrito{Tamanho:} A quantidade de memória alocada até o
  breakpoint em questão. Quando o breakpoint for removido, a
  quantidade de memória usada pela arena passa a ser o valor presente
  aqui.

\macronome \negrito{Arquivo:} Opcional para depuração. O nome do arquivo onde
  esta região da memória foi alocada.

\macronome \negrito{Linha:} Opcional para depuração. O número da linha onde
  esta região da memória foi alocada.

Sendo assim, a nossa definição de breakpoint é:

@<Declarações de Memória@>+=
struct _breakpoint{
  unsigned long type;
#if W_DEBUG_LEVEL >= 1
  char file[32];
  unsigned long line;
#endif
  void *last_element;
  struct _arena_header *arena;
  // Todo elemento dentro da memória (breakpoints e cabeçalhos de
  // memória) terão os 5 campos anteriores no mesmo local. Desta
  // forma, independente deles serem breakpoints ou regiões alocadas,
  // sempre será seguro usar um casting para qualquer um dos tipos e
  // consultar qualquer um dos 5 campos anteriores. O campo abaixo,
  // 'last_breakpoint', por outro lado, só pode ser consultado por
  // breakpoints.
  struct _breakpoint *last_breakpoint;
  size_t size;
};
@

Se todos os elementos estiverem presentes, espera-se que
um \italico{breakpoint} tenha por volta de 72 bytes. Naturalmente, isso
pode variar dependendo da máquina.

As seguintes restrições sempre devem valer para tais dados:

a) $\italico{type} = 0{\times}11010101$. Mas é melhor declarar uma
macro para não esquecer o valor:

@<Declarações de Memória@>+=
#define _BREAKPOINT_T  0x11010101
@

b) $\italico{last\_breakpoint}\leq\italico{last\_element}$.

Vamos criar uma função de depuração que nos ajude a checar por tais
erros. O caso do tipo de um \italico{breakpoint} não casar com o valor
esperado é algo possível de acontecer principalmente devido
à \italico{buffer overflows} causados devido à erros do programador
que usa a API. Por causa disso, teremos que ficar de olho em tais
erros quando |W_DEBUG_LEVEL >= 1|, não penas quando |W_DEBUG_LEVEL >= 4|.
Esta é a função que checa um \italico{breakpoint} por erros:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
void _assert__breakpoint(struct _breakpoint *);
#endif
@

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
void _assert__breakpoint(struct _breakpoint *breakpoint){
  if(breakpoint -> type != _BREAKPOINT_T){
    fprintf(stderr,
            "ERROR (1): Probable buffer overflow. We can't guarantee a "
            "reliable error message in this case. But the "
            "data where the buffer overflow happened may be "
            "the place allocated at %s:%lu or before.\n",
            ((struct _breakpoint *)
              breakpoint -> last_element) -> file,
            ((struct _breakpoint *)
              breakpoint -> last_element) -> line);
    exit(1);
  }
#if W_DEBUG_LEVEL >= 4
  if((void *) breakpoint -> last_breakpoint >
                          (void *) breakpoint -> last_element){
    fprintf(stderr, "ERROR (4): MEMORY: Breakpoint's previous breakpoint "
                    "found after breakpoint's last element.\n");
    exit(1);
  }
#endif
}
#endif
@

Vamos agora cuidar de uma função para inicializar os valores de um
breakpoint. Para isso vamos precisar saber o valor de todos os
elementos, exceto o |type| e o tamanho que pode ser deduzido pela
arena:

@(project/src/weaver/memory.c@>+=
static void _initialize_breakpoint(struct _breakpoint *self,
                                   void *last_element,
                                   struct _arena_header *arena,
                                   struct _breakpoint *last_breakpoint
#if W_DEBUG_LEVEL >= 1
                                   , char *file, unsigned long line
#endif
                                   ){
  self -> type = _BREAKPOINT_T;
  self -> last_element = last_element;
  self -> arena = arena;
  self -> last_breakpoint = last_breakpoint;
  self -> size = arena -> used - sizeof(struct _breakpoint);
#if W_DEBUG_LEVEL >= 1
  strncpy(self -> file, file, 32);
  self -> line = line;
  _assert__breakpoint(self);
#endif
}
@

Notar que assumimos que quando vamos inicializar um breakpoint, todos
os dados do cabeçalho da arena já foram atualizados como tendo o
breakpoint já existente. E como consultamos tais dados, o mutex da
arena precisa estar bloqueado para que coisas como o tamanho da arena
não mudem.

O primeiro dos breakpoints é especial e pode ser inicializado como
abaixo. Para ele não precisamos nos preocupar em armazenar o nome de
arquivo e número de linha em que é definido.

@(project/src/weaver/memory.c@>+=
static void _initialize_first_breakpoint(struct _breakpoint *self,
                                         struct _arena_header *arena){
#if W_DEBUG_LEVEL >= 1
  _initialize_breakpoint(self, self, arena, self, "", 0);
#else
  _initialize_breakpoint(self, self, arena, self);
#endif
}
@

@*2 Memória alocada.

Por fim, vamos à definição da memória alocada. Ela é formada
basicamente por um cabeçalho, o espaço alocado em si e uma
finalização. No caso do cabeçalho, precisamos dos seguintes elementos:

\macronome \negrito{Tipo:} Um número que identifica o elemento como um
  cabeçalho de dados, não um breakpoint. No caso, usaremos o número
  mágico 0$\times$10101010. Para não esquecer, é melhor definir uma
  macro para se referir à ele:

@<Declarações de Memória@>+=
#define _DATA_T        0x10101010
@

\macronome \negrito{Tamanho Real:} Quantos bytes tem a região alocada para
  dados. É igual ao tamanho pedido mais alguma quantidade adicional de
  bytes de preenchimento para podermos manter o alinhamento da
  memória.

\macronome\negrito{Tamanho Pedido:} Quantos bytes foram pedidos na alocação,
  ignorando o preenchimento.

\macronome\negrito{Último Elemento:} A posição do elemento anterior da
 arena. Pode ser outro cabeçalho de dado alocado ou um
  breakpoint. Este ponteiro nos permite acessar os dados como uma
  lista encadeada.

\macronome\negrito{Arena:} Um ponteiro para a arena à qual pertence a
  memória.
\negrito{Flags:} Permite que coloquemos informações adicionais. o
  último bit é usado para definir se a memória foi marcada para ser
  apagada ou não.

\macronome \negrito{Arquivo:} Opcional para depuração. O nome do arquivo onde
  esta região da memória foi alocada.

\macronome \negrito{Linha:} Opcional para depuração. O número da linha onde
  esta região da memória foi alocada.

A definição de nosso cabeçalho de dados é:

@<Declarações de Memória@>+=
struct _memory_header{
  unsigned long type;
#if W_DEBUG_LEVEL >= 1
  char file[32];
  unsigned long line;
#endif
  void *last_element;
  struct _arena_header *arena;
  // Os campos acima devem ser idênticos aos 5 primeiros do 'breakpoint'
  size_t real_size, requested_size;
  unsigned long flags;
};
@

Notar que as seguintes restrições sempre devem ser verdadeiras para
este cabeçalho de região alocada:

a) $\italico{type} = 0{\times}10101010$. Ou significa que ocorreu
um \italico{buffer overflow}.

b) $\italico{real\_size}\geq\italico{requested\_size}$. A quantidade
de bytes de preenchimento é no mínimo zero. Não iremos alocar um valor
menor que o pedido.

A função que irá checar a integridade de nosso cabeçalho de memória é:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
void _assert__memory_header(struct _memory_header *);
#endif
@

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
void _assert__memory_header(struct _memory_header *mem){
  if(mem -> type != _DATA_T){
    fprintf(stderr,
            "ERROR (1): Probable buffer overflow. We can't guarantee a "
            "reliable error message in this case. But the "
            "data where the buffer overflow happened may be "
            "the place allocated at %s:%lu or before.\n",
            ((struct _memory_header *)
              mem -> last_element) -> file,
            ((struct _memory_header *)
              mem -> last_element) -> line);
    exit(1);
  }
#if W_DEBUG_LEVEL >= 4
  if(mem -> real_size < mem -> requested_size){
    fprintf(stderr,
            "ERROR (4): MEMORY: Allocated less memory than requested in "
            "data allocated in %s:%lu.\n", mem -> file, mem -> line);
    exit(1);
  }
#endif
}
#endif
@

Não criaremos uma função de inicialização para este cabeçalho. Ele
será inicializado dentro da função que aloca mais espaço na
memória. Ao contrário de outros cabeçalhos, não há nenhuma facilidade
em criar um inicializador para este, pois todos os dados a serem
inicializados precisam ser passados explicitamente. Nada pode ser
meramente deduzido, exceto o |real_size|. Mas de qualquer forma o
|real_size| precisa ser calculado antes do preenchimento do cabeçalho,
para atualizar o cabeçalho da própria arena.

@*1 Criando e destruindo arenas.

Criar uma nova arena envolve basicamente alocar memória usando |mmap|
e tomando o cuidado para alocarmos sempre um número múltiplo do
tamanho de uma página (isso garante alinhamento de memória e também
nos dá um tamanho ótimo para paginarmos). Em seguida preenchemos o
cabeçalho da arena e colocamos o primeiro breakpoint nela.

A função que cria novas arenas deve receber como argumento o tamanho
mínimo que ela deve ter em bytes. Já destruir uma arena requer um
ponteiro para ela:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
  // Se estamos em modo de depuração, a função precisa estar ciente do
  // nome do arquivo e linha em que é invocada:
void *_Wcreate_arena(size_t size, char *filename, unsigned long line);
#else
void *_Wcreate_arena(size_t size);
#endif
int Wdestroy_arena(void *);
@

@*2 Criando uma arena.

O processo de criar a arena funciona alocando todo o espaço de que
precisamos e em seguida preenchendo o cabeçalho inicial e breakpoint:

@(project/src/weaver/memory.c@>+=
// Os argumentos que a função recebe são diferentes no modo de
// depuração e no modo final:
#if W_DEBUG_LEVEL >= 1
void *_Wcreate_arena(size_t size, char *filename, unsigned long line){
#else
void *_Wcreate_arena(size_t size){
#endif
  void *arena;
  size_t real_size = 0;
  struct _breakpoint *breakpoint;
  // Aloca arena calculando seu tamanho verdadeiro à partir do tamanho pedido:
  long page_size = sysconf(_SC_PAGESIZE);
  real_size = ((int) ceil((double) size / (double) page_size)) * page_size;
  arena = mmap(0, real_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS,
               -1, 0);
  if(arena == MAP_FAILED)
    arena = NULL; // Se algo falha, retornamos NULL
  if(arena != NULL){
    if(!_initialize_arena_header((struct _arena_header *) arena, real_size
#if W_DEBUG_LEVEL >= 1
  ,filename, line // Dois argumentos a mais em modo de depuração
#endif
  )){
      // Se não conseguimos inicializar o cabeçalho da arena,
      // desalocamos ela com munmap:
      munmap(arena, ((struct _arena_header *) arena) -> total);
      // O munmap pode falhar, mas não podemos fazer nada à este
      // respeito.
      return NULL;
    }
    // Preenchendo o primeiro breakpoint
    breakpoint = ((struct _arena_header *) arena) -> last_breakpoint;
    _initialize_first_breakpoint(breakpoint, (struct _arena_header *) arena);
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
#endif
  }
  return arena;
}
@

Então usar esta função nos dá como retorno |NULL| ou um ponteiro
para uma nova arena cujo tamanho total é no mínimo o pedido como
argumento, mas talvez seja maior por motivos de alinhamento e
paginação. Partes desta região contínua serão gastos com cabeçalhos da
arena, das regiões alocadas e \italico{breakpoints}. Então pode ser que
obtenhamos como retorno uma arena onde caibam menos coisas do que
caberia no tamanho especificado como argumento.

O tamanho fnal que a arena terá para colocar todas as coisas será o
menor múltiplo de uma página do sistema que pode conter o tamanho
pedido.

Usamos |sysconf| para saber o tamanho da página e |mmap| para obter a
memória. Outra opção seria o |brk|, mas usar tal chamada de sistema
criaria conflito caso o usuário tentasse usar o |malloc| da biblioteca
padrão ou usasse uma função de biblioteca que usa internamente o
|malloc|. Como até um simples |sprintf| usa |malloc|, não é prático
usar o |brk|, pois isso criaria muitos conflitos com outras
bibliotecas.

Agora vamos declarar e inicializara função de criar arenas dentro da
variável |W| que conterá nossas variáveis e funções globais:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
#if W_DEBUG_LEVEL >= 1
void *(*create_arena)(size_t, char *, unsigned long);
#else
void *(*create_arena)(size_t);
#endif
@

@<API Weaver: Inicialização@>=
W.create_arena = &_Wcreate_arena;
@

Mas na prática, teremos que usar sempre a seguinte macro para criar
arenas, pois o número de argumentos de |W.create_arena| pode variar de
acordo com o nível de depuração:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
  // Se estamos em modo de depuração, a função precisa estar ciente do
  // nome do arquivo e linha em que é invocada:
#define Wcreate_arena(a) W.create_arena(a, __FILE__, __LINE__)
#else
#define Wcreate_arena(a) W.create_arena(a)
#endif
@

@*2 Checando vazamento de memória em uma arena.

Uma das grandes vantagens de estarmos cuidando do gerenciamento de
memória é podermos checar a existência de vazamentos de memória no fim
do programa. Recapitulando, uma arena de memória ao ser alocada
conterá um cabeçalho de arena, um \italico{breakpoint} inicial e por
fim, tudo aquilo que foi alocada nela (que podem ser dados de memória
ou outros \italico{breakpoints}). Sendo assim, se depois de alocar
tudo com o nosso |Walloc| (que ainda iremos definir) nós desalocarmos
com o nosso |Wfree| ou |Wtrash| (que também iremos definir), no fim a
arena ficará vazia sem nada após o
primeiro \italico{breakpoint}. Exatamente como quando a arena é
recém-criada.

Então podemos inserir código que checa para nós se isso realmente é
verdade e que pode ser invocado sempre antes de destruirmos uma
arena. Se encontrarmos coisas na memória, isso significa que o usuário
alocou memória e não desalocou. Caberá ao nosso código então imprimir
uma mensagem de depuração informando do vazamento de memória e dizendo
em qual arquivo e número de linha ocorreu a tal alocação.

A função que fará isso para nós será:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
void _assert_no_memory_leak(void *);
#endif
@

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
void _assert_no_memory_leak(void *arena){
  struct _arena_header *header = (struct _arena_header *) arena;
  // Primeiro vamos para o último elemento da arena
  struct _memory_header *p = (struct _memory_header *) header -> last_element;
  // E vamos percorrendo os elementos de trás pra frente imprimindo
  // mensagem de depuração até chegarmos no breakpoint inicial (que
  // aponta para ele mesmo como último breakpoint):
  while(p -> type != _BREAKPOINT_T ||
        ((struct _breakpoint *) p) -> last_breakpoint !=
        (struct _breakpoint *) p){
    if(p -> type == _DATA_T && p -> flags % 2){
      fprintf(stderr, "WARNING (1): Memory leak in data allocated in %s:%lu\n",
              p -> file, p -> line);
    }
    p = (struct _memory_header *) p -> last_element;
  }
}
#endif
@

Esta função será usada automaticamente desde que estejamos compilando
uma versão de desenvolvimento do jogo. Entretanto, não há nenhum modo
de realmente garantirmos que toda arena criada será destruída. Se ela
não for, independente dela conter ou não coisas ainda alocadas, isso
será um vazamento não-detectado.

@*2 Destruindo uma arena.

Destruir uma arena é uma simples questão de finalizar o seu mutex caso
estejamos criando um programa com muitas threads e usar um
|munmap|. Também é quando invocamos a checagem por vazamento de
memória e dependendo do nível da depuração, podemos imprimir também a
quantidade máxima de memória usada:

@(project/src/weaver/memory.c@>+=
int Wdestroy_arena(void *arena){
#if W_DEBUG_LEVEL >= 1
  _assert_no_memory_leak(arena);
#endif
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
#endif
#if W_DEBUG_LEVEL >= 3
  fprintf(stderr,
          "WARNING (3): Max memory used in arena %s:%lu: %lu/%lu\n",
          ((struct _arena_header *) arena) -> file,
          ((struct _arena_header *) arena) -> line,
          (unsigned long) ((struct _arena_header *) arena) -> max_used,
          (unsigned long) ((struct _arena_header *) arena) -> total);
#endif
#ifdef W_MULTITHREAD
  {
    struct _arena_header *header = (struct _arena_header *) arena;
    if(pthread_mutex_destroy(&(header -> mutex)) != 0)
      return 0;
  }
#endif
  //Desaloca 'arena'
  if(munmap(arena, ((struct _arena_header *) arena) -> total) == -1)
    arena = NULL;
  if(arena == NULL) return 0;
  else return 1;
}
@

Assim como fizemos com a função de criar arenas, vamos colocar a
função de destruição de arenas na estrutura |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
int (*destroy_arena)(void *);
@

@<API Weaver: Inicialização@>=
W.destroy_arena = &Wdestroy_arena;
@


@*1 Alocação e desalocação de memória.

Agora chegamos à parte mais usada de um gerenciador de memórias:
alocação e desalocação. A função de alocação deve receber um ponteiro
para a arena onde iremos alocar e qual o tamanho a ser alocado.  A
função de desalocação só precisa receber o ponteiro da região a ser
desalocada, pois informações sobre a arena serão encontradas em seu
cabeçalho imediatamente antes da região de uso da memória.  Dependendo
do nível de depuração, ambas as funções precisam também saber de que
arquivo e número de linha estão sendo invocadas e isso justifica o
forte uso de macros abaixo:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
  void *_alloc(void *arena, size_t size, char *filename, unsigned long line);
#else
  void *_alloc(void *arena, size_t size);
#endif
#if W_DEBUG_LEVEL >= 2 && !defined(W_MULTITHREAD)
  void _free(void *mem, char *filename, unsigned long line);
#else
  void _free(void *mem);
#endif
@

Ao alocar memória, precisamos ter a preocupação de manter um
alinhamento de bytes para não prejudicar o desempenho. Por causa
disso, às vezes precisamos alocar mais que o pedido. Por exemplo, se o
usuário pede para alocar somente 1 byte, podemos precisar alocar 3
bytes adicionais além dele só para manter o alinhamento de 4 bytes de
dados. O tamanho que usamos como referência para o alinhamento é o
tamanho de um |long|. Sempre alocamos valores múltiplos de um |long|
que sejam suficientes para conter a quantidade de bytes pedida.

Se estamos trabalhando com múltiplas threads, precisamos também
garantir que o mutex da arena em que estamos seja bloqueado, pois
temos que mudar valores da arena para indicar que estamos ocupando
mais espaço nela.

Por fim, se tudo deu certo basta preenchermos o cabeçalho da região de
dados da arena que estamos criando. E ao retornar, retornaremos um
ponteiro para o início da região que o usuário pode usar para
armazenamento (e não da região que contém o cabeçalho). Se alguma
coisa falhar (pode não haver mais espaço suficiente na arena)
precisamos retornar |NULL| e dependendo do nível de depuração,
imprimimos uma mensagem de aviso.

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
void *_alloc(void *arena, size_t size, char *filename, unsigned long line){
#else
void *_alloc(void *arena, size_t size){
#endif
  struct _arena_header *header = arena;
  struct _memory_header *mem_header;
  void *mem = NULL, *old_last_element;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
#endif
  mem_header = header -> empty_position;
  old_last_element = header -> last_element;
  // Calcular o verdadeiro tamanho múltiplo de 'long' a se alocar:
  size_t real_size = (size_t) (ceil((float) size / (float) sizeof(long)) *
                               sizeof(long));
  if(header -> used + real_size + sizeof(struct _memory_header) >
     header -> total){
    // Chegamos aqui neste 'if' se não há memória suficiente
#if W_DEBUG_LEVEL >= 1
    fprintf(stderr, "WARNING (1): No memory enough to allocate in %s:%lu.\n",
      filename, line);
#endif
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(header -> mutex));
#endif
    return NULL;
  }
  // Atualizando o cabeçalho da arena
  header -> used += real_size + sizeof(struct _memory_header);
  mem = (void *) ((char *) header -> empty_position +
                  sizeof(struct _memory_header));
  header -> last_element = header -> empty_position;
  header -> empty_position = (void *) ((char *) mem + real_size);
#if W_DEBUG_LEVEL >= 3
  // Se estamos tomando nota do máximo de memória que usamos:
  if(header -> used > header -> max_used)
    header -> max_used = header -> used;
#endif
  // Preenchendo o cabeçalho do dado a ser alocado. Este cabeçalho
  // fica imediatamente antes do local cujo ponteiro retornamos para o
  // usuário usar:
  mem_header -> type = _DATA_T;
  mem_header -> last_element = old_last_element;
  mem_header -> real_size = real_size;
  mem_header -> requested_size = size;
  mem_header -> flags = 0x1;
  mem_header -> arena = arena;
#if W_DEBUG_LEVEL >= 1
  strncpy(mem_header -> file, filename, 32);
  mem_header -> line = line;
  _assert__memory_header(mem_header);
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
  return mem;
}
@

Para terminar o processo de alocação de memória, vamos coocar a função
de alocação em |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
#if W_DEBUG_LEVEL >= 1
void *(*alloc_arena)(void *, size_t, char *, unsigned long);
#else
void *(*alloc_arena)(void *, size_t);
#endif
@

@<API Weaver: Inicialização@>=
W.alloc_arena = &_alloc;
@

Na prática usaremos a função na forma da seguinte macro, já que o número de
argumentos de |W.alloc_arena| pode variar com o nível de depuração:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
#define Walloc_arena(a, b) W.alloc_arena(a, b, __FILE__, __LINE__)
#else
#define Walloc_arena(a, b) W.alloc_arena(a, b)
#endif
@

Para desalocar a memória, existem duas possibilidades. Podemos estar
desalocando a última memória alocada ou não. No primeiro caso, tudo é
uma questão de atualizar o cabeçalho da arena modificando o valor do
último elemento armazenado e também um ponteiro pra o próximo espaço
vazio. No segundo caso, tudo o que fazemos é marcar o elemento para
ser desalocado no futuro sem desalocá-lo de verdade no momento.

Não podemos desalocar sempre porque nosso espaço de memória é uma
pilha. Os elementos só podem ser desalocados de verdade na ordem
inversa em que são alocados. Quando isso não ocorre, a memória começa
a se fragmentar ficando com buracos internos que não podem ser usados
até que os elementos que vem depois não sejam também desalocados.

Isso pode parecer ruim, mas se a memória do projeto for bem-gerenciada
pelo programador, não chegará a ser um problema e ficamos com um
gerenciamento mais rápido. Se o programador preferir, ele tambéem pode
usar o |malloc| da biblioteca padrão para não ter que se preocupar com
a ordem de desalocações. Uma discussão sobre as consequências de cada
caso pode ser encontrada ao fim deste capítulo.

Se nós realmente desalocamos a memória, pode ser que antes dela
encontremos regiões que já foram marcadas para ser desalocadas, mas
ainda não foram. É neste momento em que realmente as desalocamos
eliminando a fragmentação naquela parte.

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 2 && !defined(W_MULTITHREAD)
void _free(void *mem, char *filename, unsigned long line){
#else
void _free(void *mem){
#endif
  struct _memory_header *mem_header = ((struct _memory_header *) mem) - 1;
  struct _arena_header *arena = mem_header -> arena;
  void *last_freed_element;
  size_t memory_freed = 0;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(arena -> mutex));
#endif
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
#endif
#if W_DEBUG_LEVEL >= 1
    _assert__memory_header(mem_header);
#endif
  // Primeiro checamos se não estamos desalocando a ultima memória. Se
  // não é a ultima memória, não precisamos manter o mutex ativo e
  // apenas marcamos o dado presente para ser desalocado no futuro.
  if((struct _memory_header *) arena -> last_element != mem_header){
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(arena -> mutex));
#endif
    mem_header -> flags = 0x0;
#if W_DEBUG_LEVEL >= 2 && !defined(W_MULTITHREAD)
  // Pode ser que tenhamos que imprimir um aviso de depuração acusando
  // desalocação na ordem errada:
    fprintf(stderr,
            "WARNING (2): %s:%lu: Memory allocated in %s:%lu should be"
            " freed first to prevent fragmentation.\n", filename, line,
            ((struct _memory_header *) (arena -> last_element)) -> file,
            ((struct _memory_header *) (arena -> last_element)) -> line);
#endif
    return;
  }
  // Se estamos aqui, esta é uma desalocação verdadeira. Calculamos
  // quanto espaço iremos liberar:
  memory_freed = mem_header -> real_size + sizeof(struct _memory_header);
  last_freed_element = mem_header;
  mem_header = mem_header -> last_element;
  // E também levamos em conta que podemos desalocar outras coisas que
  // tinham sido marcadas para ser desalocadas:
  while(mem_header -> type != _BREAKPOINT_T && mem_header -> flags == 0x0){
    memory_freed += mem_header -> real_size + sizeof(struct _memory_header);
    last_freed_element = mem_header;
    mem_header = mem_header -> last_element;
  }
  // Terminando de obter o tamanho total a ser desalocado e obter
  // novos valores para ponteiros, atualizamos o cabeçalho da arena:
  arena -> last_element = mem_header;
  arena -> empty_position = last_freed_element;
  arena -> used -= memory_freed;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(arena -> mutex));
#endif
}
@

E por fim, colocamos a nova função definida dentro da estrutura |W|:

@<Funções Weaver@>+=
// Esta declaração fica dentro de 'struct _weaver_struct{(...)} W;':
#if W_DEBUG_LEVEL >= 2 && !defined(W_MULTITHREAD)
void (*free)(void *, char *, unsigned long);
#else
void (*free)(void *);
#endif
@

@<API Weaver: Inicialização@>=
W.free = &_free;
@

Na prática usaremos sempre a seguinte macro, já que o número de
argumentos de |W.free| pode mudar:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 2 && !defined(W_MULTITHREAD)
#define Wfree(a) W.free(a, __FILE__, __LINE__)
#else
#define Wfree(a) W.free(a)
#endif
@

@*1 Usando a heap descartável.

Graças ao conceito de \italico{breakpoints}, pode-se desalocar ao mesmo
tempo todos os elementos alocados desde o último \italico{breakpoint}
por meio do |Wtrash|.  A criação de um \italico{breakpoit} e descarte
de memória até ele se dá por meio das funções declaradas abaixo:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
int _new_breakpoint(void *arena, char *filename, unsigned long line);
#else
int _new_breakpoint(void *arena);
#endif
void Wtrash_arena(void *arena);
@

As funções precisam receber como argumento apenas um ponteiro para a
arena na qual realizar a operação. Além disso, dependendo do nível de
depuração, elas recebem também o nome de arquivo e número de linha
como nos casos anteriores para que isso ajude na depuração:

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
int _new_breakpoint(void *arena, char *filename, unsigned long line){
#else
int _new_breakpoint(void *arena){
#endif
  struct _arena_header *header = (struct _arena_header *) arena;
  struct _breakpoint *breakpoint, *old_breakpoint;
  void *old_last_element;
  size_t old_size;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
#endif
  if(header -> used + sizeof(struct _breakpoint) > header -> total){
    // Se estamos aqui, não temos espaço para um breakpoint
#if W_DEBUG_LEVEL >= 1
    fprintf(stderr, "WARNING (1): No memory enough to allocate in %s:%lu.\n",
      filename, line);
#endif
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(header -> mutex));
#endif
    return 0;
  }
  // Atualizando o cabeçalho da arena e salvando valores relevantes
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
  if(header -> used > header -> max_used){ // Batemos récorde de uso?
    header -> max_used = header -> used;
  }
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
  breakpoint -> type = _BREAKPOINT_T; // Preenchendo cabeçalho do breakpoint
  breakpoint -> last_element = old_last_element;
  breakpoint -> arena = arena;
  breakpoint -> last_breakpoint = (void *) old_breakpoint;
  breakpoint -> size = old_size;
#if W_DEBUG_LEVEL >= 1
  strncpy(breakpoint -> file, filename, 32);
  breakpoint -> line = line;
#endif
#if W_DEBUG_LEVEL >= 4
  _assert__breakpoint(breakpoint);
#endif
  return 1;
}
@

Esta função de criação de \italico{breakpoints} em uma arena precis
ser colocada em |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
#if W_DEBUG_LEVEL >= 1
int (*breakpoint_arena)(void *, char *, unsigned long);
#else
int (*breakpoint_arena)(void *);
#endif
@

@<API Weaver: Inicialização@>=
W.breakpoint_arena = &_new_breakpoint;
@

Para sempre usarmos o número correto de argumentos, na prática
usaremos sempre a função acima na forma da macro:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
#define Wbreakpoint_arena(a) W.breakpoint_arena(a, __FILE__, __LINE__)
#else
#define Wbreakpoint_arena(a) W.breakpoint_arena(a)
#endif
@

E a função para descartar toda a memória presente na heap até o
último breakpoint é definida como:

@(project/src/weaver/memory.c@>+=
void Wtrash_arena(void *arena){
  struct _arena_header *header = (struct _arena_header *) arena;
  struct _breakpoint *previous_breakpoint =
    ((struct _breakpoint *) header -> last_breakpoint) -> last_breakpoint;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(header -> mutex));
#endif
#if W_DEBUG_LEVEL >= 4
    _assert__arena_header(arena);
    _assert__breakpoint(header -> last_breakpoint);
#endif
  if(header -> last_breakpoint == previous_breakpoint){
    // Chegamos aqui se existe apenas 1 breakpoint
    header -> last_element = previous_breakpoint;
    header -> empty_position = (void *) (previous_breakpoint + 1);
    header -> used = previous_breakpoint -> size + sizeof(struct _breakpoint);
  }
  else{
    // Chegamos aqui se há 2 ou mais breakpoints
    struct _breakpoint *last = (struct _breakpoint *) header -> last_breakpoint;
    header -> used = last -> size;
    header -> empty_position = last;
    header -> last_element = last -> last_element;
    header -> last_breakpoint = previous_breakpoint;
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(header -> mutex));
#endif
}
@

A função acima é totalmente inócua se não existem dados a serem
desalocados até o último \italico{breakpoint}. Neste caso ela
simplesmente apaga o \italico{breakpoint} se ele não for o único, e
não faz nada se existe apenas o \italico{breakpoint} inicial.

Vamos agora colocá-ladentro de |W|:

@<Funções Weaver@>+=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
void (*trash_arena)(void *);
@

@<API Weaver: Inicialização@>=
W.trash_arena = &Wtrash_arena;
@


@*1 Usando as arenas de memória padrão.

Ter que se preocupar com arenas geralmente é desnecessário. O usuário
pode querer simplesmente usar uma função |Walloc| sem ter que se
preocupar com qual arena usar. Weaver simplesmente assumirá a
existência de uma arena padrão e associada à ela as novas funções
|Wfree|, |Wbreakpoint| e |Wtrash|.

Primeiro precisaremos declarar duas variáveis globais. Uma delas será
uma arena padrão do usuário, a outra deverá ser uma arena usada pelas
funções internas da própria API. Ambas as variáveis devem ficar
restritas ao módulo de memória, então serão declaradas como estáticas:

@(project/src/weaver/memory.c@>+=
static void *_user_arena, *_internal_arena;
@

Noe que elas serão variáveis estáticas. Isso garantirá que somente as
funções que definiremos aqui poderão manipulá-las. Será impossível
mudá-las ou usá-las sem que seja usando as funções relacionadas ao
gerenciador de memória. Vamos precisar inicializar e finalizar estas
arenas com as seguinte funções:

@<Declarações de Memória@>+=
void _initialize_memory();
void _finalize_memory();
@

Que são definidas como:

@(project/src/weaver/memory.c@>+=
void _initialize_memory(void){
  _user_arena = Wcreate_arena(W_MAX_MEMORY);
  if(_user_arena == NULL){
    fprintf(stderr, "ERROR: This system have no enough memory to "
            "run this program.\n");
    exit(1);
  }
  _internal_arena = Wcreate_arena(W_INTERNAL_MEMORY);
  if(_internal_arena == NULL){
    fprintf(stderr, "ERROR: This system have no enough memory to "
            "run this program.\n");
    exit(1);
  }
}
void _finalize_memory(){
  Wdestroy_arena(_user_arena);
  Wtrash_arena(_internal_arena);
  Wdestroy_arena(_internal_arena);
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
_initialize_memory();
@

@<API Weaver: Finalização@>+=
// Primeiro a finalização das coisas antes de desalocar memória:
@<API Weaver: Encerramento@>
@<API Weaver: Som: Encerramento@>
// Só então podemos finalizar o gerenciador de memória:

_finalize_memory();
@

Agora para podermos alocar e desalocar memória da arena padrão e da
arena interna, criaremos a seguinte funções:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
void *_Walloc(size_t size, char *filename, unsigned long line);
void *_Winternal_alloc(size_t size, char *filename, unsigned long line);
#define _iWalloc(n) _Winternal_alloc(n, __FILE__, __LINE__)
#else
void *_Walloc(size_t size);
void *_Winternal_alloc(size_t size);
#define _iWalloc(n) _Winternal_alloc(n)
#endif
@

Destas o usuário irá usar mesmo a |Walloc|. A |_iWalloc| será usada
apenas internamente para usarmos a arena de alocações internas da
API. E precisamos que elas sejam definidas como funções, não como
macros para poderem manipular as arenas, que são variáveis estáticas à
este capítulo.


@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
void *_Walloc(size_t size, char *filename, unsigned long line){
  return _alloc(_user_arena, size, filename, line);
}
void *_Winternal_alloc(size_t size, char *filename, unsigned long line){
  return _alloc(_internal_arena, size, filename, line);
}
#else
void *_Walloc(size_t size){
  return _alloc(_user_arena, size);
}
void *_Winternal_alloc(size_t size){
  return _alloc(_internal_arena, size);
}
#endif
@

Adicionando alocação à variável |W|:

@<Funções Weaver@>+=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
#if W_DEBUG_LEVEL >= 1
void *(*alloc)(size_t, char *, unsigned long);
#else
void *(*alloc)(size_t);
#endif
@

@<API Weaver: Inicialização@>=
W.alloc = &_Walloc;
@

Embora na prática usaremos a função dentro da seguinte macro que cuida
do número de argumentos:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
#define Walloc(a) W.alloc(a, __FILE__, __LINE__)
#else
#define Walloc(a) W.alloc(a)
#endif
@

O |Wfree| já foi definido e irá funcionar sem problemas, independente
da arena à qual pertence o trecho de memória alocado. Sendo assim,
resta declarar apenas o |Wbreakpoint| e |Wtrash|:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
int _Wbreakpoint(char *filename, unsigned long line);
int _iWbreakpoint_(char *filename, unsigned long line);
#else
int _Wbreakpoint(void);
int _iWbreakpoint_(void);
#endif
void _Wtrash(void);
void _iWtrash(void);
@

A definição das funções segue abaixo:

@(project/src/weaver/memory.c@>+=
#if W_DEBUG_LEVEL >= 1
int _Wbreakpoint(char *filename, unsigned long line){
  return _new_breakpoint(_user_arena, filename, line);
}
int _iWbreakpoint_(char *filename, unsigned long line){
  return _new_breakpoint(_internal_arena, filename, line);
}
#else
int _Wbreakpoint_(void){
  return _new_breakpoint(_user_arena);
}
int _iWbreakpoint(void){
  return _new_breakpoint(_internal_arena);
}
#endif
void _Wtrash(void){
  Wtrash_arena(_user_arena);
}
void _iWtrash(void){
  Wtrash_arena(_internal_arena);
} 
@

E por fim as adicionamos à |W|:

@<Funções Weaver@>+=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
#if W_DEBUG_LEVEL >= 1
int (*breakpoint)(char *, unsigned long);
#else
int (*breakpoint)(void);
#endif
void (*trash)(void);
@

@<API Weaver: Inicialização@>=
W.breakpoint = &_Wbreakpoint;
W.trash = & _Wtrash;
@

E as macros que nos ajudam a cuidar do número de argumentos:

@<Declarações de Memória@>+=
#if W_DEBUG_LEVEL >= 1
#define Wbreakpoint() W.breakpoint(__FILE__, __LINE__)
#define _iWbreakpoint() _iWbreakpoint_(__FILE__, __LINE__)
#else
#define Wbreakpoint() W.breakpoint()
#define _iWbreakpoint() _iWbreakpoint_()
#endif
#define Wtrash() W.trash()
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

@(/tmp/dummy.c@>=
// Só um exemplo, não faz parte de Weaver
#include "game.h"
#define T 1000000

int main(int argc, char **argv){
  long i;
  void *m[T];
  Winit();
  W_TIMER_BEGIN();
  for(i = 0; i < T; i ++){
    m[i] = Walloc(1);
  }
  for(i = T-1; i >=0; i --){
    Wfree(m[i]);
  }
  Wtrash();
  W_TIMER_END();
  Wexit();
  return 0;
}
@


Rodando este código em um Pentium B980 2.40GHz Dual Core, este é o
gráfico que representa o teste de desempenho. As barras vermellhas
representam o uso de |Walloc|/|free| em diferentes níveis de depuração
(0 é o mais claro e 4 é o mais escuro). Para comparar, em azul podemos
ver o tempo gasto pelo |malloc|/|free| da biblioteca C GNU versão 2.20.

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 7mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 13mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 14mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 13mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 15mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 17mm width 23mm}
}

Isso nos mostra que se compilarmos nosso código sem nenhum recurso de
depuração (como o que é feito ao compilarmos a versão final), obtemos
um desempenho duas vezes mais rápido que do |malloc|.

E se alocássemos quantidades maiores que 1 byte?  O próximo gráfico
mostra este caso usando exatamente a mesma escala utilizada no gráfico
anterior. nele alocamos um milhão de fragmentos de 100 bytes cada um:

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 20mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 22mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 30mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 37mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 37mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 40mm width 23mm}
}

A diferença não é explicada somente pela diminuição da localidade
espacial dos dados acessados. Se diminuirmos o número de alocações
para somente dez mil, mantendo um total alocado de 1 MB, ainda assim o
|malloc| ficaria na mesma posição se comparado ao |Walloc|. O que
significa que alocando quantias maiores, o |malloc| é apenas
ligeiramente pior que o |Walloc| sem recursos de depuração. Mas a
diferença é apenas marginal.

E se ao invés de desalocarmos memória com |Wfree|, usássemos o
|Wtrash| para desalocar tudo de uma só vez? Presume-se que esta é uma
vantagem de nosso gerenciador, pois ele permite desalocar coisas em
massa por meio de um recurso de ``heap descartável''. O gráfico abaixo
mostra este caso para quando alocamos 1 milhão de espaços de 1 byte
usando a mesma escala do gráfico anterior:

\espaco{5mm}

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 5mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 10mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 10mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 10mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 11mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 15mm width 23mm}
}

O alto desempenho de nosso gerenciador de memória neste caso é
compreensível. Podemos substituir um milhão de chamadas para uma
função por uma só. Enquanto isso o |malloc| não tem esta opção e
precisa chamar uma função de desalocação para cada função de alocação
usada. E se usarmos isto para alocar 1 milhão de fragmentos de 100
bytes, o teste em que o |malloc| teve um desempenho semelhante ao
nosso? A resposta é o gráfico:

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 10mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 16mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 18mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 21mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 22mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 24mm width 23mm}
}

Via de regra podemos dizer que o desempenho do |malloc| é semelhante
ao do |Walloc| quando |W_DEBUG_MODE| é igual à 1. Mas quando o
|W_DEBUG_MODE| é zero, obtemos sempre um desempenho melhor (embora em
alguns casos a diferença possa ser marginal). Para analizar um caso em
que o |Walloc| realmente se sobressai, vamos observar o comportamento
quando compilamos o nosso teste de alocar 1 byte um milhão de vezes
para Javascript via Emscripten (versão 1.34). O gráfico à seguir
mostra este caso, mas usando uma escala diferente. Nele, as barras
estão dez vezes menores do que estariam se usássemos a mesma escala:

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 1mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 8mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 8mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 9mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 10mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 32mm width 23mm}
}

Enquanto o |Walloc| tem uma velocidade 1,8 vezes menor compilado com
Emscripten, o |malloc| tem uma velocidade 20 vezes menor. Se tentarmos
fazer no Emscripten o teste em que alocamos 100 bytes ao invés de 1
byte, o resultado reduzido em dez vezes fica praticamente igual ao
gráfico acima.

Este é um caso no qual o |Walloc| se sobressai. Mas há também um caso
em que o |Walloc| é muito pior: quando usamos várias
threads. Considere o código abaixo:

@(/tmp/dummy.c@>=
// Só um exemplo, não faz parte de Weaver
#define NUM_THREADS 10
#define T (1000000 / NUM_THREADS)

void *test(void *a){
  long *m[T];
  long i;
  for(i = 0; i < T; i ++){
    m[i] = (long *) Walloc(1);
    *m[i] = (long) m[i];
  }
  for(i = T-1; i >=0; i --){
    Wfree(m[i]);
  }
}

int main(void){
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
@

Neste caso, assumindo que estejamos compilando com a macro
|W_MULTITHREAD| no arquivo \monoespaco{conf/conf.h}, as threads
estarão sempre competindo pela arena e passarão boa parte do tempo
bloqueando umas às outras. O desempenho do |Walloc| e |malloc| neste
caso será:

\hbox{
\cor{0.0 0.0 1.0}{\vrule height 17mm width 23mm}
\cor{1.0 0.75 0.75}{\vrule height 45mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 120mm width 23mm}
\vbox to 70mm{\hbox to 70mm{Para |W_DEBUG_MODE| valendo dois e três, a}
\hbox to 70mm{barra torna-se vinte vezes maior do que a vista}
\hbox to 70mm{ao lado.\hfil}
\kern2mm
\hbox to 70mm{Para o nível quatro de depuração, a barra}
\hbox to 70mm{torna-se quarenta vezes maior que a vista ao}
\hbox to 70mm{lado.\hfil}\vfil}
}

Neste caso, o correto seria criar uma arena para cada thread com
|Wcreate_arena|, sempre fazer cada thread alocar dentro de sua arena
com |Walloc_arena|, criar \italico{breakpoints} com
|Wbreakpoint_arena|, desalocar com |Wfree_arena| e descartar a heap
até o último \italico{breakpoint} com |Wtrash_arena|. Por fim, cada
thread deveria finalizar sua arena com |Wdestroy_arena|. Assim
poderia-se usar o desempenho maior do |Walloc| aproveitando-o melhor
entre todas as threads. Pode nem ser necessário definir
|W_MULTITHREAD| se as threads forem bem especializadas e não
disputarem recursos.

A nova função de teste que usamos passa a ser:

@(/tmp/dummy.c@>=
// Só um exemplo, não faz parte de Weaver
void *test(void *a){
  long *m[T];
  long i;
  void *arena = Wcreate_arena(10000000);
  for(i = 0; i < T; i ++){
    m[i] = (long *) Walloc_arena(arena, 1);
    *m[i] = (long) m[i];
  }
  for(i = T-1; i >= 0; i --){
    Wfree(m[i]);
  }
  Wtrash_arena(arena);
  Wdestroy_arena(arena);
  return NULL;
}
@

Neste caso, o gráfico de desempenho em um computador com dois
processadores é:

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 6mm width 23mm}
\cor{1.0 0.6 0.6}{\vrule height 10mm width 23mm}
\cor{1.0 0.45 0.45}{\vrule height 10mm width 23mm}
\cor{1.0 0.2 0.2}{\vrule height 11mm width 23mm}
\cor{0.9 0.0 0.0}{\vrule height 11mm width 23mm}
\cor{0.0 0.0 1.0}{\vrule height 17mm width 23mm}
}

Infelizmente não poderemos fazer os testes de threads na compilação
via Emscripten. Até o momento, este é um recurso disponível somente no
Firefox Nightly.

Os testes nos mostram que embora o |malloc| da biblioteca C GNU seja
bem otimizado, é possível obter melhoras significativas em código
compilado via Emscripten e código feito para várias threads tendo um
gerenciador de memórias mais simples e personalizado. Isto e a
habilidade de detectar vazamentos de memória em modo de depuração é o
que justifica a criação de um gerenciador próprio para Weaver. Como a
prioridade em nosso gerenciador é a velocidade, o seu uso correto para
evitar fragmentação excessiva depende de conhecimento e cuidados
maiores por parte do programador. Por isso espera-se que programadores
menos experientes continuem usando o |malloc| enquanto o |Walloc| será
usado internamente pela nossa engine e estará à disposição daqueles
que querem pagar o preço por ter um desempenho maior, especialmente em
certos casos específicos.

@*1 O Coletor de Lixo.

O benefício de termos criado o nosso próprio gerenciador de memórias é
que podemos implementar um coletor de lixo para que o usuário não
precise usar manualmente as funções |Wfree| e |Wtrash|.

Usaremos um gerenciamento de memória baseada em regiões. Como
exemplificamos no começo deste capítulo, um jogo pode ser separado em
vários momentos. O vídeo de abertura, a tela inicial, bem como
diferentes regiões e momentos de jogo. Cada fase de um jogo de
plataforma seria também um momento. Bem como cada batalha e parte do
mapa em um RPG por turnos.

Em cada um destes momentos o jogo está em um loop principal. Alguns
momentos substituem os momentos anteriores. Como quando você sai da
tela de abertura para o jogo principal. Ou quando sai de uma fase para
a outra. Quando isso ocorre, podemos descartar toda a memória alocada
no momento anterior. Outros momentos apenas interrompem
temporariamente o momento que havia antes. Como as batalhas de um jogo
de RPG por turnos clássico. Quando a batalha começa não podemos jogar
fora a memória alocada no momento anterior, pois após a batalha
precisamos manter na memória todo o estado que havia antes. Por outro
lado, a memória alocada para a batalha pode ser jogada fora assim que
ela termina.

A Engine Weaver implementa isso por meio de funções |Wloop| e
|Wsubloop|. Ambas as funções recebem como argumento uma função que não
recebe argumentos do tipo |MAIN_LOOP|. Uma função deste tipo tem
sempre a seguinte forma:

@(/tmp/dummy.c@>=
// Exemplo. Não faz parte do Weaver.
MAIN_LOOP main_loop(void){
 LOOP_INIT:
  // Código a ser executado só na 1a iteração do loop principal
 LOOP_BODY:
  // Código a ser executado em toda iteração do loop principal
 LOOP_END:
  // Código a ser executado quando o loop se encerrar
}
@

O tipo |MAIN_LOOP| serve para explicitar que uma determinada função é
um loop principal e também nos dá a opção de implementar o valor de
retorno deste tipo de função de diferentes formas. Provavelmente ele
será sempre |void|, mas em futuras arquiteturas pode ser útil fazer
que tal função retorne um valor passando informações adicionais para a
\italico{engine}. Abaixo segue também como poderíamos implementar os
rótulos que delimitam a região de inicialização:

@<Cabeçalhos Weaver@>+=
typedef void MAIN_LOOP;
/*#define LOOP_INIT if(!_running_loop) _exit_loop(); if(!_running_loop)\
   goto _LOOP_FINALIZATION; if(!_loop_begin) goto _END_LOOP_INITIALIZATION;\
   _BEGIN_LOOP_INITIALIZATION
#define LOOP_BODY _loop_begin = false; if(_loop_begin)\
   goto _BEGIN_LOOP_INITIALIZATION; _END_LOOP_INITIALIZATION
#define LOOP_END _render(); if(_running_loop) return;\
  _LOOP_FINALIZATION: */
bool _loop_begin, _running_loop;
@

O código acima está comentado porque ele na verdade será mais complexo
que isso. Por hora mostraremos só a parte que cuida do controle de
fluxo. Note que o código tem redundâncias inofensivas. Algumas
condicionais nunca são verdadeiras e portanto seu desvio nunca
ocorrerão. Mas elas estão lá apenas para evitarmos mensagens de aviso
de compilação envolvendo rótulo não usados e para garantir que ocorra
um erro de compilação caso um dos rótulos seja usado sem o outro em
uma função de loop principal.

Note que depois do corpo do loop chamamos |_render|, a função que
renderiza as coisas de nosso jogo na tela.

As funções |Wloop| e |Wsubloop| tem a seguinte declaração:

@<Cabeçalhos Weaver@>+=
void Wloop(MAIN_LOOP (*f)(void)) __attribute__ ((noreturn));
void Wsubloop(MAIN_LOOP (*f)(void)) __attribute__ ((noreturn));
@

Note que estas funções nunca retornam. O modo de sair de um loop é
passar para o outro por meio de alguma condição dentro dele. Colocar
loops em sequência um após o outro não funcionará, pois o primeiro não
retornará e nunca passará para o segundo. Isso ocorre para nos
mantermos dentro das restrições trazidas pelo Emscripten cujo modelo
de loop principal não prevê um retorno. Mas a restrição também torna
mais explícita a sequência de loops pela qual um jogo passa.

Um jogo sempre começa com um |Wloop|. O primeiro loop é um caso
especial. Não podemos descartar a memória prévia, ou acabaremos nos
livrando de alocações globais. Então vamos usar uma pequena variável
para sabermos se já iniciamos o primeiro loop ou não. Outra coisa que
precisamos é de um vetor que armazene as funções de loop que estamos
executado. Embora um |Wloop| não retorne, precisamos simular um
retorno no caso de sairmos explicitamente de um |Wsubloop|. Por isso,
precisamos de uma pilha com todos os dados de cada loop para o qual
podemos voltar:

@<Cabeçalhos Weaver@>+=
bool _first_loop;
// A pilha de loops principais:
int _number_of_loops;
MAIN_LOOP (*_loop_stack[W_MAX_SUBLOOP]) (void);
@

E a inicializaremos as variáveis. O primeiro loop logo deverá mudar
seus valores de inicialização e cada loop saberá como deve tratar eles
após a execução baseando-se em como recebeu tais valores:

@<API Weaver: Inicialização@>+=
_first_loop = true;
_running_loop = false;
_number_of_loops = 0;
@

Eis que o código de |Wloop| é:

@<API Weaver: Definições@>+=
void Wloop(void (*f)(void)){
  if(_first_loop)
    _first_loop = false;
  else{
#if W_TARGET == W_WEB
    emscripten_cancel_main_loop();
#endif
    Wtrash();
  }
  Wbreakpoint();
  _loop_begin = 1;
  @<Código Imediatamente antes de Loop Principal@>
  @<Código antes de Loop, mas não de Subloop@>
  _loop_stack[_number_of_loops] = f;
  _running_loop = true;
  _update_time();
#if W_TARGET == W_WEB
  while(1)
    emscripten_set_main_loop(f, 0, 1);
#else
  while(1)
    f();
#endif
}
@

Mas se um Wloop nunca retorna, como sair dele? Para sair do programa
como um todo, pode-se usar |Wexit|. Mas pode ser que estejamos dentro
de um subloop e queremos encerrá-lo voltando assim para o loop que o
gerou. Para isso iremos definir a função |_exit_loop|. Se nunca criamos
nenhum subloop, a função é essencialmente idêntica à |Wexit|. Podemos
definir então o |_exit_loop| como:

@<Cabeçalhos Weaver@>+=
void _exit_loop(void) __attribute__ ((noreturn));
@

@<API Weaver: Definições@>+=
void _exit_loop(void){
#if W_DEBUG_LEVEL >= 1
  if(_first_loop){
    fprintf(stderr, "ERROR (1): Using Wexit_loop outside a game loop.\n");
    Wexit();
  }
#endif
  Wtrash();
  if(_number_of_loops == 0)
    Wexit();
  else{
    @<Código após sairmos de Subloop@>
    _number_of_loops --;
    @<Código Imediatamente antes de Loop Principal@>
    _running_loop = true;
    _update_time();
#if W_TARGET == W_WEB
    emscripten_cancel_main_loop();
    while(1)
      emscripten_set_main_loop(_loop_stack[_number_of_loops], 0, 1);
#else
  while(1)
    _loop_stack[_number_of_loops]();
#endif
  }
}
@

Conforme visto no código das macros que tem a forma de rótulos dentro
de funções de loop principal, a função |_exit_loop| é chamada
automaticamente na próxima iteração quando a variável |_running_loop|
torna-se falsa dentro da função. Para que isso possa ocorrer,
definiremos a seguinte função de macro que é o que o usuário deverá
chamar dentro de funções assim para encerrar o loop:

@<Cabeçalhos Weaver@>+=
#define Wexit_loop() (_running_loop = false)
@

Agora vamos implementar a variação: |Wsubloop|. Ele funciona de forma
semelhante invocando um novo loop principal. Mas esta função não irá
descartar o loop que a invocou, e assim que ela se encerrar (o que
pode acontecer também depois que um |Wloop| foi chamado dentro dela e
se encerrar), o loop anterior será restaurado. Desta forma, pode-se
voltar ao mapa anterior após uma batalha que o interrompeu em um jogo
de RPG clássico ou pode-se voltar rapidamente ao jogo após uma tela de
inventário ser fechada sem a necessidade de ter-se que carregar tudo
novamente.

@<API Weaver: Definições@>+=
void Wsubloop(void (*f)(void)){
#if W_TARGET == W_WEB
    emscripten_cancel_main_loop();
#endif
  Wbreakpoint();
  _loop_begin = 1;
  _number_of_loops ++;
  @<Código Imediatamente antes de Loop Principal@>
  @<Código antes de Subloop@>
#if W_DEBUG_LEVEL >= 1
  if(_number_of_loops >= W_MAX_SUBLOOP){
    fprintf(stderr, "Error (1): Max number of subloops achieved.\n");
    fprintf(stderr, "Please, increase W_MAX_SUBLOOP in conf/conf.h.\n");
  }
#endif
  _loop_stack[_number_of_loops] = f;
  _running_loop = true;
  _update_time();
#if W_TARGET == W_WEB
  while(1)
    emscripten_set_main_loop(f, 0, 1);
#else
  while(1)
    f();
#endif
}
@

@*1 Estrutura de um Loop Principal.

No loop principal de um jogo, temos que lidar com algumas questões. O
jogo precisa rodar de forma semelhante, tanto em máquinas rápidas como
lentas. Do ponto de vista da física não devem haver diferenças, cada
iteração da engine de física deve ocorrer em intervalos fixos de
tempo, para que assim o jogo torne-se determinístico e não acumule
mais erros em máquinas rápidas que rodariam um loop mais rápido. Do
ponto de vista da renderização, queremos realizá-la o mais rápido
possível.

Para isso precisamos manter separadas a física e a renderização. A
física e a lógica do jogo devem rodar em intervalos fixos e
conhecidos, tais como a 25 frames por segundo (pode parecer pouco, mas
é mais rápido que imagens de um filme de cinema). Para coisas como
obter a entrada de usuário e rodar simulação física, isso é o
bastante. Já a renderização pode acontecer o mais rápido que podemos
para que a imagem rode com atualização maior.

Para isso cada loop principal na verdade tem 2 loops. Um mais interno
que atualiza a física e outro que renderiza. Nem sempre iremos entrar
no mais interno. Mas devemos sempre ter em mente que como a física se
atualiza em unidades de tempo discretas, o tempo real em que estamos é
sempre ligeiramente no futuro disso. Sendo assim, na hora de
renderizarmos, precisamos extrapolar um pouco a posição de todas as
coisas sabendo a sua velocidade e sua posição. Essa extrapolação
ocasionalmente pode falhar, por não levar em conta colisões e coisas
características da engine de física. Mas mesmo quando ela falha, isso
é corrigido na próxima iteração e não é tão perceptível.

Existem 2 valores que precisamos levar em conta. Primeiro quanto tempo
deve durar cada iteração da engine de física e controle de jogo. É o
valor de |W.dt| mencionado no capítulo anterior e que precisa ser
inicializado. E segundo, quanto tempo se passou desde a última
invocação de nossa engine de física (|_lag|).


@<Cabeçalhos Weaver@>+=
long _lag;
@

@<API Weaver: Inicialização@>+=
W.dt = 40000; // 40000 microssegundos é 25 fps para a engine de física
_lag = 0;
@

@<Código Imediatamente antes de Loop Principal@>=
_lag = 0;
@

Ocorre que a parte de nosso loop principal dentro dos rótulos
|LOOP_BODY| e |LOOP_END| é a parte que assumiremos fazer parte da
física e do controle de jogo, e que portanto executará em intervalos
de tempo fixos. Para construirmos então este controle, usaremos as
seguintes definições de macro:

@<Cabeçalhos Weaver@>+=
#define LOOP_INIT if(!_running_loop) _exit_loop(); if(!_running_loop)\
   goto _LOOP_FINALIZATION; if(!_loop_begin) goto _END_LOOP_INITIALIZATION;\
   _BEGIN_LOOP_INITIALIZATION
#define LOOP_BODY _loop_begin =  false; if(_loop_begin)\
   goto _BEGIN_LOOP_INITIALIZATION; _END_LOOP_INITIALIZATION:\
   _lag +=  _update_time(); while(_lag >= 40000){ _update(); _LABEL_0
#define LOOP_END _lag -=  40000; W.t +=  40000; } \
   _render(); if(_running_loop) return; if(W.t == 0) goto _LABEL_0;\
   _LOOP_FINALIZATION
@

Pode parecer confuso o que todas estas macros disfarçadas de rótulos
fazem. Mas se expandirmos e ignorarmos o código inócuo que está lá só
para prevenir avisos do compilador e traduzirmos alguns |goto| para
uma forma estruturada, o que temos é:

@(/tmp/dummy.c@>=
MAIN_LOOP main_loop(void){
  if(!_running_loop)
    _exit_loop();
  if(initializing){
    /* Código de usuário da inicialização */
  }
  initializing = false;
  // Código executado toda iteração:
  _lag += _update_time();
  while(_lag >= 40000){
    _update();
    /* Código do usuário executado toda iteração */
    _lag -= 40000;
    W.t += 40000;
  }
  _render();
  if(!running_loop){
    /* Código de usuário para finalização */
  }
}
@

@*1 Sumário das Variáveis e Funções de Memória.

\macronome Ao longo deste capítulo, definimos 9 novas funções:

\macrovalor|void *Wcreate_arena(size_t size)|: Cria uma nova região
contínua de memória, de onde modemos alocar e desalocar regiões e
retorna ponteiro para ela.

\macrovalor|int Wdestroy_arena(void *arena)|: Destrói uma região
contínua de memória criada com a função acima. Retorna 1 em caso de
sucesso e 0 se o pedido falhar.

\macrovalor|void *Walloc_arena(void *arena, size_t size)|: Aloca
\monoespaco{size} bytes em uma dada região de memória contínua e
retorna endereço da região alocada.

\macrovalor|void Wfree(void *mem)|: Desaloca região de memória
alocada.

\macrovalor|int Wbreakpoint_arena(void *arena)|: Cria marcação em
região de memória contínua. Ver |Wtrash_arena|. Retorna 1 em caso de
sucesso e 0 em caso de falha.

\macrovalor|void Wtrash_arena(void *arena)|: Desaloca automaticamente
toda a memória alocada após última marcação em região contínua de
memória e remove a marcação. Se não houverem marcações adicionadas,
desaloca tudo o que já foi alocado na região contínua de memória.

\macrovalor|void *Walloc(size_t size)|: Aloca \monoespaco{size} bytes
de memória de uma região de memória padrão e retorna ponteiro para
região alocada.

\macrovalor|int Wbreakpoint(void)|: Cria marcação em região de memória
padrão. Retorna 1 em caso de sucesso e 0 em caso de falha.

\macrovalor|void Wtrash(void)|: Remove tudo o que foi alocado em
região de memória padrão desde a última marcação. Remove a
marcação. Na ausência de marcação, desaloca tudo o que já foi alocado
com |walloc|.

\macrovalor|void Wloop(void (*f)(void))|: Troca o loop principal atual
por um loop novo representado pela função passada como argumento. Ou
inicia o primeiro loop principal.

\macrovalor|void Wsubloop(void (*f)(void))|: Inicia um novo loop
principal que deve rodar dentro do atual. Quando ele se encerrar, o
loop atual deve retomar sua execução.

\macrovalor|void Wexit_loop(void)|: Sai do loop principal
atual. Retomamos o último loop interrompido com um |Wsubloop|. Se não
existe, encerramos o programa.
