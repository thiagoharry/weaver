@* Gerenciamento de memória.

Alocar memória dinamicamente de uma heap é uma operação cujo tempo
gasto nem sempre pode ser previsto. Isso é algo que depende da
quantidade de blocos contínuos de memória presentes na heap que o
gerenciador organiza. Por sua vez, isso depende muito do padrão de uso
das funções \monoespaco{malloc} e \monoespaco{free}, e por isso não é algo
fácil de ser previsto.

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

@ E também criamos o cabeçalho de memória. À partir de agora, cada
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

\macronome|W_WEB_MEMORY|: A quantidade de memória adicional em bytes que
  reservaremos para uso caso compilemos o nosso jogo para a Web ao
  invés de gerar um programa executável. O Emscripten precisará de
  memória adicional e a quantidade pode depender do quanto outras
  funções como |malloc| e |Walloc_arena| são usadas. Este valor deve
  ser aumentado se forem encontrados problemas de falta de memória na
  web. Esta macro será consultada na verdade por um dos
  \monoespaco{Makefiles}, não por código que definiremos neste PDF.

@*1 Estruturas de Dados Usadas.

Vamos considerar primeiro uma \negrito{arena}. Toda \negrito{arena} terá
a seguinte estrutura:

\quebra

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

Caso usemos todos estes dados, nosso cabeçalho de memória ficará com
cerca de 88 bytes em máquinas típicas. Nosso cabeçalho de arena terá
então a seguinte definição na linguagem C:

