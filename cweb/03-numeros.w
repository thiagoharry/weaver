@* Funções e Operações Numéricas.

Neste capítulo iremos construir funções numéricas e matemáticas
diversas que serão úteis mais tarde. À partir deste capítulo já
poderemos ser capazes de aproveitar o gerenciador de memória
construído no capítulo anterior.

Começamos declarando nosso arquivo de cabeçalho.

@(project/src/weaver/numeric.h@>=
#ifndef _numeric_h_
#define _numeric_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Funções Numéricas: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@

E agora o nosso arquivo com as funções C em si:

@(project/src/weaver/numeric.c@>=
#ifdef W_MULTITHREAD
#include <pthread.h>
#endif
#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h> // gettimeofday
#include <string.h> // memcpy
#include "numeric.h"
#if W_TARGET == W_ELF
#include <unistd.h> // read
#include <sys/stat.h> // open
#include <fcntl.h> // open
#endif
static bool initialized = false;
@<Funções Numéricas: Variáveis Estáticas@>
@<Funções Numéricas: Funções Estáticas@>
@<Funções Numéricas: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "numeric.h"
@

@*1 Geração de Números Pseudo-Randômicos: SFMT.

Um dos algoritmos geradores de números pseudo-randômicos mais usados e
de melhor qualidade é o Mersenne Twister (MT). O Playstation 3 é o
exemplo mais canônico de hardware cujo kit de desenvolvimento usa tal
algoritmo. Mas ele não usa o Mersenne Twister original. Ele usa uma
variação conhecida por ter desempenho melhor: o SIMBD Fast Mersenne
Twister (SFMT). Além de ser mais rápido, ele tem uma melhor
equidistribuição numérica e se recupera mais rápido caso fique preso
na geração de sequências patologicamente ruins. O único algoritmo
conhecido que supera esta versão do Mersenne Twister na qualidade é o
WELL (Well Equidistributed Long-Period Linear). Mas como ele é muito
mais lento, tanto o Mersenne Twister como o SFMT na prática são muito
mais usados.

Um gerador de números pseudo-randômicos típico gera sequência de
números à partir de um valor inicial conhecido como ``semente''
($s$). Para gerar o primeiro número pseudo-randômico, uma função $f$
retornaria $f(s)$. O segundo número gerado é $f(f(s))$ e assim por
diante. Então, bastaria sempre armazenarmos o último número gerado e
por meio dele deduzimos o próximo com a nossa função $f$.

Tanto o MT como o SFMT são um pouco mais complexos. Não iremos
demonstrar suas propriedades, iremos apenas descrevê-las. Ambos os
algoritmos garantem que são capazes de gerar novos números sem repetir
periodicamente a sequência um número de vezes igual à um primo de
Mersenne. Ou seja, um número na forma $2^n-1$ que também é primo. Em
tese podemos escolher qualquer primo de Mersenne, mas iremos escolher
o $2^{19937}-1$. Este é o número escolhido nas implementações mais
comuns do algoritmo. Se usássemos outro primo de Mersenne teríamos que
derivar e descobrir parâmetros específicos para ele. Ao invés disso, é
melhor obter um número cujos parâmetros já foram calculados e já foi
bastante testado.

Como o nosso número no expoente é $19937$, o nosso algoritmo irá
precisar armazenar na memória um total de $\lfloor{19937 \over
128}\rfloor+1=156$ sequências de números de 128 bits. Ou seja, 19968
bits. Esta sequência representa o estado atual do nosso gerador de
números pseudo-randômicos. Iremos gerá-la no começo do programa e com
ela teremos a resposta para os próximos 624 números
pseudo-randômicos. Se precisarmos de mais, geramos um novo estado
representado pela sequência de novos 154 números de 128 bits.

@<Funções Numéricas: Variáveis Estáticas@>=
// A sequência de números:
static uint32_t _sfmt_sequence[624];
// O índice que determina qual o próximo número a ser retornado:
static int _sfmt_index;
#if defined(W_MULTITHREAD)
// Um mutex para que possamos usar o gerador em threads:
static pthread_mutex_t _sfmt_mutex;
#endif
@

Vamos inicializar tudo nesta função:

@<Funções Numéricas: Declarações@>=
void _initialize_numeric_functions(void);
void _finalize_numeric_functions(void);
@
@<Funções Numéricas: Definições@>=
void _initialize_numeric_functions(void){
  uint32_t seed;
  @<Funções Numéricas: Inicialização@>
}
void _finalize_numeric_functions(void){
  @<Funções Numéricas: Finalização@>
}
@

E isso será inicializado na inicialização do programa:

@<API Weaver: Inicialização@>+=

_initialize_numeric_functions();
@

E finalizado no fim do programa:

@<API Weaver: Inicialização@>+=
_finalize_numeric_functions();
@

A primeira coisa a ser inicializada e finalizada é o nosso mutex, que
não tem nenhum mistério:

@<Funções Numéricas: Inicialização@>=
#if defined(W_MULTITHREAD)
if(!initialized && pthread_mutex_init(&_sfmt_mutex, NULL) != 0){
  fprintf(stderr, "ERROR (0): Can't initialize mutex for random numbers.\n");
  exit(1);
}
#endif
@

@<Funções Numéricas: Finalização@>=
#if defined(W_MULTITHREAD)
  pthread_mutex_destroy(&_sfmt_mutex);
#endif
@

A primeira coisa a fazer é escolher uma semente, um valor inicial para
o nosso gerador de números pseudo-randômicos. Apesar de na teoria
nosso algoritmo só tratar números como sequências de 128 bits, a
semente que passaremos sempre terá 32 bits. Escolheremos a semente
primeiro checando se a variável \monoespaco{use\_runtime\_seed} é
verdadeira. Se for o caso, lemos a variável estática global
\monoespaco{runtime\_seed} para definir a semenete. Caso contrário, se
o usuário definiu a macro |W_SEED| em \monoespaco{conf/conf.h},
usaremos este valor. Caso contrário usaremos como valor o número lido
de \monoespaco{/dev/urandom} ou um valor baseado no número de
microsegundos.

@<Funções Numéricas: Inicialização@>+=
if(use_runtime_seed)
  seed = runtime_seed;
else{
#ifndef W_SEED
#if W_TARGET == W_ELF
  bool got_seed = false;
  int file = open("/dev/urandom", O_RDONLY);
  if(file != -1){
    if(read(file, &seed, sizeof(seed)) != -1)
      got_seed = true;
    close(file);
  }
  if(!got_seed){
    struct timeval t;
    gettimeofday(&t, NULL);
    seed = (uint32_t) t.tv_usec + (uint32_t) (t.tv_sec << 9);
  }
#else
  {
    struct timeval t;
    gettimeofday(&t, NULL);
    seed = (uint32_t) t.tv_usec + (uint32_t) (t.tv_sec << 9);
  }
#endif
  // Colocamos a semente como primeiro valor na nossa sequência aleatória:
  _sfmt_sequence[0] = seed;
#else
  _sfmt_sequence[0] = seed = (uint32_t) W_SEED; // Se W_SEED é definida, use ela
#endif
}
@

A saber, inicialmente manteremos a \monoespaco{use\_runtime\_seed}
como falso:

@<Funções Numéricas: Variáveis Estáticas@>+=
static bool use_runtime_seed = false;
static unsigned int runtime_seed = 0;
@

Vamos assumir que a sequência de números que iremos gerar são números
de 32 bits (apesar de que mais adiante o algoritmo tratará a sequência
como sendo de números de 128 bits). Acabamos de gerar o primeiro
$N_0$, cujo valor é a semente. A fórmula para gerar todos os outros é:

$$
N_i = 1812433253(N_{i-1} \oplus \lfloor N_{i-1} / 2^{30}\rfloor) + i
$$

Onde o operador $\oplus$ é o XOR bit-a-bit.  Sabendo disso, podemos
começar a implementar a inicialização de nosso vetor:

@<Funções Numéricas: Inicialização@>+=
{
  int i;
  for(i = 1; i < 624; i ++){
    _sfmt_sequence[i] = 1812433253ul *
      (_sfmt_sequence[i-1]^(_sfmt_sequence[i-1] >> 30)) + i;
  }
  // Marcamos o último valor gerado como a semente. Os próximos são os
  // que vem depois dela:
  _sfmt_index = 0;
}
@

Mas ainda não acabou. Sabemos que existem configurações iniciais
problemáticas para o Mersenne Twister. Se nós tivemos azar ao obter a
nossa semente, podemos ter gerado uma sequência ruim, que vai começar
a se repetir muito antes da nossa previsão mínima de
$2^{19937}-1$. Felizmente sabemos como prever se nós geramos uma
sequência inicial ruim e é fácil corrigir se isso aconteceu.

Fazemos isso checando os 4 primeiros números de 32 bits gerados: $N_0,
N_1, N_2$ e $N_3$. Basicamente calculamos então:

$$
(1\otimes N_0)\oplus(0\otimes N_1)\oplus(0\otimes
N_2)\oplus(331998852\otimes N_3)
$$

E em seguida pegamos este resultado e calculamos o XOR bit-a-bit de
todos os valores. Se o resultado final for falso, então estamos diante
de um valor inicial ruim. O que faremos então é apenas inverter o bit
menos seignificativo da semente e isso corrige a imperfeição para o
caso específico dos valores que usamos.
  
Estes valores usados nas operações de AND bit-a-bit ($\otimes$) são
derivados especialmente para o nosso caso em que o primo de Mersenne é
$2^{19937}-1$. Se o primo fôsse diferente, teríamos que obter valores
diferentes. E poderíamos ter que inverter algum bit diferente para
corrigir entradas ruins.

Claro, na prática usaremos nosso conhecimento de que calcular o AND
bit-a-bit com o número zero sempre resulta em um zero. E assim,
precisamos apenas conferir os valores do primeiro e quarto número:

@<Funções Numéricas: Inicialização@>+=
{
  int i;
  uint32_t r = (1 & _sfmt_sequence[0]) ^ (331998852ul & _sfmt_sequence[3]);
  for(i = 16; i >= 1; i /= 2)
    r ^= (r >> i);
  if(!(r % 2)){
    // Sequência problemática. Corrigindo um bit.
    if(_sfmt_sequence[0] % 2)
      _sfmt_sequence[0] --;
    else
      _sfmt_sequence[0] ++;
  }
}
@

Agora podemos até definir a nossa função responsável por gerar números
pseudo-randômicos:

@<Funções Numéricas: Declarações@>+=
unsigned long _random(void);
@

@<Funções Numéricas: Definições@>+=
unsigned long _random(void){
  unsigned long number;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_sfmt_mutex);
#endif
  if(_sfmt_index < 623){
    _sfmt_index ++;
  }
  else{
    _sfmt_index = 0;
    // Acabaram os números, vamos produzir mais:
    _regenerate_sequence();
  }
  number = (unsigned long) _sfmt_sequence[_sfmt_index];
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_sfmt_mutex);
#endif
  return number;
}
@