@<Declarações de Memória@>+=
struct _arena_header{
  size_t total, used;
  struct _breakpoint *last_breakpoint;
  void *empty_position, *last_element;
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
  if(header -> last_element < header -> last_breakpoint){
    fprintf(stderr,
            "ERROR (4): MEMORY: Arena header storing in wrong location!\n");
    exit(1);
  }
  // O espaço não-alocado não existe ou fica depois do último elemento
  // alocado.
  if(!(header -> empty_position == NULL ||
       header -> empty_position > header -> last_element)){
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
tem. Os demais valores podem ser deduzidos. Portanto, podemos usar
esta função interna para a tarefa:

@(project/src/weaver/memory.c@>+=
static bool _initialize_arena_header(struct _arena_header *header,
                                     size_t total){
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
  if(breakpoint -> last_breakpoint > breakpoint -> last_element){
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
                                   struct _breakpoint *last_breakpoint,
                                   char *file, unsigned long line){
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
  _initialize_breakpoint(self, self, arena, self, "", 0);
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

%As seguintes restrições sempre são válidas para tais dados: $tipo =
%0{\times}10101010$, $tamanho\_pedido \leq tamanho\_real$.

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
void *Wcreate_arena(size_t);
int Wdestroy_arena(void *);
@

@*2 Criando uma arena.

O processo de criar a arena funciona alocando todo o espaço de que
precisamos e em seguida preenchendo o cabeçalho inicial e breakpoint:

@(project/src/weaver/memory.c@>+=
void *Wcreate_arena(size_t size){
  void *arena;
  size_t real_size = 0;
  struct _breakpoint *breakpoint;

  { // Aloca 'arena' com cerca de 'size' bytes e preenche 'realsize'
    long page_size = sysconf(_SC_PAGESIZE);
    real_size = ((int) ceil((double) size / (double) page_size)) * page_size;
    arena = mmap(0, real_size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS,
                -1, 0);
    if(arena == MAP_FAILED){
      arena = NULL;
    }
  }

  if(arena != NULL){
    if(!_initialize_arena_header((struct _arena_header *) arena, real_size)){
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

Mas qual será o tamanho real da arena se não é necessariamente o que
pedimos como argumento? Será o menor tamanho que é maior ou
igual ao valor pedido e que seja múltiplo do tamanho de uma página do
sistema.

Usamos |sysconf| para saber o tamanho da página e |mmap| para obter a
memória. Outra opção seria o |brk|, mas usar tal chamada de sistema
criaria conflito caso o usuário tentasse usar o |malloc| da biblioteca
padrão ou usasse uma função de biblioteca que usa internamento o
|malloc|. Como até um simples |sprintf| usa |malloc|, não podemos usar
o |brk|, pois isso criaria muitos conflitos com outras bibliotecas:

@*2 Destruindo uma arena.

Destruir uma arena é uma simples questão de finalizar o seu mutex caso
estejamos criando um programa com muitas threads e usar um
|munmap|. Entretanto, se estamos rodando uma versão em desenvolvimento
do jogo, com depuração, este será o momento no qual informaremos a
existência de vazamentos de memória. E dependendo do nível da
depuração, podemos imprimir também a quantidade máxima de memória
usada:

@(project/src/weaver/memory.c@>+=
int Wdestroy_arena(void *arena){
#if W_DEBUG_LEVEL >= 1
  struct _arena_header *header = (struct _arena_header *) arena;
@<Checa vazamento de memória em 'arena' dado seu 'header'@>
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
  //Desaloca 'arena'
  if(munmap(arena, ((struct _arena_header *) arena) -> total) == -1){
    arena = NULL;
  }
  if(arena == NULL){
    return 0;
  }
  return 1;
}
@

Agora resta apenas definir como checamos a existência de vazamentos
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
        ((struct _breakpoint *) p) -> last_breakpoint !=
        (struct _breakpoint *) p){
    if(p -> type == _DATA_T && p -> flags % 2){
      fprintf(stderr, "WARNING (1): Memory leak in data allocated in %s:%lu\n",
              p -> file, p -> line);
    }
    p = (struct _memory_header *) p -> last_element;
  }
}
@

A única coisa que não temos como checar é se toda arena criada é
depois destruída. Caso um programador decida manipular manualmente
suas arenas, ele deverá assumir responsabilidade por isso.

@*1 Alocação e desalocação de memória.

@<Declarações de Memória@>+=
void *_alloc(void *arena, size_t size, char *filename, unsigned long line);
void _free(void *mem, char *filename, unsigned long line);
@

Alocar memória significa basicamente atualizar informações no
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
  //Parte 1: Calcular o verdadeiro tamanho a se alocar:
  size_t real_size = (size_t) (ceil((float) size / (float) sizeof(long)) *
                               sizeof(long));
  //Parte 2: Atualizar o cabeçalho da arena:
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
  //Parte 3: Preencher o cabeçalho do dado a ser alocado:
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
@


E agora precisamos só de uma função de macro para cuidar
automaticamente da tarefa de coletar o nome de arquivo e número de
linha para mensagens de depuração:

@<Declarações de Memória@>+=
#define Walloc_arena(a, b) _alloc(a, b, __FILE__, __LINE__)
@

Para desalocar a memória, existem duas possibilidades. Podemos estar
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
  // Primeiro checamos se não estamos desalocando a ultima memória. Se
  // é a ultima memória, precisamos manter o mutex ativo para impedir
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
@

E agora a macro que automatiza a obtenção do nome de arquivo e
número de linha:

@<Declarações de Memória@>+=
#define Wfree(a) _free(a, __FILE__, __LINE__)
@

@*1 Usando a heap descartável.

Graças ao conceito de \italico{breakpoints}, pode-se desalocar ao mesmo
tempo todos os elementos alocados desde o último \italico{breakpoint}
por meio do |Wtrash|.  A criação de um \italico{breakpoit} e descarte
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
void _initialize_memory();
void _finalize_memory();

@ Note que são funções que sabem o nome do arquivo e número de linha
em que estão para propósito de depuração. Elas são definidas como
sendo:

@(project/src/weaver/memory.c@>+=
void _initialize_memory(void){
  _user_arena = Wcreate_arena(W_MAX_MEMORY);
  _internal_arena = Wcreate_arena(4000);
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

@(/tmp/dummy.c@>=
// Só um exemplo, não faz parte de Weaver
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
@

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

@(/tmp/dummy.c@>=
// Só um exemplo, não faz parte de Weaver
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
@

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