A última coisa que precisa ser definida é a função
|regenerate_sequence|, a qual gerará a próxima leva de números
pseudo-randômicos após já termos usado todos os 616 gerados
previamente. Neste momento o SFMT diverge do MT clássico e também
começa a sempre tratar os seus valores como números de 128 bits ao
invés de 32 bits. A fórmula para obter um novo número de 128 bits de
agora em diante será:

$$
N_i = N_{i-154} \oplus (N_{i-154} << 8) \oplus ((N_{i-8} >>' 11)
\otimes X) \oplus (N_{i-2} << 8) \oplus (N_{i-1} <<' 18)
$$

Onde $X$ é uma constante que depende do primo de Mersenne que usamos
no algortimo e as operações $<<$ e $>>$ representam as operações de
shift aplicadas sobre cda sequência individual de 32 bits que formam o
número, não uma operação de shift sobre todo o número de 128 bits.

A implementação da função é então:

@<Funções Numéricas: Funções Estáticas@>=
static void _regenerate_sequence(void){
  int i;
  // A primeira coisa que fazemos é usar os últimos 256 bits gerados
  // de maneira pseudo-randômica e tratar como dois números: r1 e r2:
  uint32_t r1[4], r2[4];
  // A ideia agora é iterarmos sobre o vetor de números gerados
  // previamente e ir gerando novos números. Mas vamos tratar o vetor
  // como um vetor de números de 128 bits, não como 32 bits. Então, r2
  // sempre irá representar a última sequência de 128 bits gerada e r1
  // representará a penúltima. Inicialmente temos:
  memcpy(r2, &(_sfmt_sequence[620]), 16);
  memcpy(r1, &(_sfmt_sequence[616]), 16);
  // Gerando cada número de 128 bits:
  for(i = 0; i < 156; i ++){
    // Primeiro fazemos um shift à esquerda de 1 byte no valor de 128
    // bits que temos na posição atual de nosso vetor de sequências e
    // armazenamos em x:
    uint32_t x[4], y[4];
    uint64_t n1, n2, aux1, aux2;
    int j;
    n1 = ((uint64_t) _sfmt_sequence[i * 4 + 3] << 32) |
      ((uint64_t) _sfmt_sequence[i * 4 + 2]);
    n2 = ((uint64_t) _sfmt_sequence[i * 4 + 1] << 32) |
      ((uint64_t) _sfmt_sequence[i * 4]);
    aux1 = n1 << 8;
    aux2 = n2 << 8;
    aux1 |= n2 >> 56;
    x[1] = (uint32_t) (aux2 >> 32);
    x[0] = (uint32_t) aux2;
    x[3] = (uint32_t) (aux1 >> 32);
    x[2] = (uint32_t) aux1;
    // Agora fazemos um shift de 1 byte à direita de r1 e armazenamos
    // em y:
    n1 = ((uint64_t) r1[3] << 32) | ((uint64_t) r1[2]);
    n2 = ((uint64_t) r1[1] << 32) | ((uint64_t) r1[0]);
    aux1 = n1 >> 8;
    aux2 = n2 >> 8;
    aux2 |= n1 << 56;
    y[1] = (uint32_t) (aux2 >> 32);
    y[0] = (uint32_t) aux2;
    y[3] = (uint32_t) (aux1 >> 32);
    y[2] = (uint32_t) aux1;
    // O j armazenará a posição do número de 128 bits 8 posições atrás:
    if(i < 34)
      j = i + 122;
    else
      j = i - 34;
    // E agora preenchemos um novo valor de 128 bits no nosso vetor de
    // números pseudo-randômicos:
    _sfmt_sequence[i * 4] = _sfmt_sequence[i * 4] ^ x[0] ^
      ((_sfmt_sequence[j * 4] >> 11) & 3758096367ul) ^ y[0] ^ (r2[0] << 18);
    _sfmt_sequence[i * 4 + 1] = _sfmt_sequence[i * 4 + 1] ^ x[1] ^
      ((_sfmt_sequence[4 * j + 1] >> 11) & 3724462975ul) ^ y[1] ^ (r2[1] << 18);
    _sfmt_sequence[i * 4 + 2] = _sfmt_sequence[i * 4 + 2] ^ x[2] ^
      ((_sfmt_sequence[4 * j + 2] >> 11) & 3220897791ul) ^ y[2] ^ (r2[2] << 18);
    _sfmt_sequence[i * 4 + 3] = _sfmt_sequence[i * 4 + 3] ^ x[3] ^
      ((_sfmt_sequence[4 * j + 3] >> 11) & 3221225462ul) ^ y[3] ^ (r2[3] << 18);
    // E por fim atualizamos os valores de r1 e r2 para a próxima iteração
    memcpy(r1, r2, 16);
    memcpy(r2, &(_sfmt_sequence[4 * i]), 16);
  }
}
@

E tendo terminado a nossa implementação do SFMT, resta apenas
declararmos e inicializarmos um ponteiro para a função geradora de
números pseudo-randômicos na estrutura |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
unsigned long (*random)(void);
@

@<API Weaver: Inicialização@>=
W.random = &_random;
@

Recapitulando, o primeiro número de 128 bits gerado pelo nosso
Mersenne Twister depende da semente. Os primeiros 32 bits são
idênticos à semente e os demais envolvem operações envolvendo a
semente. Em seguida, os próximos 155 são preenchidos na inicialização
e cada um deles depende inteiramente do número anterior. Somente
depois que 156 números de 128 bits são gerados na inicialização
envolvendo operações mais simples, aplicamos o algoritmo do Mersenne
Twister em toda a sua glória, onde a geração de cada número envolve
embaralhar os seus bits com uma constante, com o número anterior, com
o anterior do anterior, com o número 8 posições atrás e com o número
de 156 posições atrás.

A geração de números com a qualidade esperada só ocorre então depois
dos 156 iniciais. Por causa disso, é importante que na inicialização
nós descartemos os números iniciais para gerar os próximos 156 que
virão com uma qualidade maior após a preparação inicial:

@<Funções Numéricas: Inicialização@>+=
{
  _sfmt_index = -1;
  _regenerate_sequence();
  initialized = true;
}
@

A última coisa que falta é fornecermos uma função que permite definir
a semente do gerador de números pseudo-randômicos em tempo de
execução. Esta será uma funçãoque será usada mais internamente:

@<Funções Numéricas: Declarações@>+=
void _set_random_number_seed(unsigned int seed);
@

@<Funções Numéricas: Definições@>+=
void _set_random_number_seed(unsigned int seed){
     use_runtime_seed = true;
     runtime_seed = seed;
     _initialize_numeric_functions();
}
@

Feito isso, terminamos toda a preparação e nosso gerador de números
pseudo-randômicos está pronto.

Tudo isso é interessante, mas a pergunta que deve ser feita é: o quão
rápido é? Realmente vale à pena usar um algoritmo como o Mersenne
Twister em jogos que precisam de um bom desempenho? Como esta versão
do Mersenne Twister se dá ao ser compilada para Javascript, onde as
operações bit-a-bit podem não ser tão rápidas? A resposta pode ser
vista no gráfico abaixo:

\hbox{
\cor{1.0 0.75 0.75}{\vrule height 3.31mm width 25mm}
\cor{1.0 0.6 0.6}{\vrule height 8.71mm width 25mm}
\cor{1.0 0.45 0.45}{\vrule height 28mm width 25mm}
\cor{1.0 0.2 0.2}{\vrule height 70mm width 25mm}
\cor{0.0 0.0 1.0}{\vrule height 110mm width 25mm}
}

Nele cada milímetro corresponde a 100 microssegundos no computador
usado nos testes. A primeira e menor coluna corresponde ao tempo que a
implementação de referência criada por Mutsuo Saito e Makoto Matsumoto
leva para gerar 100 mil números pseudo-randômicos. A segunda coluna é
o tempo gasto pela implementação usada no Weaver, a qual foi descrita
acima. A terceira coluna é o tempo gasto pela função |rand()| da
biblioteca padrão do C. A quarta coluna é o tempo gasto pela |rand()|
quando compilada usando Emscripten. E a última coluna é a nossa
implementação do Mersenne Twister quando compilada usando o Mersenne
Twister.

Isso nos permite concluir que mesmo não tendo no momento otimizado
tanto a implementação do algoritmo como conseguiram seus criadores,
mesmo assim o Mersenne Twister consegue um desempenho muito melhor que
a função usada pela biblioteca padrão C. Então mesmo ainda tendo muito
espaço para melhorias, ainda é melhor ficarmos com esta implementação
que com a implementação padrão da Glibc.

No caso do Emscripten, lidamos com uma questão mais complicada. Se
usarmos |rand()| diretamente, o desempenho é muito melhor que usando
nossa implementação de Mersennet Twister (neste caso, o Emscripten usa
uma implementação própria de gerador de números pseudo-randômicos em
Javascript). Mas se nós fizermos com que a nossa função |W.random|
passe a apontar para |rand|, todo o benefício de velocidade se perde e
o desempenho torna-se cerca de 50\% pior do que se usarmos nossa
implementação de Mersenne Twister. Aparentemente, para gerar números
pseudo-randômicos de forma rápida no Emscripten, deve-se chamar |rand|
diretamente sem ``wrappers''.

Mas como Weaver precisa por consistência de sua API fornecer suas
funções por meio da estrutura |W|, só nos resta então fornecer
|W.random| como implementando o Mersenne Twister, que ainda é o que
fornece o melhor desempenho neste caso. Mas devemos avisar na
documentação que o uso da função |rand| sem ``wrappers'' fornece um
desempenho melhor, ao menos quando medido no Emscripten 1.34.0.
                                          
@*1 Sumário das Variáveis e Funções Numéricas.

\macronome Ao longo deste capítulo, definimos a seguinte função:

\macrovalor|unsigned long W.random(void)|: Gera um número
inteiro pseudo-randômico de até 32 bits.
