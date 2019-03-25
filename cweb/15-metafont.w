@* METAFONT.

METAFONT é uma linguagem criada inicialmente para definir fontes de
computador. Mas de fato, ela é uma linguagem turing completa capaz de
definir desenhos e imagens arbitrários, desde que tenham com uma única
cor. Ela descreve todas as formas por meio de equações geométricas,
com ajuda e curvas de Bézier cúbicas. A versão atual da linguagem foi
criada em 1984 por Donald Knuth. A Engine Weaver a usará como uma
forma de receber instruções de desenhos e para representar fontes.

As funções referentes à linguagem METAFONT ficarão todas dentro dos
seguintes arquivos:

@(project/src/weaver/metafont.h@>=
#ifndef _metafont_h_
#define _metafont_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
#if W_DEBUG_LEVEL == 0 && defined(W_DEBUG_METAFONT)
#error "Use W_DEBUG_METAFONT only with W_DABUG_LEVEL > 0"
#endif
@<Metafont: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@

@(project/src/weaver/metafont.c@>=
#include "weaver.h"
#include <stdarg.h>
@<Metafont: Inclui Cabeçalhos@>
@<Metafont: Variáveis Estáticas@>
@<Metafont: Funções Locais Declaradas@>
@<Metafont: Funções Estáticas@>
@<Metafont: Eval@>
@<Metafont: Parser@>
@<Metafont: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "metafont.h"
@

@<Metafont: Declarações@>+=
// A definir...
@

@<Metafont: Variáveis Estáticas@>+=
// A definir...
@

@<Metafont: Funções Estáticas@>+=
// A definir...
@

@<Metafont: Definições@>+=
// A definir...
@

@*1 Preparativos Iniciais.

Vamos precisar preparar duas coisas adicionais antes de começarmos. A
primeira tem relação com a memória. Precisamos alocar e desalocar
coisas nos seguintes três casos:

1- Para variáveis e definições globais, as quais só serão desalocadas
após sairmos do programa.

2- Para os tokens que vão sendo gerados à medida que formos lendo um
código-fonte, os quais devem ser desalocados assim que forem
interpretados.

3- Para variáveis e definições locais, as quais estarão dentro de um
bloco (que começa com \monoespaco{begingroup} e termina em um
\monoespaco{endgroup} no METAFONT).

No primeiro caso, vamos querer alocar as nossas estruturas na arena de
memória geral de nosso jogo. No segundo caso iremos querer alocar na
arena de memória interna. Mas precisamos de uma terceira arena de
memória para o terceiro caso.

Declaremos esta arena de memória:

@<Metafont: Variáveis Estáticas@>=
static void *metafont_arena;
@

Declaremos a função que irá inicializar tudo o que precisarmos
referente à interpretação de código METAFONT:

@<Metafont: Declarações@>=
void _initialize_metafont(void);
@

Na definição estabeleceremos que 1/4 da memória interna na verdade
seja usada como memória para o METAFONT:

@<Metafont: Definições@>+=
void _initialize_metafont(void){
    struct metafont *mf;
    metafont_arena = Wcreate_arena(W_INTERNAL_MEMORY / 4);
    if(metafont_arena == NULL){
        fprintf(stderr, "ERROR: This system have no enough memory to "
                "run this program.\n");
        exit(1);
    }
    @<Metafont: Inicialização@>
    @<Metafont: Lê Arquivo de Inicialização@>
}
@

A inicialização do Metafont será chamada após criarmos uma marcação na
memógia geral:

@<API Weaver: Inicialização@>+=
{
    Wbreakpoint();
    _initialize_metafont();
}
@

E essa marcação permite que na finalização desaloquemos tudo que for
referente ao Metafont em uma só desalocação:

@<API Weaver: METAFONT: Encerramento@>+=
{
    Wtrash();
}
@

A segunda coisa que precisamos preparar antes de começar a interpretar
METAFONT é uma estrutura de dados que armazene todas as informações
que forem relevantes sobre a interpretação: qual arquivo estamos
lendo, em que linha estamos, que variáveis definimos, e coisas
assim. No fim essa estrutura de dados irá conter todas as informações
sobre uma fonte, e durante a interpretação da fonte conterá todas as
informações que precisamos.

Essa estrutura será chamada de \monoespaco{metafont}:

@<Metafont: Variáveis Estáticas@>+=
struct metafont{
    char filename[256]; // Nome de arquivo com fonte
    FILE *fp; // Ponteiro para arquivo acima
    char buffer[4096]; // Buffer com conteúdo atual lido do arquivo
    int buffer_position; // Onde estamos lendo no buffer acima
    int line; // O número da linha atual do arquivo fonte lido
    bool error; // Encontramos um erro?
    struct metafont *parent, *child;
    @<METAFONT: Estrutura METAFONT@>
};
@

Uma estrutura METAFONT pode ser alocada em duas arenas: a global geral
(quando ela representará uma fonte) e a arena própria que definimos a
pouco (quando a estrutura representará o escopo dentro de um bloco,
onde variáveis e macros locais podem estar sendo definidas, caso em
que a estrutura será filha de outra).

Sendo assim, a inicialização da estrutura será feita pelo seguinte
construtor:

@<Metafont: Declarações@>+=
struct metafont *_new_metafont(struct metafont *, char *);
@

@<Metafont: Definições@>+=
struct metafont *_new_metafont(struct metafont *parent, char *filename){
    void *arena;
    struct metafont *structure;
    size_t ret;
    if(parent == NULL)
        arena = _user_arena;
    else
        arena = metafont_arena;
    structure = (struct metafont *) Walloc_arena(arena,
                                                 sizeof(struct metafont));
    if(structure == NULL)
        goto error_no_memory;
    structure -> parent = parent;
    strncpy(structure -> filename, filename, 255);
    if(parent == NULL){
#ifdef W_DEBUG_METAFONT
      printf("METAFONT: Opening file '%s'.\n", filename);
#endif
        structure -> fp = fopen(filename, "r");
        if(structure -> fp == NULL)
            goto error_no_file;
        else{
            ret = fread(structure -> buffer, 1, 4095, structure -> fp);
            structure -> buffer[ret] = '\0';
            if(ret != 4095){
                fclose(structure -> fp);
                structure -> fp = NULL;
            }
        }
    }
    structure -> buffer_position = 0;
    structure -> line = 1;
    structure -> error = false;
    @<METAFONT: Inicializa estrutura METAFONT@>
    @<METAFONT: Executa Arquivo de Inicialização@>
    if(parent != NULL)
        parent -> child = structure;
    else
        structure -> child = NULL;
    return structure;
error_no_file:
    fprintf(stderr, "ERROR (0): File %s don't exist.\n", filename);
    return NULL;
error_no_memory:
    fprintf(stderr, "ERROR: Not enough memory to parse METAFONT "
            "source. Please, increase the value of W_%s_MEMORY "
            "at conf/conf.h.\n", (arena == _user_arena)?"MAX":"INTERNAL");
    return NULL;
}
@

Assim, na inicialização, para lermos o nosso arquivo inicial com
código METAFONT, usamos:

@<Metafont: Lê Arquivo de Inicialização@>=
#if W_DEBUG_LEVEL == 0
  mf = _new_metafont(NULL, "/usr/share/games/"W_PROG"/fonts/init.mf");
#else
  mf = _new_metafont(NULL, "fonts/init.mf");
#endif
@

Agora anter de escrevermos o lexer da nossa linguagem, vamos
implementar duas funções que serão úteis. A primeira lê e retorna o
próxio caractere do nosso arquivo-fonte (provavelemtne é algo que já
está no buffer) e o consome, fazendo com que ele não volte mais a ser
retornado nas próximas vezes que checarmos o próximo caractere. A
segunda apenas retorna o caractere, mas não o consome. Tipicamente
isso é chamado de \monoespaco{read} e \monoespaco{peek}:

@<Metafont: Funções Estáticas@>+=
char read_char(struct metafont *mf){
    char ret;
    size_t size;
    while(mf -> parent != NULL)
        mf = mf -> parent;
    ret = mf -> buffer[mf -> buffer_position];
    if(ret != '\0'){
        mf -> buffer_position ++;
    }
    else if(mf -> fp != NULL){
        size = fread(mf -> buffer, 1, 4095, mf -> fp);
        mf -> buffer[size] = '\0';
        if(size != 4095){
            fclose(mf -> fp);
            mf -> fp = NULL;
        }
        mf -> buffer_position = 0;
        ret = mf -> buffer[mf -> buffer_position];
        if(ret != '\0')
            mf -> buffer_position ++;
    }
    else
        return '\0';
    // Também implementamos a contagem de linhas aqui
    if(ret == '\n')
        mf -> line ++;
    return ret;
}
@

A função \monoespaco{peek_char} pode parecer mais simples, mas temos
que tratar o caso de quando estamos no fim do buffer e para obtermos o
próximo caractere precisamos ler mais um bloco de dados do arquivo:

@<Metafont: Funções Estáticas@>+=
char peek_char(struct metafont *mf){
    char ret;
    size_t size;
    while(mf -> parent != NULL)
        mf = mf -> parent;
    ret = mf -> buffer[mf -> buffer_position];
    if(ret == '\0'){
        if(mf -> fp != NULL){
            size = fread(mf -> buffer, 1, 4095, mf -> fp);
            mf -> buffer[size] = '\0';
            if(size != 4095){
                fclose(mf -> fp);
                mf -> fp = NULL;
            }
            mf -> buffer_position = 0;
            ret = mf -> buffer[mf -> buffer_position];
        }
        else
            return '\0';
    }
    return ret;
}
@

Por fim, vamos criar mais uma função básica que serve para avisarmos
erros no código Metafont. Em tais casos, se um erro do tipo já foi
sinalizado, não iremos sinalizar outros, pois o erro relevante é
tipicamente o primeiro:

@<Metafont: Funções Estáticas@>+=
void mf_error(struct metafont *mf, char *message, ...){
    va_list args;
    va_start(args, message);
    while(mf -> parent != NULL)
        mf = mf -> parent;
    if(! mf -> error){
        fprintf(stderr, "ERROR: Metafont: %s:%d: ",
                mf -> filename, mf -> line);
        vfprintf(stderr, message, args);
        fprintf(stderr, "\n");
        mf -> error = true;
        // Finaliza a leitura de mais código:
        if(mf -> fp != NULL){
            fclose(mf -> fp);
            mf -> fp = NULL;
        }
        mf -> buffer_position = 0;
        mf -> buffer[mf -> buffer_position] = '\0';
    }
    va_end(args);
}
@


E também uma função para finalizar o interpretador sem erros:

@<Metafont: Funções Estáticas@>+=
void mf_end(struct metafont *mf){
    // Finaliza a leitura de mais código:
    while(mf -> parent != NULL)
        mf = mf -> parent;
    if(mf -> fp != NULL){
        fclose(mf -> fp);
        mf -> fp = NULL;
    }
    mf -> buffer_position = 0;
    mf -> buffer[mf -> buffer_position] = '\0';
    @<Metafont: Chegamos ao Fim do Código-Fonte@>
}
@

@*1 O Analizador Léxico.

A linguagem METAFONT possui as seguintes regras léxicas:

Regra 01: Pontos descartáveis: Se o próximo caractere for um espaço ou
for um ponto que não é seguido por um dígito decimal, ou outro ponto,
ignore-o e continue.

Regra 02: Comentários: Se o próximo caractere for um sinal e
porcentagem, ignore-o e ignore tudo o que existir até o fim da linha.

Regra 03: Token Numérico: Se o próximo caractere for um dígito decimal
ou um ponto seguido por dígitos decimais, o próximo token é um token
numérico consistino na maior sequência que satisfaz:

\alinhaverbatim
<Token Numérico>      --> <Sequência de Dígito>
                      |-> . <Sequência de Dígito>
                      |-> <Sequência de Dígito> . <Sequência de Dígito>

<Sequência de Dígito> --> <Dígito Decimal>
                      |-> <Sequência de Dígito> <Dígito Decimal>

<Dígito Decimal>      --> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
\alinhanormal

Regra 04: Token de String: Se o próximo caractere forem aspas duplas,
o próximo token é um token de string, e é formado por todos os
caracteres que estiverem até as próximas aspas duplas, as quais devem
estar na mesma linha. Caso não seja finalizada na mesma linha, isso é
um erro de string incompleta.

Regra 05: Tokens Caracteres: Se o próximo caractere for um abre ou
fecha parênteses, uma vírgula ou um ponto-e-vírgula, aquele caractere
é um único token, considerado como um token simbólico.

Regra 06: Tokens compostos: Caso contrário, temos um token simbólico
que será formado pela maior sequência de caracteres que abaixo
aparecem na mesma linha:

\alinhaverbatim
ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz
<=>:|
`'
+-
*/\\
!?
#&@$
[
]
{}
.
^~
\alinhanormal
%'

Dito isso, o analizador léxico irá sempre produzir 3 tipos de tokens:
números, strings e símbolos. Podemos representar cada token pela
estrutura:

@<Metafont: Variáveis Estáticas@>+=
// Tipo de token
#define NUMERIC 1
#define STRING  2
#define SYMBOL  3
struct token{
    int type;
    float value; // Para números
    char *name; // Para strings e identificadores
    @<Metafont: Atributos de Token@>
    struct token *prev, *next; // Para listas duplamente encadeadas
};
@

É importante notar que trataremos todos os números como em
ponto-flutuante simples. O METAFONT original usava outra definição,
onde todos os números tinham a parte inteira entre -4095 e +4095 e a
parte fracionária um múltiplo de $1/65536$. Mas a representação em
ponto-flutuante é melhor por ser mais rápida, ter no caso típico uma
casa decimal a mais de precisão e por ser capaz de representar uma
maior gama de números. Então não iremos manter a compatibilidade
nisso.

Podemos criar os seguintes construtores para tais diferentes tokens:

@<Metafont: Funções Estáticas@>+=
static struct token *new_token(int type, float value, char *name,
                               void *memory_arena){
    struct token *token;
    token = (struct token *) Walloc_arena(memory_arena, sizeof(struct token));
    if(token == NULL)
        goto error_no_memory;
    token -> type = type;
    token -> value = value;
    if(name != NULL){
        size_t name_size;
        name_size =  strlen(name) + 1;
        token -> name = Walloc_arena(memory_arena, name_size);
        if(token -> name == NULL)
            goto error_no_memory;
        memcpy(token -> name, name, name_size);
    }
    else
        token -> name = name;
    token -> prev = token -> next = NULL;
    @<Metafont: Construção de Token@>
    return token;
error_no_memory:
    fprintf(stderr, "ERROR (0): Not enough memory to parse METAFONT "
            "source. Please, increase the value of %s "
            "at conf/conf.h.\n",
            (memory_arena == _user_arena)?"W_MAX_MEMORY":
            "W_INTERNAL_MEMORY");
    return NULL;
}
#define new_token_number(a) new_token(NUMERIC, a, NULL, _internal_arena)
#define new_token_string(a) new_token(STRING, 0.0, a, _internal_arena)
#define new_token_symbol(a) new_token(SYMBOL, 0.0, a, _internal_arena)
@

Caso queiramos imprimir uma lista de tokens para fins de depuração,
criaremos:

@<Metafont: Funções Estáticas@>+=
#ifdef W_DEBUG_METAFONT
void debug_token_list(struct token *list){
  struct token *tok = list;
  while(tok != NULL){
    switch(tok -> type){
    case SYMBOL:
      printf(" [%s] ", tok -> name);
      break;
    case STRING:
      printf(" \"%s\" ", tok -> name);
      break;
    case NUMERIC:
      printf(" %f ", tok -> value);
      break;
    }
    // Warn if linked list is broken
    if(tok -> next != NULL)
      if(tok -> next -> prev != tok)
        printf("\033[0;31mX\033[0m");
    tok = tok -> next;
  }
}
#endif
@

Com base nisso já podemos escrever a nossa função de analizador
léxico. Basicamente ela irá sempre retornar o próximo token lido. Ela
é construída diretamente à partir do autômato finito que pode ser
definido à partir das regras vistas acima sobre como identificar cada
token:

@<Metafont: Funções Estáticas@>+=
static struct token *next_token(struct metafont *mf){
    char buffer[512];
    int buffer_position = 0, number_of_dots = 0;
    char current_char, next_char;
    char family[56];
    bool valid_char;
    start:
    current_char = read_char(mf);
    switch(current_char){
    case '\0': return NULL;
    case ' ': case '\n': goto start; // Ignora espaço (regra 01:a)
    case '.':
        next_char = peek_char(mf);
        if(next_char == '.'){
            memcpy(family, ".", 2);
            break;
        }
        else if(isdigit(next_char))
            goto numeric;
        else
            goto start; // Ignora '.' nestes casos (Regra 01:b)
    case '%': // (Regra 02)
        while(current_char != '\n' && current_char != '\0')
            current_char = read_char(mf);
        goto start;
    case '0': case '1': case '2': case '3': case '4': case '5':
    case '6': case '7': case '8': case '9':
        {
        numeric: // Regra 03: Vai retornar um token numérico
            for(;;){
                buffer[buffer_position] = current_char;
                buffer_position = (buffer_position + 1) % 512;
                if(current_char == '.')
                    number_of_dots ++;
                next_char = peek_char(mf);
                if((next_char == '.' && number_of_dots ==  1) ||
                   (next_char != '.' && !isdigit(next_char))){
                    buffer[buffer_position] = '\0';
                    return new_token_number(atof(buffer));
                }
                current_char = read_char(mf);
            }
        }
    case '"': // Regra 04: Strings
        current_char = read_char(mf);
        while(current_char != '"' && current_char != '\0'){
            if(current_char == '\n'){
                mf_error(mf, "Incomplete string. "
                         "Strings should finish on the same line"
                         " as they began.");
                return NULL;
            }
            buffer[buffer_position] = current_char;
            buffer_position = (buffer_position + 1) % 512;
            current_char = read_char(mf);
        }
        buffer[buffer_position] = '\0';
        return new_token_string(buffer);
    case '(': case ')': case ',': case ';': // Regra 05: Tokens caracteres
        buffer[buffer_position] = current_char;
        buffer_position = (buffer_position + 1) % 512;
        buffer[buffer_position] = '\0';
        return new_token_symbol(buffer);
    case 'a': case 'b': case 'c': case 'd': case 'e': case 'f': case 'g':
    case 'h': case 'i': case 'j': case 'k': case 'l': case 'm': case 'n':
    case 'o': case 'p': case 'q': case 'r': case 's': case 't': case 'u':
    case 'v': case 'w': case 'x': case 'y': case 'z': case '_': case 'A':
    case 'B': case 'C': case 'D': case 'E': case 'F': case 'G': case 'H':
    case 'I': case 'J': case 'K': case 'L': case 'M': case 'N': case 'O':
    case 'P': case 'Q': case 'R': case 'S': case 'T': case 'U': case 'V':
    case 'W': case 'X': case 'Y': case 'Z':
      memcpy(family, "abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ", 54);
      break;
    case '<': case '=': case '>': case ':': case '|':
        memcpy(family, "<=>:|", 6);
        break;
    case '`': case '\'':
        memcpy(family, "`'", 3);
        break;
    case '+': case '-':
        memcpy(family, "+-", 3);
        break;
    case '/': case '*': case '\\':
        memcpy(family, "/*\\", 4);
        break;
    case '!': case '?':
        memcpy(family, "!?", 3);
        break;
    case '#': case '&': case '@@': case '$':
        memcpy(family, "#&@@$", 5);
        break;
    case '[':
        memcpy(family, "[", 2);
        break;
    case ']':
        memcpy(family, "]", 2);
        break;
    case '{': case '}':
        memcpy(family, "{}", 3);
        break;
    case '~': case '^':
        memcpy(family, "~^", 3);
        break;
    default:
        mf_error(mf, "Text line contains an invalid character.");
        return NULL;
    }
    // Se ainda estamos aqui, temos um token composto a tratar
    do{
        char *c = family;
        buffer[buffer_position] = current_char;
        buffer_position = (buffer_position + 1) % 512;
        next_char = peek_char(mf);
        valid_char = false;
        while(*c != '\0'){
            if(*c == next_char){
                valid_char = true;
                current_char = read_char(mf);
                break;
            }
            c ++;
        }
    }while(valid_char);
    buffer[buffer_position] = '\0';
    return new_token_symbol(buffer);
}
@

Na prática estaremos com muita frequência formando listas encadeadas
de tokens à medida que formos interpretando eles de um código-fonte ou
caso queiramos armazenar o significado de uma macro. Para ajudar com
isso, usaremos as funções para concatenar uma lista de tokens na
outra:

@<Metafont: Funções Estáticas@>+=
// Coloca sequência de tokens 'after' após a sequência de tokens 'before'
static void concat_token(struct token **before, struct token *after){
  struct token *head = *before;
  if(*before == NULL){
    *before = after;
    return;
  }
  if(after == NULL)
    return;
  while(head -> next != NULL)
    head = head -> next;
  head -> next = after;
  after -> prev = head;
}
@

Além de concatenar, criar uma cópia de uma lista de tokens pode ser
bastante útil, especialmente em casos nos quais podemos querer mover
tokens de uma arena de memória para outra ou quando queremos extrair
elementos de uma lista de tokens sem desfazer aquela lista:

@<Metafont: Funções Estáticas@>+=
// Coloca sequência de tokens 'after' após a sequência de tokens 'before'
static struct token *copy_token_list(struct token *list, void *memory_arena){
  struct token *ret, *last_created = NULL, *current;
  current = list;
  if(current == NULL)
    return NULL;
  ret = new_token(current -> type, current -> value, current -> name,
		  memory_arena);
  last_created = ret;
  current = current -> next;
  while(last_created != NULL && current != NULL){
    last_created -> next = new_token(current -> type, current -> value,
				     current -> name, memory_arena);
    last_created = last_created -> next;
    current = current -> next;
  }
  return ret;
}
@


@*1 Declarações e Expansões.

Um programa METAFONT tem a seguinte aparência:

\alinhaverbatim
<Programa> --> <Lista de Declarações> end
           |-> <Lista de Declarações> dump
\alinhanormal

Não iremos diferenciar os dois tipos de progrma. Trataremos da mesma
forma tanto os terminados em \monoespaco{end} como os terminados em
\monoespaco{dump}. No METAFONT original o segundo tipo de programa
servia para gerar um arquivo com várias definições já pré-processadas
para serem carregadas mais rápido. Mas no nosso cenário isso não fará
sentido. Então podemos tratar os tokens \monoespaco{end} e
\monoespaco{dump} como sinônimos.

Já a lista de declarações tem a forma:

\alinhaverbatim
<Lista de Declarações> --> <Vazio>
                       |-> <Declaração> ; <Lista de Declarações>
\alinhanormal

Isso significa que o menor programa possível é um formado apenas por
\monoespaco{end} ou \monoespaco{dump}. Tal programa não faz nada. Mas
todos os demais programas são mais interessantes e são formados por
uma lista de declarações separadas pelo token simbólico de
ponto-e-vírgula.

Sabendo disso, além de uma função que apenas retorna tokens, seria
interessante se houvesse uma que retorna listas de tokens que formam
uma declaração. Para isso, supostamente deveríamos ler tokens
encadeados até encontrarmos o ponto-e-vírgula final e aí retornamos
ele. Mas as coisas não são tão diretas. Existem algumas poucas
declarações que podem conter pontos-e-vírgulas dentro delas. E existem
alguns tokens que não são primitivos, mas representam macros que devem
ser substituídos por listas de outros tokens. Às vezes um único token
deve ser expandido antes de chegar no interpretador e ele representa
dezenas de declarações.

Sendo assim, nossa função deve ficar responsável por expandir
tokens. E sempre retornar uma única declaração, guardando os tokens
sobressalentes para retornarmos depois, após os expandirmos também.

Primeiro vamos criar uma estrutura METAFONT, que representa tudo o que
é armazenado pelo nosso interpretador. Ali dentro podemos armazenar
qualquer token já lido, e que está pendente para ser
interpretado. Também armazenaremos em alguns casos tokens passados,
caso tenhamos necessidade de armazená-los em alguns contextos:

@<METAFONT: Estrutura METAFONT@>+=
struct token *pending_tokens, *past_tokens;
@


Essa estrutura será inicializada por:

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> pending_tokens = NULL;
structure -> past_tokens = NULL;
@

Agora vamos nos concentrar apenas na função que ficará responsável por
obter o próximo token (seja um já lido, mas ainda não interpretado, ou
um que ainda precisa ser lido de uma string) e expandi-lo:

@<Metafont: Funções Estáticas@>+=
@<Metafont: Função Estática expand_token@>
static struct token *get_token(struct metafont *mf){
    struct token *first_token = NULL;
    // Obtemos o primeiro token
    if(mf -> pending_tokens){
        first_token = mf -> pending_tokens;
        first_token -> next -> prev = NULL;
        mf -> pending_tokens = first_token -> next;
        first_token -> next = NULL;
    }
    else{
         first_token = next_token(mf);
    }
    while(expand_token(mf, &first_token));
    return first_token;
}
@

Por fim, podemos fazer a nossa função que separa uma declaração:

@<Metafont: Funções Estáticas@>+=
static struct token *get_statement(struct metafont *mf){
    struct token *first_token, *current_token;
    first_token = get_token(mf);
    current_token = first_token;
    // Se o primeiro token é um NULL, 'end' ou 'dump', terminamos de ler:
    if(current_token == NULL ||
       (current_token -> type == SYMBOL &&
       (!strcmp(current_token -> name, "end") ||
        !strcmp(current_token -> name, "dump")))){
        mf_end(mf);
        return NULL;
    }
    // Se não, vamos expandindo cada token até acharmos o fim da declaração
    while(1){
        if(current_token -> type == SYMBOL &&
           !strcmp(current_token -> name, ";"))
            break;
        // Se não saímos do loop, temos que ir para o próximo token
        if(current_token -> next == NULL){
            if(mf -> pending_tokens == NULL){
                current_token -> next = next_token(mf);
            }
            else{
                current_token -> next = mf -> pending_tokens;
                mf -> pending_tokens = mf -> pending_tokens -> next;
                current_token -> next -> next = NULL;
            }
        }
        if(current_token -> next == NULL)
            goto source_incomplete_or_with_error;
        current_token -> next -> prev = current_token;
        current_token = current_token -> next;
        while(expand_token(mf, &current_token));
    }
    // Obtida declaração no loop acima, finalizando
    if(current_token -> next != NULL){
        current_token -> next -> prev = NULL;
        if(mf -> pending_tokens == NULL)
            mf -> pending_tokens = current_token -> next;
        else
            concat_token(&(mf -> pending_tokens), current_token -> next);
    }
    current_token -> next = NULL;
    @<Metafont: Imediatamente após gerarmos uma declaração completa@>
    return first_token;
source_incomplete_or_with_error:
    mf_error(mf, "Source with error or incomplete, aborting.");
    printf("current: %s first: %s\n", current_token -> name, first_token -> name);
    return NULL;
}
@

Fazendo isso, por fim podemos terminar a estrutura básica da leitura e
interpretação de um código METAFONT na forma de uma string por meio da
função abaixo que fica obtendo declarações e as executa:

@<Metafont: Parser@>=
@<Metafont: Função run_single_statement@>
void run_statements(struct metafont *mf){
    struct token *statement;
    bool end_execution = false, first_loop = (mf -> parent == NULL);
    while(!end_execution){
        if(mf -> pending_tokens == NULL && mf -> parent == NULL)
            _iWbreakpoint();
        if(first_loop){
            @<Metafont: Antes de Obter a Primeira Declaração@>
            first_loop = false;
        }
        @<METAFONT: Imediatamente antes de ler próxima declaração@>
        statement = get_statement(mf);
        if(statement == NULL)
            end_execution = true;
        else{
            run_single_statement(&mf, statement);
        }
        @<METAFONT: Imediatamente após executar declaração@>
        if(mf -> pending_tokens == NULL && mf -> parent == NULL)
            _iWtrash();
    }
    @<Metafont: Após terminar de interpretar um código@>
}
@

E com isso encerramos a estrutura básica. Claro, nós ainda não
definimos o que faz a função que executa uma única declaração
METAFONT. O trabalho ao longo deste capítulo será definir isso e para
tal teremos que checar todos os tipos de declarações existentes na
linguagem. Mas podemos começar fazendo ela compreender o tipo mais
simples de declaração: a declaraçãovazia formada por um único
ponto-e-vírgula. Semanticamente ela é uma declaração que pede para o
nosso interpretador METAFONT não fazer nada:

@<Metafont: Função run_single_statement@>=
void run_single_statement(struct metafont **mf, struct token *statement){
#ifdef W_DEBUG_METAFONT
    {
        int depth = 0;
        struct metafont *p = *mf;
        while(p -> parent != NULL){
            p = p -> parent;
            depth ++;
        }
        printf("Global vardefs:");
        _debug_trie_values("", p -> vardef);
        printf("\n");
        printf("Declared variables:");
        p = *mf;
        while(p -> parent != NULL){
          _debug_trie_values("", p -> variable_types);
          p = p -> parent;
        }
        _debug_trie_values("", p -> variable_types);
        printf("\n");
        printf("METAFONT: Statement:  (Depth: %d)\n", depth);
        while(p != *mf){
            printf("                     ");
            debug_token_list(p -> past_tokens);
            printf(" [begingroup]\n");
            p = p -> child;
        }
        printf("                  -> ");
        debug_token_list(statement);
        printf("\n");
        printf("                     ");
        debug_token_list((*mf) -> pending_tokens);
        printf("\n");
    }
#endif
    if(statement -> type == SYMBOL && !strcmp(statement -> name, ";"))
        return;
    @<Metafont: Remover e Tratar token endgroup@>
    @<Metafont: Executa Declaração@>
    @<Metafont: Prepara Retorno de Expressão Composta@>
    mf_error(*mf, "Isolated expression. I couldn't find a = or := after it.");
    return;
error_no_memory_user:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
            "value of W_MAX_MEMORY at conf/conf.h\n");
    exit(1);
error_no_memory_internal:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
            "value of W_INTERNAL_MEMORY at conf/conf.h\n");
    exit(1);
}
@

Outra coisa que ainda não definimos é a função que expande um único
token para um ou mais tokens. Essa é a implementação das macros de
METAFONT, as quais serão definidas logo em seguida.

@<Metafont: Função Estática expand_token@>=
bool expand_token(struct metafont *mf, struct token **first_token){
     // todo
     (void) mf; // Evita aviso de compilação
     (void) first_token; // Evita aviso de compilação
     return false;
}
@

Com isso, podemos enfim fazer cada estrutura Metafont executar logo
após sua inicialização:

@<METAFONT: Executa Arquivo de Inicialização@>=
if(parent == NULL){
  run_statements(structure);
}
@

@*1 Quantidades Internas.

Antes de começar implementando as coisas mais complexas da linguagem,
é sempre melhor começarmos com as funcionalidades mais simples que são
possíveis à partir de nosso estado atual. Somente quando novas
funcionalidades simples não puderem ser implementadas é que iremos
avançar implementando coisas mais complexas.

A primeira coisa mais simples de ser implementada são as quantidades
internas. Elas podem ser vistas como variáveis que sempre irão
armazenar um número e que deverão ser acessadas da forma mais rápida
possível. Quando as declaramos, elas sempre devem começar tendo o
valor zero.

Basicamente nós iremos armazenar dentro da estrutura METAFONT uma
árvore trie para podermos acessar tais quantidades:

@<METAFONT: Estrutura METAFONT@>=
struct _trie *internal_quantities;
@

A qual deverá ser inicializada como vazia para qualquer inicializ ação
de estrutura METAFONT:

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> internal_quantities = _new_trie(arena);
if(structure -> internal_quantities == NULL)
    goto error_no_memory;
@

Mas se estamos declarando a primeira estrutura METAFONT, então ela
deverá ser inicializada já contendo algumas quantidades internas, pela
própria especificação da linguagem. Todas elas devem começar valendo
zero, exceto por \monoespaco{year}, \monoespaco{month},
\monoespaco{day} e \monoespaco{time} que receberão valores iniciais
baseados na data e hora do momento da inicialização. E
\monoespaco{boundarychar} deve começar valendo -1:

@<METAFONT: Inicializa estrutura METAFONT@>+=
if(structure -> parent == NULL){
    struct _trie *T = structure -> internal_quantities;
    time_t current_time;
    unsigned int year, month, day, time_in_minutes;
    struct tm *date;
    time(&current_time);
    date = localtime(&current_time);
    year = date -> tm_year + 1900;
    month = date -> tm_mon + 1;
    day = date -> tm_mday;
    time_in_minutes = 60 * date -> tm_hour + date -> tm_min;
    _insert_trie(T, arena, DOUBLE, "tracingtitles", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingequations", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingcapsules", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingchoices", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingspecs", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingpens", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingcommands", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingrestores", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingmacros", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingedges", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingoutput", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingonline", 0.0);
    _insert_trie(T, arena, DOUBLE, "tracingstats", 0.0);
    _insert_trie(T, arena, DOUBLE, "pausing", 0.0);
    _insert_trie(T, arena, DOUBLE, "showstopping", 0.0);
    _insert_trie(T, arena, DOUBLE, "proofing", 0.0);
    _insert_trie(T, arena, DOUBLE, "turningcheck", 0.0);
    _insert_trie(T, arena, DOUBLE, "warningcheck", 0.0);
    _insert_trie(T, arena, DOUBLE, "smoothing", 0.0);
    _insert_trie(T, arena, DOUBLE, "autorounding", 0.0);
    _insert_trie(T, arena, DOUBLE, "glanularity", 0.0);
    _insert_trie(T, arena, DOUBLE, "glanularity", 0.0);
    _insert_trie(T, arena, DOUBLE, "fillin", 0.0);
    _insert_trie(T, arena, DOUBLE, "year", (double) year);
    _insert_trie(T, arena, DOUBLE, "month", (double) month);
    _insert_trie(T, arena, DOUBLE, "day", (double) day);
    _insert_trie(T, arena, DOUBLE, "time", (double) time_in_minutes);
    _insert_trie(T, arena, DOUBLE, "charcode", 0.0);
    _insert_trie(T, arena, DOUBLE, "charext", 0.0);
    _insert_trie(T, arena, DOUBLE, "charwd", 0.0);
    _insert_trie(T, arena, DOUBLE, "charht", 0.0);
    _insert_trie(T, arena, DOUBLE, "chardp", 0.0);
    _insert_trie(T, arena, DOUBLE, "charic", 0.0);
    _insert_trie(T, arena, DOUBLE, "chardx", 0.0);
    _insert_trie(T, arena, DOUBLE, "chardy", 0.0);
    _insert_trie(T, arena, DOUBLE, "designsize", 0.0);
    _insert_trie(T, arena, DOUBLE, "hppp", 0.0);
    _insert_trie(T, arena, DOUBLE, "vppp", 0.0);
    _insert_trie(T, arena, DOUBLE, "xoffset", 0.0);
    _insert_trie(T, arena, DOUBLE, "yoffset", 0.0);
    _insert_trie(T, arena, DOUBLE, "boundarychar", -1.0);
}
@

Várias destas quantidades internas, dependendo do valor, mudam o
comportamento do METAFONT. Contudo, nossa implementação não irá se
preocupar em usar todas elas assim como o METAFONT original
faz. Contudo, elas estarão presentes e poderão ser conferidas e
checadas pelos programas.

Agora podemos começar a falar sobre o que é uma declaração. A
gramática de uma declaração começa com a regra:

\alinhaverbatim
<Declaração> --> <Vazio>
             |-> <Título>
             |-> <Equação>
             |-> <Atribuição>
             |-> <Declaração de Variáveis>
             |-> <Definição>
             |-> <Declaração Composta>
             |-> <Comando>
\alinhanormal

Dentre elas, já implementamos a declaração vazia. Diante das demais,
algumas das mais simples são comandos (ainda que muitos dos comandos
sejam mais complexos e estejamos deixando pra depois). Os comandos são
instruções diversas que damos ao nosso interpretador. Os diferentes
comandos são:

\alinhaverbatim
<Comando> --> <Comando save>
          |-> <Comando interim>
          |-> <Comando newinternal>
          |-> <Comando randomseed>
          |-> <Comando let>
          |-> <Comando delimiters>
          |-> <Comando de Proteção>
          |-> <Comando everyjob>
          |-> <Comando show>
          |-> <Comando de Mensagem>
          |-> <Comando de Modo>
          |-> <Comando de Imagem>
          |-> <Comando de Visualização>
          |-> <Comando openwindow>
          |-> <Comando shipout>
          |-> <Comando Especial>
          |-> <Comando de Métrica de Fonte>
\alinhanormal

Como estamos interessados no momento nas quantidades internas, o
comando que nos interessa é o que permite declarar novas quantidades
internas. Tais quantidades sempre irão começar com o valor zero:

\alinhaverbatim
<Comando newinternal> --> newinternal <lista de Tokens Simbólicos>
<lista de Tokens Simbólicos> --> <Token Simbólico>
                             |-> <Lista de Tokens Simbólicos> , <Token Simbólico>
\alinhanormal

Cada token simbólico contém o nome de uma das novas quantidades
internas que serão criadas. O nosso trabalho então será primeiro
definir uma função que identifica listas de tokens simbólicos. Esta
função irá consumir os tokens lidos por eles, removendo a vírgula
separadora que esperamos existir entre eles. Se após um dos tokens nós
não encontrarmos uma vírgula, nós encerramos:

@<Metafont: Funções Estáticas@>=
static struct token *symbolic_token_list(struct metafont *mf,
                                         struct token **token){
    struct token *first_token = *token, *current_token;
    current_token = first_token;
    while(1){
        // Se o token atual não for simbólico, isso é um erro.
        if(current_token == NULL || current_token -> type != SYMBOL){
            mf_error(mf, "Missing symbolic token.");
            return NULL;
        }
        // Se o próximo token não for uma vírgula, terminamos de ler a
        // lista
        if(current_token -> next == NULL ||
           current_token -> next -> type != SYMBOL ||
           strcmp(current_token -> next -> name, ",")){
            *token = current_token -> next;
            current_token -> next = NULL;
            return first_token;
        }
        // Caso contrário, consumimos a vírgula e ligamos o token
        // atual no próximo:
        if(current_token -> next -> next != NULL)
            current_token -> next -> next -> prev = current_token;
        current_token -> next = current_token -> next -> next;
        current_token = current_token -> next;
    }
}
@

Tendo uma função capaz de consumir e interpretar corretamente o <Lista
de Tokens Simbólicos>, então podemos identificar e interpretar
corretamente o <Comando newinternal>:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "newinternal")){
    struct token *current_token = statement -> next;
    struct token *list = symbolic_token_list(*mf, &current_token);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(current_token == NULL || current_token -> type != SYMBOL ||
       strcmp(current_token -> name, ";")){
        mf_error(*mf, "Extra token at newinternal command.");
        return;
    }
    // Executa o comando
    while(list != NULL){
        _insert_trie((*mf) -> internal_quantities, _user_arena, DOUBLE,
                     list -> name, 0.0);
        list = list -> next;
    }
    return;
}
@


@*1 O Comando \monoespaco{everyjob}.

Vamos implementar o próximo comando fácil existente. A gramática
do Comando \monoespaco{everyjob} é:

\alinhaverbatim
<Comando everyjob> --> everyjob <Token Simbólico>
\alinhanormal

O propósito deste comando é fazer com que o token simbólico passado
para ele seja inserido automaticamente toda vez que invocamos o
METAFONT para interpretar um novo código-fonte.

Para isso, tudo o que temos a fazer é armazenar dentro da própria
estrutura METAFONT o nome do token a ser armazenado. Usaremos a
seguinte variável:

@<METAFONT: Estrutura METAFONT@>=
char *everyjob_token_name;
@

Na inicialização manteremos o valor como sendo nulo:

@<METAFONT: Inicializa estrutura METAFONT@>+=
structure -> everyjob_token_name = NULL;
@

E iremos criar e armazenar o nome do token caso o comando em si seja
invocado:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "everyjob")){
    // Deve haver um token simbólico após o comando
    if(statement -> next == NULL || statement -> next -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    // Se aconteceu do token definido como everyjob ser um ';', pegamos mais um:
    if(!strcmp(statement -> next -> name, ";")){
        statement -> next -> next = get_statement(*mf);
        if(statement -> next -> next != NULL)
            statement -> next -> next -> prev = statement -> next;
    }
    // E em seguida deve haver um ponto-e-vírgula:
    if(statement -> next -> next == NULL ||
       statement -> next -> next -> type != SYMBOL ||
       strcmp(statement -> next -> next -> name, ";")){
        mf_error(*mf, "Extra tokens found after everyjob.");
        return;
    }
    // Se não ocorreu erro, armazena o nome do token:
    if((*mf) -> everyjob_token_name == NULL ||
       strlen((*mf) -> everyjob_token_name) < strlen(statement -> next -> name))
        (*mf) -> everyjob_token_name = (char *)
            Walloc(strlen(statement -> next -> name) + 1);
    memcpy((*mf) -> everyjob_token_name, statement -> next -> name,
           strlen(statement -> next -> name) + 1);
    return;
}
@

A ideia é que tendo esse comando, antes de executarmos a primeira
declaração de um código METAFONT, iremos inserir o token que foi
registrado como o primeiro a ser inserido:

@<Metafont: Antes de Obter a Primeira Declaração@>=
if(mf -> everyjob_token_name != NULL)
    mf -> pending_tokens = new_token_symbol(mf -> everyjob_token_name);
@

@*1 Comandos de Modo.

No METAFONT original, assumia-se que a linguagem era interpretada por
um aplicativo de linha de comando e os Comandos de Modo serviam para
determinar quanto de interação com o usuário o programa iria ter em
caso de erro. Atualmente isso não faz sentido, pois a nossa
implementação da linguagem METAFONT não está ligada à um aplicativo de
linha de comando. Por causa disso, nós apenas iremos ignorar este tipo
de comando.

De qualquer forma, como eles fazem parte da linguagem, devemos checar
a sintaxe deles e imprimir mensagens de erro se houver alguma coisa
errada. A gramática de tais comandos é:

\alinhaverbatim
<Comando de Modo> --> batchmode | nonstopmode | scrollmode | errorstopmode
\alinhanormal

É uma regra gramatical bastante simples. Sendo assim, basta checarmos
que tais comandos devem aparecer isolados sem nenhum outro token até o
próximo fim de declaração:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL &&
   (!strcmp(statement -> name, "batchmode") ||
    !strcmp(statement -> name, "nonstopmode") ||
    !strcmp(statement -> name, "scrollmode") ||
    !strcmp(statement -> name, "errorstopmode"))){
    // Garante que próximo token é um ';'
    if(statement -> next == NULL || statement -> next -> type != SYMBOL ||
       strcmp(statement -> next -> name, ";")){
        mf_error(*mf, "Extra tokens found after mode command.");
        return;
    }
    return;
}
@

@*1 Declarações Compostas.

Uma declaração pode ser composta por várias outras declarações. A
regra gramatical para isso é:

\alinhaverbatim
<Declaração Composta> --> begingroup
                          <Lista de Declarações><Declaração que Não é Título>
                          endgroup
\alinhanormal

Notar que a declaração final dentro do grupo que forma a declaração
composta, além de não poder ser um título, não é terminada com
ponto-e-vírgula. Embora a presença de um ponto-e-vírgula não faça
diferença alguma semanticamente.

Dentro de um grupo, algumas variáveis podem ser declaradas como sendo
locais daquele grupo. Por isso, quando entramos em um grupo devemos
fazer duas coisas: criar uma nova estrutura METAFONT que será filha da
atual e devemos incrementar lá um contador que armazena a profundidade
em grupos na qual estamos (pois um grupo pode estar dentro do
outro). Já ao encontrarmos um \monoespaco{endgroup} devemos voltar
para a estrutura METAFONT anterior e decrementar o contador de
profundidade.

Não iremos preocupar agora em salvar variáveis ou com o escopo delas
ainda. Quando chegarmos nos comandos que servem para isso,
implementaremos tal funcionalidade. No momento nos preocuparemos
apenas em deixar tudo pronto para que tais programas funcionem.

A primeira coisa a fazer é apenas checar se quando temos uma nova
declaração a ser executada, ela começa com o token
\monoespaco{begingroup}. Neste caso, consumiremos apenas ela e
devolveremos o resto para o começo da lista de tokens que estão
pendentes para serem interpretados. E ao consumi-la iremos trocar a
versão atual da estrutura METAFONT por outra.

Vamos agora detectar mais um tipo de erro: se nós estamos saindo de
nosso programa após encontrarmos um \monoespaco{end},
\monoespaco{dump} ou o fim do código, então devemos checar se estamos
em uma estrutura METAFONT sem pai. Se não estivermos, isso significa
que estamos encerrando o programa no meio de um grupo não-finalizado:


@<Metafont: Chegamos ao Fim do Código-Fonte@>=
if(mf -> parent != NULL){
    mf_error(mf, "A group begun and never ended.");
}
@

Vamos agora tratar o caso de encontrarmos um \monoespaco{begingroup}
no começo de uma declaração. Além de criar uma nova estrutura METAFONT
filha, passamos para ela os tokens pendentes que antes estavam em seu
pai.

@<Metafont: Executa Declaração@>=
  if(statement -> type == SYMBOL && !strcmp(statement -> name, "begingroup")){
    Wbreakpoint_arena(metafont_arena);
    *mf = _new_metafont(*mf, (*mf) -> filename);
    statement = statement -> next;
    statement -> prev = NULL;
    (*mf) -> pending_tokens = statement;
    concat_token(&((*mf) -> pending_tokens),
                 (*mf) -> parent -> pending_tokens);
    (*mf) -> parent -> pending_tokens = NULL;
    return;
}
@

Já tratar o comando \monoespaco{endgroup} é mais complicado, pois ele
aparece tipicamente na penúltima posição (antes de um
ponto-e-vírgula), podendo aparecer na última caso o código esteja
incorreto por estar incompleto. Outras vezes, podemos estar dentro de
uma expressão, caso em que ele aparece no meio ou no começo da lista
de tokens. Sendo assim, vamos criar uma forma da fuinção que monta uma
nova declaração avisar o nosso interpretador caso ela leia um
\monoespaco{endgroup} na penúltima ou última posição:

@<METAFONT: Estrutura METAFONT@>=
int hint;
@

Inicialmente essa variável \monoespaco{hint} deve estar nula. E deve
ser tornada nula imediatamente antes de ler a próxima declaração:

@<METAFONT: Inicializa estrutura METAFONT@>+=
structure -> hint = 0;
@

@<METAFONT: Imediatamente antes de ler próxima declaração@>=
mf -> hint = 0;
@

Vamos chamar o caso de termos um \monoespaco{endgroup} na declaração
atual como algo que será avisado por meio da seguinte definição:

@<Metafont: Inclui Cabeçalhos@>+=
#define HINT_ENDGROUP      1
@

Quando somos avisados que temos que encerrar o grupo, antes de
executarmos a declaração devemos remover o token de 'endgroup'
existente:

@<Metafont: Remover e Tratar token endgroup@>=
{
    struct token *aux = statement;
    if((*mf) -> hint == HINT_ENDGROUP){
      while(aux != NULL){
        if(aux -> type == SYMBOL && !strcmp(aux -> name, "endgroup")){
            if(aux -> prev != NULL)
              aux -> prev -> next = NULL;
            else
                statement = aux -> next;
            concat_token(&(aux -> next), (*mf) -> pending_tokens);
            if(aux -> next != NULL){
                (*mf) -> pending_tokens = aux -> next;
                aux -> next -> prev = NULL;
            }
            break;
        }
        aux = aux -> next;
      }
    }
}
@

E após executarmos a declaração, iremos encerrar o grupo.

@<METAFONT: Imediatamente após executar declaração@>=
if(mf -> hint == HINT_ENDGROUP){
    //struct metafont *p;
    // Caso de erro: usar endgroup sem begingroup:
    if(mf -> parent == NULL)
        mf_error(mf, "Extra 'endgroup' while not in 'begingroup'.");
    else{
        end_scope(mf);
        mf = mf -> parent;
        Wtrash_arena(metafont_arena);
    }
}
@

Só temos que tomar cuidado que se nós terminamos de interpretar um
código, mas não terminamos todos os grupos, temos o trabalho de limpar
a nossa memória antes de encerrar:

@<Metafont: Após terminar de interpretar um código@>=
while(mf -> parent != NULL){
    end_scope(mf);
    mf = mf -> parent;
    Wtrash_arena(metafont_arena);
}
@

E agora o código que faz com que se encontramos um 'endgroup'
identificado como na última ou penúltima posição de uma nova
declaração, após já terem ocorrido todas as expansões de token
possíveis, então temos que avisar nosso interpretador que ele deve
encerrar o grupo e silenciosamente remover o token
\monoespaco{endgroup} para ele não atrapalhar na interpretação da
declaração. Mas só devemos fazer isso se o primeiro token não é um
\monoespaco{begingroup}, pois a aplicação das duas regras só funciona
se forem feitas separadamente.

@<Metafont: Imediatamente após gerarmos uma declaração completa@>=
{
    struct token *aux = current_token;
    while(aux != NULL){
        if(aux -> type == SYMBOL &&
           !strcmp(aux -> name, "endgroup")){
            mf -> hint = HINT_ENDGROUP;
        }
        else if(aux -> type == SYMBOL &&
           !strcmp(aux -> name, "begingroup")){
           mf -> hint = 0;
        }
        aux = aux -> prev;
    }
}
@

@*1 O Comando \monoespaco{save}.

A grande utilidade de termos declarações compostas como as que
definimos é que podemos usar o escopo para termos variáveis
locais. Por padrão, todas as variáveis são globais, mesmo quando elas
são usadas ou declaradas dentro de um bloco. Entretanto, um token pode
passar a ser considerado local usando o Comando \monoespaco{save}. A
gramática de tal comando é:

\alinhaverbatim
<Comando save> --> save <Lista de Tokens Simbólicos>
\alinhanormal

O que é uma boa notícia, pois já temos a função que consome e extrai
os tokens de uma lista de tokens simbólicos. Este comando não declara
um tipo para o que será armazenado no identificador representado pelo
token. Vamos considerar isso como sendo do tipo ``não-declarado'',
dentre os seguintes tipos de variáveis mais comuns:

@<Metafont: Inclui Cabeçalhos@>+=
#define NOT_DECLARED -1
#define BOOLEAN       0
#define PATH          1
//#define STRING      2 // Já definido
//#define NUMERIC     3 // Já definido
#define PEN           4
#define PICTURE       5
#define TRANSFORM     6
#define PAIR          7
@

Cada estrutura METAFONT representa um escopo. E cada escopo terá a sua
própria árvore trie para indicar o tipo de suas variáveis. Assumimos
que o escopo de uma variável é o escopo mais profundo no qual o seu
tipo é declarado. Sendo assim, vamos declarar a árvore trie dos tipos
de variáveis:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *variable_types;
@

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> variable_types = _new_trie(arena);
@

O que o comando \monoespaco{save} deverá fazer então é fazer com que o
tipo de cada uma das variáveis passadas para ele passe a ser
\monoespaco{NOT\_DECLARED} no escopo atual. Mas não é só isso. Caso
alguma variável já exista no escopo atual, o seu valor anterior deve
ser esquecido. Isso significa que devemos declarar também as árvores
trie que armazenarão os valores de cada variável para que assim
possamos remover os valores caso eles já existam durante um comando
\monoespaco{save}:

@<METAFONT: Estrutura METAFONT@>+=
  struct _trie *vars[8];
@

@<METAFONT: Inicializa estrutura METAFONT@>=
{
    int i;
    // Uma trie com  valor de variáveis para cada tipo:
    for(i = 0; i < 8; i ++)
        structure -> vars[i] = _new_trie(arena);
}
@

Tendo definido e declarado todas essas coisas, enfim podemos definir o
nosso mais novo comando:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "save")){
    struct token *current_token = statement -> next;
    struct token *list = symbolic_token_list(*mf, &current_token);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(current_token == NULL || current_token -> type != SYMBOL ||
       strcmp(current_token -> name, ";")){
        mf_error(*mf, "Extra token at save command.");
        return;
    }
    // Executa o comando
    while(list != NULL){
        void *current_arena =
            ((*mf) -> parent == NULL)?_user_arena:metafont_arena;
        int current_type;
        bool already_declared = _search_trie((*mf) -> variable_types, INT,
                                             list -> name, &current_type);
        if(already_declared && current_type != NOT_DECLARED)
            _remove_trie((*mf) -> vars[current_type], list -> name);
        _insert_trie((*mf) -> variable_types, current_arena, INT, list -> name,
                     NOT_DECLARED);
        list = list -> next;
    }
    return;
}
@

Isso nos trás então a necessidade de responder: dado um nome de tipo
de variável, qual é o escopo dele? Para isso precisamos de uma função
que retorna uma estrutura METAFONT (um escopo) após receber uma
estrutura Metafont (o escopo atual) e uma string (um nome de tipo de
variável):

@<Metafont: Funções Locais Declaradas@>+=
struct metafont *get_scope(struct metafont *mf, char *type_name);
@

A função vai funcionar primeiro obtendo o prefixo, se aplicável. Se o
prefixo for diferente do nome completo a ser buscado, começamos
buscando somente por ele. O escopo da variável é então o mesmo do
prefixo. Caso contrário, buscamos então pelo nome completo. Se nada
for encontrado, então o prefixo será a estrutura Metafont inicial.

@<Metafont: Funções Estáticas@>+=
struct metafont *get_scope(struct metafont *mf, char *type_name){
  // Obter o prefixo:
  bool got_prefix = false;
  char *p = type_name;
  struct metafont *scope = mf, *last_scope = mf;
  void *dummy_result;
  while(*p != '\0'){
    if(*p == ' '){
      got_prefix = true;
      *p = '\0';
      break;
    }
    p ++;
  }
  if(got_prefix){
    while(scope != NULL){
      if(_search_trie(scope -> variable_types, VOID_P,
                      type_name, &dummy_result)){
        *p = ' ';
        return scope;
      }
      scope = scope -> parent;
    }
  }
  // No prefix found
  if(got_prefix){
    *p = ' ';
    scope = mf;
  }
  while(scope != NULL){
    if(_search_trie(scope -> variable_types, VOID_P,
                    type_name, &dummy_result)){
      return scope;
    }
    last_scope = scope;
    scope = scope -> parent;
  }
  return last_scope;
}
@


@*1 O Comando \monoespaco{delimiters}.

Nas equações e atribuições que ainda serão criadas na linguagem, é
útil que alguns tokens sejam vistos como delimitadores de
sub-extressões. Geralmente tal papel cabe aos parênteses. Assim, temos
que $(1+3)\times5$ é igual a 20, já que os parênteses como
delimitadores fazem com que façamos a soma antes da multiplicação.

O que o comendo \monoespaco{delimiters} faz é estabelecer dois tokens
como sendo delimitadores. Um deles é o começo e o outro é o fim do
delimitador. A gramática do comando é:

\alinhaverbatim
<Comando delimiters> --> delimiters <Token Simbólico> <Token Simbólico>
\alinhanormal

Geralmente o uso mais comum do comando é na declaração:

\alinhaverbatim
delimiters ( );
\alinhanormal

Que faz com que os parênteses passem a ter o comportamente que se esper adeles.

Este é um comando bastante simples. Precisaremos armazenar em uma
árvore trie todos os nomes de tokens simbólicos que servem como começo
de um delimitador e eles devem armazenar o nome do token simbólico que
serve como fim de seus delimitadores. Como os delimitadores obedecem o
escopo dos tokens, temos que checar sempre em qual escopo o
delimitador está sendo declarado.

Então primeiro criemos e inicializemos o local onde armazenaremos os
delimitadores:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *delimiters;
@

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> delimiters = _new_trie(arena);
@

Fora isso, o comando é bastante
simples:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "delimiters")){
    char *end_delimiter;
    void *current_arena;
    size_t name_size;
    struct metafont *scope = (*mf);
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    scope = get_scope(*mf, statement -> name);
    current_arena = (scope -> parent == NULL)?_user_arena:metafont_arena;
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    end_delimiter = (char *)
        Walloc_arena(current_arena,
                     name_size = strlen(statement -> name) + 1);
    if(end_delimiter == NULL){
        fprintf(stderr, "ERROR: Not enough memory to parse METAFONT. "
                "Please, increase the value of %s at conf/conf.h.\n",
                (current_arena==_user_arena)?"W_MAX_MEMORY":"W_INTERNAL_MEMORY");
        return;
    }
    memcpy(end_delimiter, statement -> name, name_size);
    _insert_trie(scope -> delimiters, current_arena, VOID_P,
                 statement -> prev -> name, (void *) end_delimiter);
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    return;
}
@

Vamos agora gerar apenas uma função auxiliar para obter o delimitador
oposto de um token, ou NULL se ele não for um delimitador:

@<Metafont: Funções Estáticas@>+=
static char *delimiter(struct metafont *mf, struct token *tok){
    char *result = NULL;
    while(mf != NULL){
        bool ret = _search_trie(mf -> delimiters, VOID_P, tok -> name,
                                (void *) &result);
        if(ret){
            return result;
        }
        mf = mf -> parent;
    }
    return NULL;
}
@

@*1 Os Comandos de Proteção.

METAFONT permiter declarar que alguns tokens nunca podem aparecer em
contextos nos quais não são interpretados imediatamente. Assim, tais
tokens nunca podem aparecer sem acusar erro dentro de condicionais
falsas, dentro da definição de macros, ou quando estão sendo passados
como parâmetro para macros sem serem expandidos antes. Por padrão
nenhum token recebe tal proteção. Mas o comando \monoespaco{outer}
torna o token protegido e o comando \monoespaco{inner} deprotege um
token tornado protegido antes. A gramática para tais comandos é:

\alinhaverbatim
<Comando de Proteção> --> outer <Lista de Tokens SImbólicos>
                      +-> inner <Lista de Tokens SImbólicos>
\alinhanormal

Como a proteção depende de escopo, cada estrutura METAFONT deve
armazenar em uma trie quais de seus tokens são protegidos:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *outer_tokens;
@

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> outer_tokens = _new_trie(arena);
@

Depois disso, podemos definir os comandos de proteção:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL &&
   (!strcmp(statement -> name, "inner") ||
    !strcmp(statement -> name, "outer"))){
    bool inner_command = (statement -> name[0] == 'i');
    statement = statement -> next;
    struct token *list = symbolic_token_list(*mf, &statement);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        mf_error(*mf, "Extra token at save command");
        return;
    }
    // Executa o comando
    while(list != NULL){
        void *current_arena;
        struct metafont *scope = get_scope(*mf, list -> name);
        current_arena = (scope -> parent == NULL)?_user_arena:metafont_arena;
        if(inner_command)
            _remove_trie((*mf) -> outer_tokens, list -> name);
        else
            _insert_trie((*mf) -> outer_tokens, current_arena, INT,
                         list -> name, 0);
        list = list -> next;
    }
    return;
}
@

Para justificar a funcionalidade implementada, o seu uso mais
frequente é a declaração:

\alinhaverbatim
outer end;
\alinhanormal

Que impede que um comando para encerrar o programa possa ser inserido
por uma macro ou ignorado de qualquer forma sem provocar um erro.

@*1 Declaração de Variáveis.

Conforme já visto na árvore trie de declarações, as variáveis podem
ser de 8 tipos, ignorando o primeiro tipo ``não-definido'' que
colocamos temporariamente após um \monoespaco{save}. Como já definimos
o escopo dos programas e já definimos a árvore trie que armazena o
tipo, podemos terminar deifnindo a declaração de nossas variáveis.

Toda variável que não e do tipo numérico precisa ser declarada antes
de ser usada. Se uma variável não-declarada for encontrada, ela será
assumida como sendo do tipo numérico. A gramática de declaraçãod e
variáveis é:

\alinhaverbatim
<Declaração de Variáveis> --> <Tipo><Lista Decl. de Var.>
<Tipo> --> boolean | string | path | pen | picture | transform | pair | numeric
<Lista Decl. de Var.> --> <Variável Declarada>
                      +-> <Lista Decl. de Var.> , <Variável Declarada>
<Variável Declarada> --> <Token Simbólico> <Sufixo Declarado>
<Sufixo Declarado> --> <Vazio>
                   +-> <Sufixo Declarado> <Tag>
                   +-> <Sufixo Declarado> [ ]
<Tag> --> <Tag Externa>
      +-> <Quantidade Interna>
\alinhanormal

Isso significa que um nome de variável pode ser composta por vários
tokens. Assim uma variável pode ser composta por um nome inicial e
qualquer quantidade de sufixo seguinte. O nome de uma variável pode
ter inclusive tokens numéricos em seu nome. Por exemplo,
\monoespaco{x1}. Ao contrário de muitas outras linguagens, este nome é
formado por dois tokens, sendo o primeiro simbólico e o segundo numérico.

Esta convenção torna automático o funcionamento de estruturas como
\monoespaco{casa.altura}, ou \monoespaco{casa.largura}. O caractere de
espaço simplesmente é ignorado em tais construções e no fim ficam
apenas dois tokens que representam duas variáveis diferentes.

Existe, contudo, uma restrição semântica: se temos uma variável
\monoespaco{x1}, a qual é um número, então todas as outras variáveis
\monoespaco{x2}, \monoespaco{x3}, etc., precisam também ser
números. Por causa disso, não é possível declarar uma variável
contendo número. Ao invés de número, deve-se usar uma declaração como:

\alinhaverbatim
numeric x[];
\alinhanormal

Que declara as infinitas variáveis que começam com \monoespaco{x} e
são seguidas por um número de representarem números. Também é
perfeitamente possível declarar:

\alinhaverbatim
string y[][]altura[];
\alinhanormal

Que representa uma declaração de todos os tokens que começam com
\monoespaco{y}, são seguidos por dois números, pelo token
\monoespaco{altura} e por um outro número como sendo do tipo string.

Na definição do quê é uma declaração permitida, nota-se que
absolutamente qualquer token simbólico pode compor a primeira parte do
nome de variável. Com relação ao seu sufixo, aí as opções são
menores. Um sufixo pode ser apenas os tokens \monoespaco{[]}, e
qualquer token simbólico que não seja uma macro e nem um token com um
significado primitivo, tal como \monoespaco{;} ou
\monoespaco{string}. Contudo, tais tokens passam a ser considerados
tags se forem usados após um comando \monoespaco{save}. Mas não são
tags se forem uma macro. E são tags se forem declarados com
\monoespaco{vardef}.

Embora estejamos mencionando construções da linguagem que ainda não
definimos, podemos definir elas rapidamente e entrar em detalhes
somenter depois. Isso será necessário para checarmos se uma variável
declarada realmente tem um nome válido. As seguintes árvores trie irão
armazenar os diferentes tipos de macros:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *def, *vardef, *primarydef, *secondarydef, *tertiarydef;
@

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> def = _new_trie(arena);
structure -> vardef = _new_trie(arena);
structure -> primarydef = _new_trie(arena);
structure -> secondarydef = _new_trie(arena);
structure -> tertiarydef = _new_trie(arena);
@

E agora sim a seguinte função checa se um token recebido é uma tag:

@<Metafont: Funções Estáticas@>=
static bool is_tag(struct metafont *mf, struct token *token){
    struct metafont *scope = mf;
    void *dummy;
    if(token == NULL)
        return false;
    while(scope != NULL){
        if(_search_trie(scope -> variable_types, VOID_P,
                        token -> name, &dummy))
            return true;
        if(_search_trie(scope -> internal_quantities, VOID_P,
                        token -> name, &dummy))
            return true;
        if(_search_trie(scope -> def, VOID_P,
                        token -> name, &dummy))
            return false;
        if(_search_trie(scope -> vardef, VOID_P,
                        token -> name, &dummy))
            return true;
        if(_search_trie(scope -> primarydef, VOID_P,
                        token -> name, &dummy))
            return false;
        if(_search_trie(scope -> secondarydef, VOID_P,
                        token -> name, &dummy))
            return false;
        if(_search_trie(scope -> tertiarydef, VOID_P,
                        token -> name, &dummy))
            return false;
        scope = scope -> parent;
    }
    if(_search_trie(primitive_sparks, VOID_P,
                    token -> name, &dummy))
        return false;
    else
        return true; // Variável não-declarada
}
@

Para essa nossa checagem, teremos que checar também uma lista de
valores primitivos que sabemos que não são tags, por estarem
reservados para a linguagem. Como a linguagem chama de ``spark'' tudo
que não é uma tag, iremos armazená-las na seguinte trie:

@<Metafont: Variáveis Estáticas@>+=
static struct _trie *primitive_sparks;
@

Vamos também definir enfim uma função de inicialização para
preenchermos tal árvore:

@<Metafont: Inicialização@>=
    primitive_sparks = _new_trie(_user_arena);
    _insert_trie(primitive_sparks, _user_arena, INT, "end", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "dump", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, ";", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, ",", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "newinternal", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "everyjob", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "batchmode", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "nonstopmode", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "scrollmode", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "errorstopmode", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "begingroup", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "endgroup", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "save", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "delimiters", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "outer", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "inner", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "[", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "]", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "boolean", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "string", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "path", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "pen", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "picture", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "transform", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "pair", 0);
    _insert_trie(primitive_sparks, _user_arena, INT, "numeric", 0);
    @<Metafont: Declara Nova Spark@>
#ifdef W_DEBUG_METAFONT
        printf("METAFONT Sparks:");
        _debug_trie_values("", primitive_sparks);
        printf("\n");
#endif
@

A definição acima conta com todas as sparks que já definimos em nossa
gramática. Outras ainda serão inseridas.

Com isso vamos escrever agora um código para interpretar e consumir
uma variável declarada e armazena em 'dst' uma string com o nome dela,
com cada sufixo separado por espaços:

@<Metafont: Funções Estáticas@>=
void declared_variable(struct metafont *mf, struct token **token,
                       char *dst, size_t dst_size){
    struct token *first_token = *token, *current_token;
    size_t dst_length = 0, aux_length;
    // O primeiro token apenas deve ser simbólico
    if(first_token == NULL || first_token -> type != SYMBOL){
        mf_error(mf, "Missing symbolic token.");
        return;
    }
    current_token = first_token -> next;
    dst_length = strlen(first_token -> name);
    if(dst_length + 1 > dst_size){
        mf_error(mf, "Token too big: %s\n", first_token -> name);
        return;
    }
    memcpy(dst, first_token -> name, dst_length + 1);
    while(current_token != NULL){
        // Se um token não for uma tag ou '[' e ']', encerremos
        if(current_token -> type != SYMBOL ||
           (!is_tag(mf, current_token) &&
            (strcmp(current_token -> name, "[") &&
             strcmp(current_token -> name, "]")))){
            current_token = current_token -> prev;
            break;
        }
        // Se tivermos um '[' sem ter um ']' depois, também é erro:
        if(!strcmp(current_token -> name, "[") &&
           (current_token -> next == NULL ||
            strcmp(current_token -> next -> name, "]"))){
            mf_error(mf, "Illegal suffix at token declaration.");
            current_token = current_token -> prev;
            break;
        }
        // Se tivermos um ']' sem ser precedido por um '[', também:
        if(!strcmp(current_token -> name, "]") &&
           (current_token -> prev == NULL ||
            strcmp(current_token -> prev -> name, "["))){
            mf_error(mf, "Illegal suffix at token declaration.");
            current_token = current_token -> prev;
            break;
        }
        // Se não, apenas incrementa o contador do tamanho do nome do token
        aux_length = strlen(current_token -> name);
	if(dst_length + aux_length + 2 > dst_size){
            mf_error(mf, "Token too big: %s %s\n", dst, current_token -> name);
            return;
        }
        memcpy(&dst[dst_length], " ", 2);
        dst_length ++;
	memcpy(&dst[dst_length], current_token -> name, aux_length + 1);
        dst_length += aux_length;
        current_token  = current_token -> next;
    }
    if(current_token == NULL && first_token -> prev == NULL)
        *token = NULL;
    else if(current_token == NULL){
        first_token -> prev -> next = NULL;
        *token = NULL;
    }
    else if(first_token -> prev == NULL){
        *token = current_token -> next;
        current_token -> prev = NULL;
    }
    else{
        *token = current_token -> next;
        current_token -> next -> prev = first_token -> prev;
        first_token -> prev -> next = current_token -> next;
    }
    return;
}
@

Com isso já podemos escrever o código de declaração de variáveis:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL &&
   (!strcmp(statement -> name, "boolean") ||
    !strcmp(statement -> name, "string")  ||
    !strcmp(statement -> name, "path") ||
    !strcmp(statement -> name, "pen") ||
    !strcmp(statement -> name, "picture") ||
    !strcmp(statement -> name, "transform") ||
    !strcmp(statement -> name, "pair") ||
    !strcmp(statement -> name, "numeric"))){
    int type;
    char buffer[1024];
    // Obtém o tipo da declaração em número
    switch(statement -> name[0]){
    case 'b':
        type = BOOLEAN;
        break;
    case 's':
        type = STRING;
        break;
    case 't':
        type = TRANSFORM;
        break;
    case 'n':
        type = NUMERIC;
        break;
    default:
        switch(statement -> name[2]){
        case 't':
            type = PATH;
            break;
        case 'n':
            type = PEN;
            break;
        case 'c':
            type = PICTURE;
            break;
        default:
            type = PAIR;
            break;
        }
    }
    statement = statement -> next;
    while(1){
        bool already_declared = false;
        int current_type_if_already_declared;
        void *current_arena;
        struct metafont *scope = *mf;
        // Obtém nome da variável declarada
        declared_variable(*mf, &statement, buffer, 1024);
        if(!strcmp(buffer, "")){
            mf_error(*mf, "Missing symbolic token.");
            return;
        }
        // Descobre seu escopo
        if(scope -> parent == NULL)
            already_declared = _search_trie(scope -> variable_types, INT,
                                            buffer,
                                            &current_type_if_already_declared);
        scope = get_scope(*mf, buffer);
        already_declared = _search_trie(scope -> variable_types, INT,
                                        buffer,
                                        &current_type_if_already_declared);
        // Determina sua arena de memória
        if(scope -> parent == NULL)
            current_arena = _user_arena;
        else
            current_arena = metafont_arena;
        // Removendo variável se já existe
        if(already_declared && current_type_if_already_declared != NOT_DECLARED)
            _remove_trie(scope -> vars[current_type_if_already_declared],
                         buffer);
        // Armazenando nova variável
        _insert_trie(scope -> variable_types, current_arena, INT, buffer, type);
        // Se o token atual agora é um ';', terminamos de inserir tudo:
        if(statement != NULL && statement -> type == SYMBOL &&
           !strcmp(statement -> name, ";"))
          break;
        // Se for um ',', apenas o consumimos e continuamos
        if(statement != NULL && statement -> type == SYMBOL &&
           !strcmp(statement -> name, ",")){
            statement = statement -> next;
            continue;
        }
        // Senão, temos algo estranho:
        else{
            mf_error(*mf, "Illegal suffix or missing symbolic token.");
            return;
        }
    }
    return;
}
@

@*1 Definições do Tipo \monoespaco{def}.

Agora não há mais como fugir. Devemos começar a nos preocupar com
expansão de macros, já que esta é a coisa mais simples dentre as que
restam para se implementar. Primeiro veremos uma das formas pelas
quais uma macro pode ser implementada. Vamos à gramática das
definições:

\alinhaverbatim
<Definição> --> <Cabeçalho de Definição><É><Texto de Substituição> enddef
<É> --> = | :=
<Cabeçalho de Definição> --> def <Token Simbólico><Parâmetro de Cabeçalho>
                         +-> <Cabeçalho vardef>
                         +-> <Cabeçalho leveldef>
\alinhanormal

Deixemos pra depois os cabeçalhos vardef e leveldef. Vamos ao primeiro
tipo de cabeçalho:

\alinhaverbatim
<Parâmetro de Cabeçalho> --> <Parâm. Delimitados><Parâm. Não Delimitados>
<Parâm. Delimitados> --> <Vazio>
            +-> <Parâm. Delimitados>(<Tipo Parâm.><lista de Tokens Simbólicos>)
<Tipo Parâm.> --> expr | suffix | text
<Parâm. Não Delimitados> --> <Vazio>
                         +-> primary <Token Simbólico>
                         +-> secondary <Token Simbólico>
                         +-> tertiary <Token Simbólico>
                         +-> expr <Token Simbólico>
                         +-> expr <Token Simbólico> of <Token Simbólico>
                         +-> suffix <Token Simbólico>
                         +-> text <Token Simbólico>
\alinhanormal

Observando esta especificação, primeiro vamos registrar os novos
``sparks'' que estão aparecendo nela:

@<Metafont: Declara Nova Spark@>=
_insert_trie(primitive_sparks, _user_arena, INT, "expr", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "suffix", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "text", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "primary", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "secondary", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "tertiary", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "=", 0);
_insert_trie(primitive_sparks, _user_arena, INT, ":=", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "(", 0);
_insert_trie(primitive_sparks, _user_arena, INT, ")", 0);
@

Uma definição basicamente define uma nova macro. Toda nova macro é
composta por uma lista de argumentos, cada um deles pode ser do tipo
\monoespaco{primary}, \monoespaco{secondary}, \monoespaco{tertiary},
\monoespaco{expr}, \monoespaco{suffix} ou \monoespaco{text}. A
diferença entre eles é relevante quando realmente ocorrer a
substituição daquela macro, não durante a definição. Então por hora
nós apenas armazenaremos o tipo. Além do tipo, cada argumento também
tem um nome. Em suma, podemos aproveitar a estrutura dos tokens para
representá-los, tratando-os como tipos especiais de tokens que nunca
irão parar na lista de tokens de código-fonte, mas que serão
armazenados dentro de definições de macros.

@<Metafont: Variáveis Estáticas@>+=
// Tipo de token
#define PRIMARY    4
#define SECONDARY  5
#define TERTIARY   7
#define EXPR       8
#define SUFFIX     9
#define TEXT      10
@

E uma macro em si é apenas uma estrutura formada por uma lista de
tokens-argumnentos dos novos tipos descritos acima e uma lista de
tokens de substituição, que podem ser quaisquer tokens normais mais
qualquer um dos tokens que ela tenha na lista de argumentos.

@<Metafont: Variáveis Estáticas@>+=
struct macro{
    struct token *parameters;
    struct token *replacement_text;
};
@

Além disso, toda macro tem um nome. Mas este será inserido na árvore
trie que armazenará a macro:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *macros;
@

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> macros = _new_trie(arena);
@

Uma macro deve ser tratada como algo permanente, assim como os seus
tokens. Não como os tokens temporários que vínhamos criando até então
e que eram desalocados da memória tão logo ocorria a interpretação de
cada declaração. Sendo assim, uma novidade é que ao criar um token
para elas, devemos declará-los como sendo permanentes, alocados na
arena de memória de usuário, ou locais de um bloco, sendo declarados
na arena de memória do próprio METAFONT.

Primeiro vamos então nos preocupar com os parâmetros. Esta função
deverá consumir uma lista de tokens comuns e gerar uma lista de tokens
permanentes que será uma lista de parâmetros a ser usada por uma
macro. Ela interpreta apenas parâmetros delimitados:

@<Metafont: Funções Estáticas@>+=
static struct token *delimited_parameters(struct metafont *mf,
                                          struct token **token,
                                          void *arena){
    struct token *tok = *token, *parameter_list;
    struct token *result = NULL, *last_result = NULL;
    int type = NOT_DECLARED;
    // Testando se temos parâmetros delimitados:
    while(tok != NULL && tok -> type == SYMBOL && !strcmp(tok -> name, "(")){
        tok = tok -> next;
        if(tok == NULL || tok -> type != SYMBOL){
            mf_error(mf, "Missing symbolic token.");
            return NULL;
        }
        if(!strcmp(tok -> name, "expr"))
            type = EXPR;
        else if(!strcmp(tok -> name, "suffix"))
            type = SUFFIX;
        else if(!strcmp(tok -> name, "text"))
            type = TEXT;
        else{
            mf_error(mf, "Missing paramaeter type.");
            return NULL;
        }
        tok = tok -> next;
        parameter_list = symbolic_token_list(mf, &tok);
        while(parameter_list != NULL){
	    size_t name_size = strlen(parameter_list -> name);
            char *name = (char *)
                Walloc_arena(arena, name_size + 1);
            if(name == NULL) goto error_no_memory;
	    memcpy(name, parameter_list -> name, name_size + 1);
            if(last_result != NULL){
                last_result -> next = new_token(type, 0.0, name, arena);
                if(last_result -> next == NULL)
                    return NULL;
                last_result -> next -> prev = last_result;
                last_result = last_result -> next;
                last_result -> next = NULL;
            }
            else{
                result = new_token(type, 0.0, name, arena);
                if(result == NULL)
                    return NULL;
                last_result = result;
            }
            parameter_list = parameter_list -> next;
        }
        if(tok == NULL || tok -> type != SYMBOL || strcmp(tok -> name, ")")){
            mf_error(mf, "Missing ')' closing parameters.");
            return NULL;
        }
        tok = tok -> next;
    }
    *token = tok;
    return result;
error_no_memory:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase"
            " the value of W_%s_MEMORY at conf/conf.h\n",
            (arena == _user_arena)?"MAX":"INTERNAL");
    return NULL;
}
@

E agora uma versão desta função apenas para parâmetros
não-delimitados. Tais parâmetros podem ter os seguintes tipos novos:

@<Metafont: Variáveis Estáticas@>+=
#define UNDELIMITED_EXPR   12
#define UNDELIMITED_SUFFIX 13
#define UNDELIMITED_TEXT   14
@

@<Metafont: Funções Estáticas@>+=
static struct token *undelimited_parameters(struct metafont *mf,
                                            struct token **token,
                                            void *arena){
    struct token *tok = *token;
    int type = NOT_DECLARED;
    if(tok != NULL && tok -> type == SYMBOL){
        if(!strcmp(tok -> name, "primary"))
            type = PRIMARY;
        else if(!strcmp(tok -> name, "secondary"))
            type = SECONDARY;
        else if(!strcmp(tok -> name, "tertiary"))
            type = TERTIARY;
        else if(!strcmp(tok -> name, "tertiary"))
            type = TERTIARY;
        else if(!strcmp(tok -> name, "expr"))
            type = UNDELIMITED_EXPR;
        else if(!strcmp(tok -> name, "suffix"))
            type = UNDELIMITED_SUFFIX;
        else if(!strcmp(tok -> name, "text"))
            type = UNDELIMITED_TEXT;
        else return NULL;
    }
    tok = tok -> next;
    if(tok == NULL){
        mf_error(mf, "Missing symbolic token.");
        return NULL;
    }
    *token = tok -> next;
    return new_token(type, 0.0, tok -> name, arena);
}
@

Agora a próxima coisa que irá produzir tais tokens permanentes é o
texto de substituição. Em princípio ler tal texto é simples. Lemos
todos os tokens até acharmos um \monoespaco{enddef}. Mas dentro do
texto de substituição podem existir outras macros sendo
definidas. Cada uma destas macros é finalizada com seu próprio
\monoespaco{enddef}. Então precisamos contar quantas vezes iniciamos
uma nova macro interna e finalizamos para saber qual
\monoespaco{enddef} é o correto.

Além disso, este é um momento no qual devemos gerar um erro se
acharmos uma macro declarada como \monoespaco{outer} no corpo de uma
macro.

Com relação ao começo de macros, devemos ter em mente que existem ao
todo os seguintes tokens simbólicos que os iniciam: \monoespaco{def}
(o qual estamos analizando agora), \monoespaco{vardef},
\monoespaco{primarydef}, \monoespaco{secondarydef} e
\monoespaco{tertiarydef}. Então, ao lermos o texto de substituição
podemos contar pela ocorrência de tais tokens e assim saber quantos
\monoespaco{enddef} precisamos ler:

@<Metafont: Funções Estáticas@>+=
static struct token *replacement_text(struct metafont *mf, struct token **token,
                                      void *arena){
    struct token *tok = *token, *result = NULL, *current_token = NULL;
    int depth = 0, dummy;
    for(;;){
        if(tok == NULL || (depth <= 0 && tok -> type == SYMBOL &&
                           !strcmp(tok -> name, "enddef")))
            break;
        // Checando se é um token 'outer'
        if(tok -> type == SYMBOL && _search_trie(mf -> outer_tokens, INT,
                                                 tok -> name, &dummy)){
            mf_error(mf, "Forbidden token at macro.");
            return NULL;
        }
        // Não tratando de forma especial algo que vem após um token
        // 'quote':
        if(tok -> type == SYMBOL && !strcmp(tok -> name, "quote")){
          if(tok -> next == NULL){
            mf_error(mf, "Missing token after 'quote'.");
            return NULL;
          }
          current_token = current_token -> next;
        }
        // Contagem de sub-macros
        else if(tok -> type == SYMBOL &&
           (!strcmp(tok -> name, "def") || !strcmp(tok -> name, "vardef") ||
            !strcmp(tok -> name, "primarydef") ||
            !strcmp(tok -> name, "secondarydef") ||
            !strcmp(tok -> name, "tertiarydef")))
            depth ++;
        else if(tok -> type == SYMBOL && !strcmp(tok -> name, "enddef"))
            depth --;
        // Adicionando token ao resultado:
        if(result != NULL){
            current_token -> next = new_token(tok -> type, tok -> value,
                                              tok -> name, arena);
            if(current_token -> next == NULL)
                goto end_of_function;
            current_token -> next -> prev = current_token;
            current_token = current_token -> next;
        }
        else{
            result = new_token(tok -> type, tok -> value, tok -> name, arena);
            if(result == NULL)
                goto end_of_function;
            current_token = result;
        }
        if(tok -> next == NULL){
            tok -> next = get_statement(mf);
            if(tok -> next != NULL){
                tok -> next -> prev = tok;
            }
        }
        tok = tok -> next;
    }
end_of_function:
    if(tok != NULL){
        if(tok -> next == NULL){
            tok -> next = get_statement(mf);
            if(tok -> next != NULL)
                tok -> next -> prev = tok;
        }
        *token = tok -> next;
    }
    else
        *token = tok;
    // Ignorar se existe um endgroup aqui dentro
    mf -> hint = 0;
    return result;
}
@

Tendo as três funções acima, podemos enfim terminar de definir nosso
tratamento para macros deste tipo:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "def")){
    char *name;
    struct macro *new_macro;
    struct token *delimited_headers, *undelimited_header;
    statement = statement -> next;
    struct metafont *scope = *mf;
    void *current_arena = _user_arena;
    // Nome da macro
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    name = statement -> name;
    // Decidindo em que região de memória alocar
    scope = get_scope(*mf, name);
    if(scope -> parent != NULL)
      current_arena = metafont_arena;
    statement = statement -> next;
    delimited_headers = delimited_parameters(*mf, &statement, current_arena);
    undelimited_header = undelimited_parameters(*mf, &statement, current_arena);
    new_macro = (struct macro *) Walloc_arena(current_arena, sizeof(struct macro));
    if(new_macro == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
                "value of W_%s_MEMORY at conf/conf.h\n",
                (current_arena == _user_arena)?"MAX":"INTERNAL");
        exit(1);
    }
    new_macro -> parameters = delimited_headers;
    concat_token(&(new_macro -> parameters), undelimited_header);
    // Token = ou :=
    if(statement == NULL || statement -> type != SYMBOL ||
       (strcmp(statement -> name, "=") && strcmp(statement -> name, ":="))){
        mf_error(*mf, "Missing '=' or ':=' at macro definition.");
        return;
    }
    statement = statement -> next;
    // Texto de substituição:
    new_macro -> replacement_text = replacement_text(*mf, &statement,
                                                     current_arena);
    // Armazena a macro
    _insert_trie(scope -> macros, current_arena, VOID_P, name,
                 (void *) new_macro);
    // Checando pelo fim da declaração
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        mf_error(*mf, "Extra token after enddef");
        return;
    }
    return;
}
@

@*1 Definições do Tipo \monoespaco{vardef}.

Existe outro tipo de definição de macro. Ela declara uma variável como
sendo do tipo ``macro'', e provoca a expansão somente quando o nome da
macro aparece como sendo o nome de uma variável ou é o prefixo ou
começo de uma. Ao contrário de outras macros, seus nomes podem ser
usados no final do nome ou sufixo de outras variáveis sem provocar
expansão.

A sintaxe de tais comandos usa a mesma sintaxe das macros, mas com o
cabeçalho especial:

\alinhaverbatim
<Cabeçalho vardef> --> vardef <Variável Declarada><Parâmetro de Cabeçalho>
                   +-> vardef <Variável Declarada> @# <Parâmetro de Cabeçalho>

\alinhanormal

Isso nos trás um novo ``spark'':

@<Metafont: Declara Nova Spark@>=
_insert_trie(primitive_sparks, _user_arena, INT, "@@#", 0);
@

Note que todos os trechos acima já foram definidos previamente. Uma
Variável Declarada foi definida na declaração de variáveis. O que tais
definições fazem é criar uma variável que ao invés de ter um valor
numérico, string ou de outro tipo simples, contém uma macro. É como
levar um pouco do conceito de programação funcionalista onde funções
são entidades de primeira-classe para uma linguagem sem funções onde
macros passam a ser tratadas assim.

Vamos então definir um novo tipo de variável além dos já vistos:

@<Metafont: Inclui Cabeçalhos@>+=
#define MACRO 8
@

O segundo tipo da declaração declara um número infinito de
variáveis-macro, todas com o mesmo prefixo, e definidas de forma
semelhante. No texto de substituição, pode-se referenciar o sufixo
característico delas por meio do \monoespaco{@#}.

Vamos precisar também de um novo tipo de argumento de macro para
representar tais sufixos:

@<Metafont: Variáveis Estáticas@>+=
// Tipo de token
#define VARDEF_ARG 11
@

Tais declarações no fim sempre devem ser avaliadas para uma
variável. Então o texto de definição implicitamente é colocado dentro
de um grupo. A definição de tal declaração é:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "vardef")){
    struct macro *new_macro;
    struct token *tok;
    char variable_name[1024];
    struct token *delimited_headers = NULL, *undelimited_header = NULL,
      *suffix_header = NULL;
    void *current_arena = _user_arena;
    struct metafont *scope = *mf;
    statement = statement -> next;
    // Nome da variável-macro
    variable_name[0] = '\0';
    declared_variable(*mf, &statement, variable_name, 1024);
    // Decidindo em que região de memória alocar
    scope = get_scope(*mf, variable_name);
    if(scope -> parent != NULL)
      current_arena = metafont_arena;
    // Checando ocorrência de '@#':
    if(statement != NULL && statement -> type == SYMBOL &&
       !strcmp(statement -> name, "@@#")){
      suffix_header = new_token(VARDEF_ARG, 0.0, "@@#", current_arena);
      statement = statement -> next;
    }
    // Parâmetros de cabeçalho
    delimited_headers = delimited_parameters(*mf, &statement, current_arena);
    undelimited_header = undelimited_parameters(*mf, &statement, current_arena);
    new_macro = (struct macro *) Walloc_arena(current_arena, sizeof(struct macro));
    if(new_macro == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
                "value of W_%s_MEMORY at conf/conf.h\n",
                (current_arena == _user_arena)?"MAX":"INTERNAL");
        exit(1);
    }
    new_macro -> parameters = suffix_header;
    concat_token(&(new_macro -> parameters), delimited_headers);
    concat_token(&(new_macro -> parameters), undelimited_header);
    // Token = ou :=
    if(statement == NULL || statement -> type != SYMBOL ||
       (strcmp(statement -> name, "=") && strcmp(statement -> name, ":="))){
        mf_error(*mf, "Missing '=' or ':=' at macro definition.");
        return;
    }
    statement = statement -> next;
    // Texto de substituição:
    new_macro -> replacement_text = new_token(SYMBOL, 0.0, "begingroup",
                                              current_arena);
    if(new_macro -> replacement_text == NULL){
        if(current_arena == _user_arena)
            goto error_no_memory_user;
        else
            goto error_no_memory_internal;
    }
    new_macro -> replacement_text -> next = replacement_text(*mf, &statement,
                                                             current_arena);
    new_macro -> replacement_text -> next -> prev = new_macro -> replacement_text;
    if(new_macro -> replacement_text -> next != NULL)
      new_macro -> replacement_text -> next -> prev =
          new_macro -> replacement_text;
    tok = new_token(SYMBOL, 0.0, "endgroup", current_arena);
    if(tok == NULL){
        if(current_arena == _user_arena)
            goto error_no_memory_user;
        else
            goto error_no_memory_internal;
    }
    concat_token(&(new_macro -> replacement_text), tok);
    // Inserir a macro após construí-la:
    _insert_trie(scope -> variable_types, current_arena, INT, variable_name,
                 MACRO);
    _insert_trie(scope -> vardef, current_arena, VOID_P, variable_name,
                (void *) new_macro);
    // Checando pelo fim da declaração
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        mf_error(*mf, "Extra token after enddef");
        return;
    }
    return;
}
@

@*1 Definições do Tipo \monoespaco{leveldef}.

O último tipo de definição serve para definir novos operadores por
meio de macros. A gramática do cabeçalho de tais definições é:

\alinhaverbatim
<Cabeçalho leveldef> --> <leveldef><Token Simbólico><Token Simbólico>
                         <Token Simbólico>
<leveldef> --> primarydef | secondarydef | tertiarydef
\alinhanormal

Onde o primeiro token é um dentre três tipos dependendo da precedência
do operador que se está definindo. Basicamente um
\monoespaco{primarydef} tem uma precedência equivalente à
multiplicação, um \monoespaco{secondarydef} tem precedência
equivalente à uma soma e um \monoespaco{tertiarydef} tem precedência
equivalente à operadores de comparação.

O segundo token, pode ser qualquer token simbólico e é o primeiro
operador. O terceiro token é o nome do operador. E o terceiro é o
segundo operador. Todos os novos operadores definidos assim são
operadores binários.

Assim, primeiro vamos definir os três novos ``sparks'' na linguagem:

@<Metafont: Declara Nova Spark@>=
_insert_trie(primitive_sparks, _user_arena, INT, "primarydef", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "secondarydef", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "tertiarydef", 0);
@

Agora já podemos definir a declaração:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL &&
   (!strcmp(statement -> name, "primarydef") ||
    !strcmp(statement -> name, "secondarydef") ||
    !strcmp(statement -> name, "tertiarydef"))){
    struct _trie *destiny[3];
    int precedence;
    char *name;
    struct token *arg1, *arg2;
    struct metafont *scope = *mf;
    void *current_arena = _user_arena;
    struct macro *new_macro;
    // Determina precedência
    switch(statement -> name[0]){
    case 'p':
        precedence = 0;
        break;
    case 's':
        precedence = 1;
        break;
    default:
        precedence = 2;
        break;
    }
    // Obtendo nome da macro
    if(statement -> next == NULL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    statement = statement -> next -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    name = statement -> name;
    // Descobrindo o escopo
    scope = get_scope(*mf, name);
    if(scope -> parent != NULL)
      current_arena = metafont_arena;
    destiny[0] = scope -> primarydef;
    destiny[1] = scope -> secondarydef;
    destiny[2] = scope -> tertiarydef;
    // Alocando a macro
    new_macro = (struct macro *) Walloc_arena(current_arena,
                                              sizeof(struct macro));
    if(new_macro == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
                "value of W_%s_MEMORY at conf/conf.h\n",
                (current_arena == _user_arena)?"MAX":"INTERNAL");
        exit(1);
    }
    // Obtendo o primeiro argumento
    statement = statement -> prev;
    if(statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    arg1 =  new_token(SYMBOL, 0.0, statement -> name, current_arena);
    if(arg1 == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
                "value of W_%s_MEMORY at conf/conf.h\n",
                (current_arena == _user_arena)?"MAX":"INTERNAL");
        exit(1);
    }
    // Obtendo o segundo argumento
    statement = statement -> next -> next;
    if(statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    arg2 =  new_token(SYMBOL, 0.0, statement -> name, current_arena);
    if(arg1 == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
                "value of W_%s_MEMORY at conf/conf.h\n",
                (current_arena == _user_arena)?"MAX":"INTERNAL");
        exit(1);
    }
    arg1 -> next = arg2;
    arg2 -> prev = arg1;
    new_macro -> parameters = arg1;
    // Token = ou :=
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL ||
       (strcmp(statement -> name, "=") && strcmp(statement -> name, ":="))){
        mf_error(*mf, "Missing '=' or ':=' at macro definition.");
        return;
    }
    statement = statement -> next;
    // Texto de substituição:
    new_macro -> replacement_text = new_token(SYMBOL, 0.0, "begingroup",
                                              current_arena);
    if(new_macro -> replacement_text == NULL){
        if(current_arena == _user_arena)
            goto error_no_memory_user;
        else
            goto error_no_memory_internal;
    }
    new_macro -> replacement_text = replacement_text(*mf, &statement,
                                                     current_arena);

    // Inserir a macro após construí-la:
    _insert_trie(destiny[precedence], current_arena, VOID_P, name,
                (void *) new_macro);
    // Checando pelo fim da declaração
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        mf_error(*mf, "Extra token after enddef");
        return;
    }
    return;
}
@

@*1 Títulos.

Títulos são como comentários, com o diferencial de que eles podem ser
impressos na tela de acordo com os valores internos armazenados no
METAFONT original. Mas no nosso caso, nós sempre iremos ignorá-los
depois de tratá-los.

Para um comando que não fará nada, ele será bastante complexo. Pois
aqui começaremos a definir as expressões, as quais são centrais para o
funcionamento do METAFONT.

A gramática de um título é:

\alinhaverbatim
<Título> --> <Expressão String>
<Expressão String> --> <String Terciário>
                   +-> <Expressão String> & <String Terciário>
<String Terciário> --> <String Secundário>
<String Secundário> --> <String Primário>
<String Primário> --> <Variável String>
                  +-> <Token String>
                  +-> jobname
                  +-> readstring
                  +-> ( <Expressão String> )
                  +-> begingroup <Lista de Declarações> <Expressão String>
                  |   endgroup
                  +-> str <Sufixo>
                  +-> char <Numérico Primário>
                  +-> decimal <Numérico Primário>
                  +-> substring <Par Primário> of <String Primário>
\alinhanormal

Nem tudo poderemos definir de maneira completa antes de completarmos a
definição de outros tipos de expressão. Por exemplo, supostament
teríamos que ter definição das expressões primárias de números e
pares. Mas como tais definições são muito mais complexas, é melhor
começarmos por strings, mesmo que não possamos finalizar elas ainda.

Primeiro vamos declarar os novos ``sparks'' que temos aqui:

@<Metafont: Declara Nova Spark@>=
_insert_trie(primitive_sparks, _user_arena, INT, "&", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "jobname", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "readstring", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "str", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "char", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "decimal", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "substring", 0);
@

Na maioria das vezes nós sabemos que estamos dentro de uma expresão de
string por estarmos diante de uma variável declarada como string, uma
string literal ou algum de tais operadores listados acima coo primeiro
token após os ``('' iniciais. A única exceção é quando começamos a
expressão com um grupo, pois só descobriremos isso após avaliarmos o
grupo. Se o \monoespaco{begingroup} aparece no começo de uma
expressão, ele até já começou a ser tratado, pois este caso se
confunde com uma declaração composta. Se aparece no meio, ainda temos
que tratar.

Para estes casos com grupos, de qualquer forma, precisamos tratar o
caso de quando o grupo faz parte de uma expressão. Se nós estamos em
um grupo, chegamos ao seu fim, mas não conseguimos detectar uma
declaração para ser executada, devemos assumir estarmos diante de uma
expressão que deve ser interpretada e o valor obtido deve ser
armazenado para ser usado na continuação da expressão quando a
expressão começa com um grupo.


@<Metafont: Prepara Retorno de Expressão Composta@>=
{
    struct token *new_tokens = NULL;
    struct token *expression_result = eval(mf, &statement);
    if((*mf) -> hint == HINT_ENDGROUP){
      if(expression_result != NULL)
        if((*mf) -> parent == NULL){
            mf_error(*mf, "Extra 'endgroup' while not in 'begingroup'.");
            return;
        }
        new_tokens = (*mf) -> parent -> past_tokens;
        (*mf) -> parent -> past_tokens = NULL;
        if(expression_result != NULL){
          concat_token(&new_tokens, expression_result);
          concat_token(&new_tokens, (*mf) -> pending_tokens);
          (*mf) -> parent -> pending_tokens = new_tokens;
        }
        end_scope(*mf);
        *mf = (*mf) -> parent;
        Wtrash_arena(metafont_arena);
    }
    else{
        // Se temos uma expressão solta, e ela é uma string,
        // então temos um título. Se for NULL, ignore e continue
        if(expression_result == NULL)
            return;
        if(expression_result -> type != STRING)
            mf_error(*mf, "Isolated expression.");
        else if(expression_result -> type == STRING){
          if(statement -> next -> type != SYMBOL ||
             strcmp(statement -> next -> name, ";"))
            mf_error(*mf, "Missing ';' after title.");
            ; // Se algum dia quiseros fazer algo com o título, inserir aqui
        }
    }
    return;
}
@

A função \monoespaco{eval} é o que irá avaliar expressões e retornar
um token com o resultado da avaliação. Como o caso da expressão
começar com \monoespaco{begingroup} já terminou de ser tratado agora,
podemos definir tal função:

@<Metafont: Funções Locais Declaradas@>=
static struct token *eval(struct metafont **, struct token **);
static struct token *eval_string(struct metafont **, struct token **);
static struct token *eval_numeric(struct metafont **, struct token **);
@

@<Metafont: Eval@>=
@<Metafont: eval_numeric@>
@<Metafont: eval_string@>
struct token *eval(struct metafont **mf, struct token **expression){
    struct token *aux = *expression;
    int type = -1;
    char var_name[1024], type_name[1024];
    if((*expression) -> type == SYMBOL && !strcmp((*expression) -> name, ";"))
      return NULL; // Expressão vacuosa
    // Ignorando os delimitadores iniciais para definir o tipo
    while(aux != NULL && aux -> type == SYMBOL && delimiter(*mf, aux) != NULL)
        aux = aux -> next;
    // Erro se não houver nada
    if(aux == NULL){
        mf_error(*mf, "Missing expression.");
        return NULL;
    }
    if(aux -> type == STRING)
        return eval_string(mf, expression);
    // Definindo se é uma variável:
    else if(aux -> type == SYMBOL){
        if(!strcmp(aux -> name, "begingroup")){
            struct token *expr_begin = *expression;
            while(expr_begin != NULL && expr_begin -> prev != NULL)
              expr_begin = expr_begin -> prev;
            if(expr_begin != NULL){
              (*mf) -> past_tokens = expr_begin;
            }
            // Começo de uma expressão composta com grupo
            // Primeiro rompemos a cadeia de tokens antes:
            if(aux -> prev != NULL){
              aux -> prev -> next = NULL;
              aux -> prev = NULL;
            }
            // Criamos novo contexto
            Wbreakpoint_arena(metafont_arena);
            *mf = _new_metafont(*mf, (*mf) -> filename);
            (*mf) -> pending_tokens = aux -> next;
            concat_token(&((*mf) -> pending_tokens),
                         (*mf) -> parent -> pending_tokens);
            if(aux -> next != NULL){
              aux -> next -> prev = NULL;
              aux -> next = NULL;
            }
            (*mf) -> parent -> pending_tokens = NULL;
            // Saímos sem avaliar, avaliaremos depois de obter o valor do grupo
            return NULL;
        }
        // Checando se é um operador conhecido
        if(!strcmp(aux -> name, "jobname"))
            return eval_string(mf, expression);
        if(!strcmp(aux -> name, "readstring"))
            return eval_string(mf, expression);
        if(!strcmp(aux -> name, "str"))
            return eval_string(mf, expression);
        if(!strcmp(aux -> name, "char"))
            return eval_string(mf, expression);
        if(!strcmp(aux -> name, "decimal"))
            return eval_string(mf, expression);
        if(!strcmp(aux -> name, "substring"))
            return eval_string(mf, expression);
          // Não determinado. Tentando ler como variável
        variable(mf, &aux, var_name, 1024, type_name, &type, false);
        if(type == STRING){
            struct token *teste = eval_string(mf, expression);
            return teste;
        }

    }
    mf_error(*mf, "Undetermined expression.");
    return NULL;
}
@

Por enquanto a função de avaliação de string vai só retornar. Ela vai
funcionar quando a função é só uma string literal. Definiremos em
seguida os detalhes de como avaliar expressão:

@<Metafont: eval_string@>=
static struct token *eval_string(struct metafont **mf,
                                 struct token **expression){
    bool delimited = false;
    struct token *current_token = *expression;
    char *delim = delimiter(*mf, *expression);
    if(delim != NULL){
        current_token = current_token -> next;
        delimited = true;
    }
    // Percorre a expressão avaliando expressões primárias
    while(current_token != NULL &&
          (current_token -> type != SYMBOL ||
           (strcmp(current_token -> name, ";") &&
            strcmp(current_token -> name, "=") &&
            strcmp(current_token -> name, ",") &&
            strcmp(current_token -> name, ":="))) &&
          (!delimited || strcmp(current_token -> name, delim))){
        @<Metafont: String: Expressões Primárias@>
        current_token = current_token -> next;
    }
    // Percorre a expressão avaliando expressões quaternárias
    current_token = *expression;
    if(delim != NULL)
      current_token = current_token -> next;
    while(current_token != NULL &&
          (current_token -> type != SYMBOL ||
           (strcmp(current_token -> name, ";") &&
            strcmp(current_token -> name, "=") &&
            strcmp(current_token -> name, ",") &&
            strcmp(current_token -> name, ":="))) &&
          (!delimited || strcmp(current_token -> name, delim))){
      @<Metafont: String: Expressões Quaternárias@>
      current_token = current_token -> next;
    }
    // Removendo parênteses se após avaliarmos expressão ficarmos com
    // algo como "(resultado)"
    if(delimited){
        if(*expression != NULL && (*expression) -> next != NULL &&
           (*expression) -> next -> next != NULL &&
           !strcmp((*expression) -> next -> next -> name,
                   delim)){
            *expression = (*expression) -> next;
            (*expression) -> prev = (*expression) -> prev -> prev;
            if((*expression) -> prev != NULL)
                (*expression) -> prev -> next = *expression;
            (*expression) -> next = (*expression) -> next -> next;
            if((*expression) -> next != NULL)
                (*expression) -> next -> prev = *expression;
        }
    }
    return *expression;
error_no_memory_internal:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
            "value of W_INTERNAL_MEMORY at conf/conf.h\n");
    exit(1);


}
@

@*1 Expressões de String Primárias.

Quando formos avaliar uma expressão de string, a primeira coisa a
fazer é sempre começar percorrendo ela avaliando as expressões
primárias. Depois fazemos isso com as secundárias. E por fim as
terciárias. No meio podemos ter que fazer uma expansão de tokens por
causa de novos operadores definidos pelo usuário por meio das
declarações \monoespaco{leveldef}.

@*2 Variáveis String.

Vamos começar definindo que forma terá uma variável string após ser
armazenada. Obviamente, ela precisa possuir uma string com um valor
conhecido. Mas além disso, daremos à ela um outro atributo booleano
que nos diz se ela é uma variável determinística. Ou seja, se ela foi
gerada envolvendo um número aleatório. Variáveis determinísticas
possuem a propriedade de que toda vez que um mesmo programa METAFONT
for executado, elas terão exatamente o mesmo valor. Podemos então usar
um cache para elas. Por fim, uma variável pode ser indefinida, mas
podemos saber outras informações sobre ela. Por exemplo, ela pode
fazer parte de uma lista duplamente encadeada de variáveis indefinidas
que são iguais. Se os ponteiros da lista são nulos, a variável é
conhecida e tem um valor armazenado em \monoespaco{name}. Se não, seu
valor não é conhecido, mas temos a lsita duplamente encadeada de
valores que são iguais aos dela:

@<Metafont: Variáveis Estáticas@>+=
struct string_variable{
    char *name;
    bool deterministic;
    struct string_variable *prev, *next;
};
@

Com isso, nova variável string pode ser armazenada em uma estrutura
METAFONT por meio da seguinte função. Ela simulará comandos
como \monoespaco{var=string} ou \monoespaco{var:=string}. O nome da
variável é o nome ao qual nos refereimos para tratar dela. O nome do
tipo é o nome com o qual ela foi declarada. Muitas vezes ambos serão
iguais, mas no caso de uma variável ``var1'', sua declaração tem a
forma ``var[]''. A última flag da função a seguir determina se estamos
usando o operador ``='' ou ``:='' para setar o valor da variável. O
primeiro é para variáveis indefinidas e faz com que ela e todas as
outras variáveis da lista de variáveis iguais passem a ter o valor da
string passado. O segundo é para qualquer variável e faz com que
somente ela passe a ter o valor indicado, sendo removida da lista de
igualdades se estiver em uma:

@<Metafont: Funções Estáticas@>+=
void new_defined_string_variable(char *var_name, char *type_name,
                                 struct token *string_token,
                                 struct metafont *mf, bool overwrite){
    struct metafont *scope = mf;
    int current_type = -1;
    void *current_arena;
    struct string_variable *new_variable = NULL;
    scope = get_scope(mf, type_name);
    _search_trie(scope -> variable_types, INT, type_name, &current_type);
    //Checa por erro de tipo
    switch(current_type){
    case BOOLEAN:
        mf_error(mf, "Equation cannot be performed (boolean=string).");
        return;
    case PATH:
        mf_error(mf, "Equation cannot be performed (path=string).");
        return;
    case STRING:
        // OK
        break;
    case PEN:
        mf_error(mf, "Equation cannot be performed (pen=string).");
        return;
    case PICTURE:
        mf_error(mf, "Equation cannot be performed (picture=string).");
        return;
    case TRANSFORM:
        mf_error(mf, "Equation cannot be performed (transform=string).");
        return;
    case PAIR:
        mf_error(mf, "Equation cannot be performed (pair=string).");
        return;
    default:
        mf_error(mf, "Equation cannot be performed (numeric=string).");
        return;
    }
    // Escolhendo arena de memória
    if(scope -> parent == NULL)
        current_arena = _user_arena;
    else
        current_arena = metafont_arena;
    // Checando se ela já existe:
    _search_trie(scope -> vars[STRING], VOID_P, var_name,
                  (void *) & new_variable);
    if(new_variable == NULL){
        // Não existe, gerando a variável
        size_t name_size;
        new_variable = (struct string_variable *)
            Walloc_arena(current_arena,
                         sizeof(struct string_variable));
        if(new_variable == NULL)
            goto error_no_memory;
        new_variable -> name =
            (char *) Walloc_arena(current_arena,
                                  name_size = strlen(string_token -> name) + 1);
        if(new_variable -> name == NULL)
            goto error_no_memory;
        memcpy(new_variable -> name, string_token -> name, name_size);
        new_variable -> deterministic = string_token -> deterministic;
        new_variable -> prev = new_variable -> next = NULL;
        _insert_trie(scope -> vars[STRING], current_arena, VOID_P,
                     var_name, (void *) new_variable);
        return;
    }
    else{
        // Existe.
        if(overwrite){
            size_t name_size;
            if(new_variable -> prev != NULL)
                new_variable -> prev -> next = new_variable -> next;
            if(new_variable -> next != NULL)
                new_variable -> next -> prev = new_variable -> prev;
            new_variable -> name = (char *)
                Walloc_arena(current_arena,
                             name_size = strlen(string_token -> name) + 1);
            if(new_variable -> name == NULL)
                goto error_no_memory;
            memcpy(new_variable -> name, string_token -> name, name_size);
            new_variable -> deterministic = string_token -> deterministic;
            new_variable -> prev = new_variable -> next = NULL;
        }
        else{
            // Checamos se é definido, se for, é um erro:
            if(new_variable -> prev == NULL && new_variable -> next == NULL){
                if(!strcmp(new_variable -> name, string_token -> name)){
                    mf_error(mf, "Redundant equation (%s=%s).",
                             new_variable -> name, string_token -> name);
                    return;
                }
                else{
                    mf_error(mf, "Inconsistent equation (%s=%s).",
                             new_variable -> name, string_token -> name);
                    return;
                }
            }
            // Sendo uma variável indefinida, percorreremos a
            // lista. Primeiro vamos ao começo:
            while(new_variable -> prev != NULL)
                new_variable = new_variable -> prev;
            while(new_variable != NULL){
                size_t name_size;
                struct string_variable *next_var;
                // Rompe conexão com anterior
                new_variable -> prev = NULL;
                // Gera o novo nome para a variável
                new_variable -> name =
                    (char *)
                        Walloc_arena(current_arena,
                                     name_size = strlen(string_token -> name) + 1);
                if(new_variable -> name == NULL)
                    goto error_no_memory;
                memcpy(new_variable -> name, string_token -> name, name_size);
                new_variable -> deterministic = string_token -> deterministic;
                // Rompe conexão com próximo e vai até ele
                next_var = new_variable -> next;
                new_variable -> next = NULL;
                new_variable = next_var;
            }
        }
    }
    return;
error_no_memory:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase "
            "the value of W_%s_MEMORY at conf/conf.h.\n",
            (current_arena == _user_arena)?"MAX":"INTERNAL");
    exit(1);
}
@

Mas para poder usar tal função, precisamos obter o nome completo de
uma variável, a qual pode ser formada por mais de um token ou
números. A gramática completa para acessar uma variável em uma expressão é:

\alinhaverbatim
<Variável> --> <Tag Externa><Sufixo>
           +-> <Quantidade Interna>
<Sufixo> --> <Vazio>
         +-> <Sufixo><Subscrito>
         +-> <Sufixo><Tag>
<Subscrito> --> <Token Numérico>
            +-> [ <Expressão Numérica> ]
\alinhanormal

Uma quantidade interna não pode ter sufixos. Declarar variáveis
internas é a primeira coisa que definimos na linguagem. Nos demais
casos, o sufixo pode ser qualquer quantidade de tags e de números (na
forma de expressões numéricas) delimitados ou não por ``['' e ``]''.

Por hora tratemos as expressões numéricas como se fôssem compostas
somente por números literais. Depois iremos expandir seu significado:

@<Metafont: eval_numeric@>=
static struct token *eval_numeric(struct metafont **mf,
                                  struct token **expression){
  (void) mf; // TODO: Evita aviso de compilação
  struct token *ret = *expression;
  if(ret -> next != NULL)
    ret -> next -> prev = ret -> prev;
  if(ret -> prev != NULL)
    ret -> prev -> next = ret -> next;
  *expression = ret -> next;
  return ret;
}
@

E agora o código que consome uma próxima variável, que pode ter nome
composto, e preenche uma string com seu nome, recebida como argumento
e também armazena seu tipo no último argumento. Armazena
em \monoespaco{type\_name} o nome da variável conforme foi declarado.
Assim o nome declarado da variável de nome \monoespaco{a1}
é \monoespaco{a[]}. Para as vezes em que queremos extrair somente o
nome da variável, e não consumir ela da lista de tokens, passaremos
como como último parâmetro a flag falsa. Para o caso do tipo ser de uma
variável numérica interna, usaremos isso:

@<Metafont: Inclui Cabeçalhos@>+=
#define INTERNAL 9
@

@<Metafont: Funções Estáticas@>=
static void variable(struct metafont **mf, struct token **token,
              char *dst, int dst_size,
              char *type_name, int *type, bool consume){
    struct metafont *scope = *mf;
    struct token *previous_token;
    struct token *old_token = *token;
    
    bool internal = false, vardef = false;
    float dummy;
    struct macro *mc = NULL;
    dst[0] = '\0';
    type_name[0] = '\0';
    int type_size = dst_size;
    int pos = 0, type_pos = 0, original_size = dst_size;
    if(*token == NULL || (*token) -> type != SYMBOL)
        return;
    previous_token = (*token) -> prev;
    // Primeiro checamos se é uma quantidade interna
    while(scope -> parent != NULL){
        internal = _search_trie(scope -> internal_quantities, DOUBLE,
                                                 (*token) -> name, &dummy);
        if(internal)
            break;
        scope = scope -> parent;
    }
    if(!internal)
        internal = _search_trie(scope -> internal_quantities, DOUBLE,
                                (*token) -> name, &dummy);
    if(internal){
        strncpy(dst, (*token) -> name, dst_size);
        if((*token) -> prev != NULL)
            (*token) -> prev -> next = (*token) -> next;
        if((*token) -> next != NULL)
            (*token) -> next -> prev = (*token) -> prev;
        *token = (*token) -> next;
        (*token) -> prev = previous_token;
        *type = INTERNAL;
        strncpy(type_name, dst, type_size);
        goto restore_token_if_not_consume_and_exit;
    }
    // Se não for, o primeiro token precisa ser uma tag
    if(!is_tag(*mf, *token)){
        *type = NOT_DECLARED;
        return;
    }
    while(*token != NULL){
        { // Sempre começamos checando se o que temos não é um vardef:
            scope = *mf;
            while(scope != NULL){
                vardef = _search_trie(scope -> vardef, VOID_P,
                                      type_name, (void *) &mc);
                if(vardef){
		  // vardef, remover os tokens de seu nome
		  if(old_token -> prev != NULL){
		    old_token -> prev -> next = *token;
		    (*token) -> prev = old_token -> prev;
		  }
		  else
		    (*token) -> prev = NULL;
                    *type = MACRO;
                    *token = expand_macro(*mf, mc, token);
		    // Se expandiu para NULL, temos que tratar o
		    // começo de um bloco. Retornar e repassar o
		    // controle para o interpretador
		    if(*token == NULL){
		      consume = false;
		      goto restore_token_if_not_consume_and_exit;
		    }
                    eval(mf, token);
                    (*token) -> prev = previous_token;
                    return;
                }
                scope = scope -> parent;
            }
        }
        // Se o token atual for um símbolo, mas não uma tag ou [ ou ],
        // encerramos
        if((*token) -> type == SYMBOL &&
           (!is_tag(*mf, *token) &&
            strcmp((*token) -> name, "[") &&
             strcmp((*token) -> name, "]"))){
            break;
        }
        // Se for um '[', temos que checar que temos uma expressão numérica e
        // um ']' logo em seguida
        if((*token) -> type == SYMBOL && !strcmp((*token) -> name, "[")){
            struct token *result;
            *token = (*token) -> next;
            result = eval_numeric(mf, token);
            if(result == NULL || result -> type != NUMERIC){
                mf_error(*mf, "Undefined numeric expression after '['.");
                *type = NOT_DECLARED;
                (*token) -> prev = previous_token;
                return;
            }
            if(*token == NULL || (*token) -> type != SYMBOL ||
               strcmp((*token) -> name, "]")){
                mf_error(*mf, "Missing ']' after '[' in variable name.");
                *type = NOT_DECLARED;
                (*token) -> prev = previous_token;
                return;
            }
            *token = (*token) -> next;
            // Copiando o subscrito
            snprintf(&(dst[pos]), dst_size, "%f ", result -> value);
            pos = strlen(dst);
            dst_size = original_size - pos;
            strncat(type_name, " [ ]", type_size - type_pos);
            type_pos = type_pos + 4;
            continue;
        }
        // Se for um outro símbolo, copiamos seu nome
        if((*token) -> type == SYMBOL){
            int size = strlen((*token) -> name);
            if(dst[0] != '\0'){
                strncat(dst, " ", dst_size);
                strncat(type_name, " ", type_size - type_pos);
                type_pos ++;
                pos ++;
                dst_size -= 1;
            }
            strncat(dst, (*token) -> name, dst_size);
            pos += size;
            dst_size -= pos;
            strncat(type_name, (*token) -> name, type_size - type_pos);
            type_pos += size;
            *token = (*token) -> next;
            continue;
        }
        // Se tivermos um número, ele é um subscrito e o copiamos
        if((*token) -> type == NUMERIC){
            snprintf(&(dst[pos]), dst_size, "%f", (*token) -> value);
            pos = strlen(dst);
            dst_size = original_size - pos;
            strncat(type_name, " [ ]", type_size - type_pos);
            type_pos += 4;
            *token = (*token) -> next;
            continue;
        }
        // Se não paramos em nenhum dos casos, é um token desconhecido e
        // paramos.
        break;
    }
    // Tentando obter o tipo, se não acharmos ele é numérico:
    *type = NUMERIC;
    scope = get_scope(*mf, type_name);
    _search_trie(scope -> variable_types, INT, type_name, type);
    // Finalizando a string e saindo
    if(dst_size > 0)
        dst[pos] = '\0';
    else
        dst[original_size - 1] = '\0';
    if(*token != NULL)
        (*token) -> prev = previous_token;
  restore_token_if_not_consume_and_exit:
    if(!consume && old_token != *token){
      // Restaurar variável
      if(*token != NULL && (*token) -> prev != NULL)
        (*token) -> prev -> next = old_token;
      while(old_token -> next != (*token) &&
            old_token -> next != NULL &&
            old_token -> next != old_token){
        old_token = old_token -> next;
      }
      if(*token != NULL)
          (*token) -> prev = old_token;
      old_token -> next = *token;
    }
    return;
}
@


Vamos precisar também de uma função para ler uma variável armazenada,
dado seu tipo, retornando um novo token equivalente no lugar se ela
for definida:

@<Metafont: Funções Estáticas@>+=
struct token *read_var(char *var_name, char *type_name, struct metafont *mf){
    struct metafont *scope = mf;
    struct token *ret = NULL;
    int current_type = -1;
    struct string_variable *var = NULL;
    scope = get_scope(mf, type_name);
    _search_trie(scope -> variable_types, INT, type_name, &current_type);
    if(current_type != -1){
      _search_trie(scope -> vars[current_type], VOID_P, var_name,
                   (void *) &var);
      if(var == NULL)
        return NULL;
      if(var -> prev != NULL || var -> next != NULL)
        return NULL; // Variável com valor indefinido
      ret = new_token_string(var -> name);
      ret -> deterministic = var -> deterministic;
      return ret;
    }
    return NULL;
}
@

Isso também nos mostra que os próprios tokens também precisam ter duas
informações: se eles são determinísticos ou se eles são conhecidos:

@<Metafont: Atributos de Token@>=
bool deterministic;
int known; // -1: Unknown, 0: Not checked, 1: Known
@

No começo qualquer token gerado é determinístico e o fato dele ser
conhecido não é checado:

@<Metafont: Construção de Token@>=
token -> deterministic = true;
token -> known = 0;
@

Com isso já somos capazes de lidar com variáveis string em expressões
de string:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL){
    char variable_name[1024], type_name[1024];
    int type = NOT_DECLARED;
    struct token *replacement = NULL;
    struct token *possible_var = current_token;
    variable(mf, &current_token, variable_name, 1024, type_name, &type, true);
    if(type == MACRO){ // vardef substituído
        return NULL;
    }
    if(type != NOT_DECLARED){
        // Se estamos aqui, é mesmo uma variável
        if(type != STRING){
            mf_error(*mf, "Variable '%s' isn't a string.", variable_name);
            return NULL;
        }
        replacement = read_var(variable_name, type_name, *mf);
        if(replacement != NULL){
            if(current_token != NULL)
                replacement -> prev = current_token -> prev;
            replacement -> next = current_token;
            if(current_token != NULL && current_token -> prev != NULL)
                current_token -> prev -> next = replacement;
            else
                *expression = replacement;
            if(current_token != NULL)
                current_token -> prev = replacement;
            current_token = replacement;
            continue;
        }
    }
    if(replacement == NULL || type == NOT_DECLARED){
        if(current_token != possible_var){
            // Restaurar variável se foi consumida mas é vazia
            if(current_token -> prev == NULL)
              *expression = possible_var;
            else
              current_token -> prev -> next = possible_var;
            while(possible_var -> next != current_token &&
                  possible_var -> next != NULL &&
                  possible_var -> next != possible_var){
              possible_var = possible_var -> next;
            }
            current_token -> prev = possible_var;
            possible_var -> next = current_token;
        }
    }
}
@

@*2 Tokens String.

Encontrar o token de uma string em uma expressão string é o caso mais
simples. Nós apenas ignoramos ela e seguimos em frente, pois um token
string é avaliado como sendo exatamente o que ele é. Não precisamos
fazer nada para isso.

@*2 Jobname.

A expressão \monoespaco{jobname} é avaliada como sendo um token string
cujo conteúdo é o nome do arquivo que está sendo lido:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "jobname")){
    struct token *jobname = new_token_string((*mf) -> filename);
    if(jobname == NULL)
        goto error_no_memory_internal;
    jobname -> prev = current_token -> prev;
    jobname -> next = current_token -> next;
    current_token = jobname;
    if(current_token -> prev != NULL)
        current_token -> prev -> next = current_token;
    else
        *expression = current_token;
    if(current_token -> next != NULL)
        current_token -> next -> prev = NULL;
}
@

@*2 Expressões com parênteses.

Para tratar expressões com parênteses, basta chamarmos recursivamente
a função de avaliar strings, pois ela já trata corretamente o começo e
o fim de delimitadores para saber a extensão de até onde ela deve
avaliar:

@<Metafont: String: Expressões Primárias@>=
{
    char *current_delim = delimiter(*mf, current_token);
    if(current_delim != NULL){
        eval_string(mf, &current_token);
    }
}
@

@*2 Expressões com \monoespaco{begingroup}.

Em tais casos, apenas invocamos o código que já foi feito na
função \monoespaco{eval}:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "begingroup")){
    eval(mf, &current_token);
    return NULL;
}
@

@*2 Expressões \monoespaco{readstring}.

Elas lêem uma linha da entrada padrão, removem todo o espaço no começo
e no fim, e avaliam como sendo a string resultante:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "readstring")){
    struct token *token;
    char *buffer = NULL, *begin;
    size_t size;
    if(getline(&buffer, &size, stdin) == -1 || buffer == NULL){
        fprintf(stderr, "ERROR: Not enough memory.\n");
        exit(1);
    }
    begin = buffer;
    while(isspace(*begin))
        begin ++;
    while(size != 0 && (buffer[size] == '\n' || isspace(buffer[size])))
        size --;
    buffer[size + 1] = '\0';
    token = new_token_string(begin);
    free(buffer);
    token -> next = current_token -> next;
    token -> prev = current_token -> prev;
    if(token -> prev == NULL)
        *expression = token;
    else
        token -> prev -> next = token;
    if(token -> next != NULL)
        token -> next -> prev = token;
}
@

@*2 Expressões \monoespaco{str}.

Esta expressão é sempre seguida por um sufixo. Ou seja, um conjunto de
tags e de expressões numéricas delimitadas por ``['' e ``]''. Ela é
avaliada se tornando uma string com uma representação do sufixo
lido.

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "str")){
    char buffer[2048];
    buffer[0] = '\0';
    int remaining_size = 2047;
    bool deterministic = true;
    struct token *last_token = current_token -> next, *new_result;
    while(last_token != NULL){
        if(last_token -> type == SYMBOL && !strcmp(last_token -> name, "[")){
            char buffer_number[16];
            struct token *result;
            strncat(buffer, "[", remaining_size);
            remaining_size --;
            last_token = last_token -> next;
            if(last_token == NULL){
                mf_error(*mf, "Missing numeric expression.");
                return NULL;
            }
            result = eval_numeric(mf, &last_token);
            if(result == NULL)
                return NULL;
            if(result -> type != NUMERIC){
                mf_error(*mf, "Undefined numeric expression.");
                return NULL;
            }
            deterministic = deterministic && result -> deterministic;
            snprintf(buffer_number, 16, "%f", result -> value);
            strncat(buffer, buffer_number, remaining_size);
            remaining_size -= strlen(buffer_number);
            if(last_token == NULL || last_token -> type != SYMBOL ||
               strcmp(last_token -> name, "]")){
                mf_error(*mf, "Missing ']'.");
                return NULL;
            }
            strncat(buffer, "]", remaining_size);
            remaining_size --;
            last_token = last_token -> next;
            continue;
        }
        if(last_token -> type == SYMBOL && !is_tag(*mf, last_token))
            break;
        if(last_token -> type == SYMBOL && is_tag(*mf, last_token)){
            if(buffer[0] != '\0'){
                strncat(buffer, ".", remaining_size);
                remaining_size --;
            }
            strncat(buffer, last_token -> name, remaining_size);
            remaining_size -= strlen(last_token -> name);
        }
        last_token = last_token -> next;
    }
    new_result = new_token_string(buffer);
    new_result -> deterministic = deterministic;
    new_result -> prev = current_token -> prev;
    if(new_result -> prev == NULL)
        *expression = new_result;
    else
        new_result -> prev -> next = new_result;
    new_result -> next = last_token;
    if(new_result -> next != NULL)
        new_result -> next -> prev = new_result;
    current_token = new_result;
}
@

@*2 Expressões \monoespaco{char}.

A expressão \monoespaco{char} lê um primário numérico e o converte
para uma string de um único caractere, usando a representação ASCII. O
valor numérico é sempre antes arredondado para o inteiro mais próximo.

Nós iremos nos distanciar um pouco do METAFONT original, pois para nós
o importante não é o código ASCII, mas o código UTF-8.Então o número
que podemos passar não irá variar somente entre 0 e 255. Isso quebrará
a compatibilidade, pois o METAFONT original tratava valores menores
que 0 e maiores que 255 aplicando o módulo 256. Posteriormente deve
ser avaliado se devemos manter essa incompatibilidade ou se devemos
retomar para o mesmo tratamento que o METAFONT original dá para tais
valores.

Converter um número de 32 bits para uma string de 1
caractere em UTF-8 dentro de um buffer de 5 caracteres é feito pela
seguinte função:

@<Metafont: Funções Estáticas@>+=
void number2utf8(uint32_t number, char *result){
  int endian_probe_x = 1;
  char *number_probe = (char *) & number;
  char *little_endian = (char *) & endian_probe_x;
  if(number <= 127){
    result[0] = (char) number;
    result[1] = '\0';
    return;
  }
  if(number <= 2047){
    if(*little_endian){
      result[0] = number_probe[1];
      result[1] = number_probe[0];
      result[2] = '\0';
      return;
    }
    else{
      result[0] = number_probe[2];
      result[1] = number_probe[3];
      result[2] = '\0';
      return;
    }
  }
  if(number <= 65535){
    if(*little_endian){
      result[0] = number_probe[2];
      result[1] = number_probe[1];
      result[2] = number_probe[0];
      result[3] = '\0';
      return;
    }
    else{
      result[0] = number_probe[1];
      result[1] = number_probe[2];
      result[2] = number_probe[3];
      result[3] = '\0';
      return;
    }
  }
  if(*little_endian){
    result[0] = number_probe[3];
    result[1] = number_probe[2];
    result[2] = number_probe[1];
    result[3] = number_probe[0];
    result[4] = '\0';
    return;
  }
  else{
    result[0] = number_probe[0];
    result[1] = number_probe[1];
    result[2] = number_probe[2];
    result[3] = number_probe[3];
    result[4] = '\0';
    return;
  }
}
@

A principal utilidade desta expressão é que ela fotrnece uma forma de
gerar uma string com aspas, algo que sem isso seria impossível.

Para avaliar ela, precisaríamos primeiro ver qual a definição
gramatical para um primário numérico. Mas por hora, iremos apenas
assumir ser sempre um token numérico:

@<Metafont: Funções Estáticas@>+=
struct token *numeric_primary(struct metafont **mf, struct token **token){
    struct token *result;
    if(token == NULL){
        mf_error(*mf, "ERROR: Missing numeric primary.");
        return NULL;
    }
    if((*token) -> type == NUMERIC){
      result = new_token_number((*token) -> value);
      result -> next = (*token) -> next;
      if((*token) -> next != NULL)
        (*token) -> next -> prev = result;
      result -> prev = (*token) -> prev;
      if((*token) -> prev != NULL)
        (*token) -> prev -> next = result;
      *token = (*token) -> next;
      return result;
    }
    mf_error(*mf, "ERROR: Unknown numeric primary.");
    return NULL;
}
@

E com isso escrevemos a implementação de nossa nova expressão:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "char")){
    char buffer[5] = {0x00, 0x00, 0x00, 0x00};
    unsigned long number;
    bool deterministic;
    struct token *result;
    if(current_token -> next == NULL){
      mf_error(*mf, "Missing numeric primary.");
      return NULL;
    }
    result = numeric_primary(mf, &(current_token -> next));
    if(result == NULL)
        return NULL;
    if(result -> type != NUMERIC){
      mf_error(*mf, "Not recognized numeric primary.");
      return NULL;
    }
    deterministic = result -> deterministic;
    number = (unsigned long) round(result -> value);
    number2utf8((uint32_t) number, buffer);
    result = new_token_string(buffer);
    result -> deterministic = deterministic;
    result -> next = current_token -> next;
    result -> prev = current_token -> prev;
    if(result -> next != NULL)
        result -> next -> prev = result;
    if(result -> prev != NULL)
        result -> prev -> next = result;
    else
        *expression = result;
}
@

@*2 Expressões \monoespaco{decimal}.

Estas expressões também consomem o próximo numérico primário presente
e irão retornar uma representação em string dele, no formato
decimal. Se o número for negativo, sua representação começa com
``-''. Ele será representado com 6 casas decimais, removendo as casas
decimais ao final cujo valor seja zero:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "decimal")){
    struct token *result;
    char buffer[32];
    bool deterministic;
    int n;
    if(current_token -> next == NULL){
      mf_error(*mf, "Missing numeric primary.");
      return NULL;
    }
    result = numeric_primary(mf, &(current_token -> next));
    if(result == NULL)
        return NULL;
    if(result -> type != NUMERIC){
      mf_error(*mf, "Not recognized numeric primary.");
      return NULL;
    }
    deterministic = result -> deterministic;
    snprintf(buffer, 32, "%f", result -> value);
    // Removing trainling zeros:
    for(n = 0; buffer[n] != '\0'; n ++);
    n --;
    while(buffer[n] == '0' && n >= 0){
        buffer[n] = '\0';
        n --;
    }
    if(n >= 0 && buffer[n] == '.')
        buffer[n] = '\0';
    // Creating string token
    result = new_token_string(buffer);
    result -> deterministic = deterministic;
    result -> next = current_token -> next;
    result -> prev = current_token -> prev;
    if(result -> next != NULL)
        result -> next -> prev = result;
    if(result -> prev != NULL)
        result -> prev -> next = result;
    else
        *expression = result;
}
@

@*2 Expressões \monoespaco{substring}.

Estas expressões consomem um par, o símbolo \monoespaco{of} e uma
outra expressão primária de string. A primeira coisa que temos a fazer
é definir como iremos representar um par. Vamos criar um novo tipo de
token para eles. Tal token nunca será lido de um arquivo, ele sempre
será o resultado de uma avaliação. E o tipo dele será:

@<Metafont: Variáveis Estáticas@>+=
// Tipo de token (já deifnido)
//#define PAIR   6
@

Um par é como um número, ms eles armazenam dois valores numéricos ao
invés de um. Vamos então criar a variável onde eles irão colocar este
segundo número:

@<Metafont: Atributos de Token@>+=
float value2;
@

Que será inicializado sempre como zero no construtor normal de tokens:

@<Metafont: Construção de Token@>+=
token -> value2 = 0.0;
@

Agora, assim como temos uma função \monoespaco{numeric\_primary} que
consome um primário numérico e retorna seu resultado,, criaremos um
\monoespaco{pair\_primary}. Da mesma forma, por hora deixaremos a
definição desta função incopmpleta até começarmos a tratar os pares de
maneira mais completa. Por hora, só iremos reconhecer pares na forma:

\alinhaverbatim
<Par Primário> --> ( <Expressão Numérica> , <Expressão Numérica> )
\alinhanormal

Assim, nossa definição de função será:

@<Metafont: Funções Estáticas@>+=
struct token *pair_primary(struct metafont **mf, struct token **token){
  struct token *result, *tok = *token;
  bool deterministic = true;
  if(tok == NULL){
    mf_error(*mf, "ERROR: Missing pair primary.");
    return NULL;
  }
  if(tok -> type == SYMBOL && !strcmp(tok -> name, "(") &&
     tok -> next != NULL && (tok -> next -> type != SYMBOL ||
                             strcmp(tok -> next -> name, "("))){
    struct token *n1, *n2;
    tok = tok -> next;
    if(tok == NULL){
      mf_error(*mf, "Missing numeric expression.");
      return NULL;
    }
    n1 = eval_numeric(mf, &tok);
    if(n1 == NULL)
      return NULL;
    deterministic = deterministic && n1 -> deterministic;
    if(n1 -> type != NUMERIC){
      mf_error(*mf, "Unknown numeric expression result.");
      return NULL;
    }
    if(tok == NULL || tok -> type != SYMBOL || strcmp(tok -> name, ",")){
      mf_error(*mf, "Missing ',' at pair.");
      return NULL;
    }
    tok = tok -> next;
    if(tok == NULL){
      mf_error(*mf, "Missing numeric expression.");
      return NULL;
    }
    n2 = eval_numeric(mf, &tok);
    if(n2 == NULL)
      return NULL;
    deterministic = deterministic && n2 -> deterministic;
    if(n2 -> type != NUMERIC){
      mf_error(*mf, "Unknown numeric expression result.");
      return NULL;
    }
    if(tok == NULL || tok -> type != SYMBOL || strcmp(tok -> name, ")")){
      mf_error(*mf, "Missing ')' at pair.");
      return NULL;
    }
    result = new_token_number(n1 -> value);
    result -> type = PAIR;
    result -> deterministic = deterministic;
    result -> value2 = n2 -> value;
    if((*token) -> prev != NULL)
      (*token) -> prev -> next = tok -> next;
    if(tok -> next != NULL)
      tok -> next -> prev = (*token) -> prev;
    *token = tok -> next;
    return result;
  }
  mf_error(*mf, "ERROR: Unknown numeric primary.");
  return NULL;
}
@

Com isso já podemos tratar a expressão de substrings. Se encontramos
uma, devemos primeiro avaliar a expressão primária de par que vem logo
em seguida. Depois disso, seguimos adiante sem fazer o restante. Mas
depois de resolvermos qualquer expressão primária, devemos checar se
temos antes de nós um par w uma operação de substring. Se tivermos, aí
sim realizamos a operação.

Então primeiro tratamos apenas o par:

@<Metafont: String: Expressões Primárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "substring")){
  struct token *pair, *substring_token;
  substring_token = current_token;
  current_token = current_token -> next;
  pair = pair_primary(mf, &current_token);
  if(pair == NULL){
    return NULL;
  }
  pair -> next = current_token;
  pair -> prev = substring_token;
  substring_token -> next = pair;
  if(current_token != NULL)
    current_token -> prev = pair;
}
@

Agora depois de tratar todos os casos de expressão primária, nós
checamos antes de continuar no loop se podemos avaliar uma expressão
substring. Definimos uma string como tendo seus bytes com coordenadas
que variam entre 0 e n. E ums substring $(a, b)$ são os caracteres
entre as coordenadas $(round(a), round(b))$ (obtidas após arredondar
os valores), incluindo elas próprias. Contudo, se $a>b$, o resultado é
a substring $(b, a)$ invertida, se $a < 0$, assumimos que ela é igual
à substring $(0, b)$ e se $b> n$ assumimos que ela é igual à substring
$(a, n)$.

@<Metafont: String: Expressões Primárias@>=
while(current_token != NULL && current_token -> prev != NULL &&
   current_token -> prev -> prev != NULL &&
   current_token -> prev -> prev -> prev != NULL &&
   current_token -> prev -> prev -> prev -> type == SYMBOL &&
   !strcmp(current_token -> prev -> prev -> prev -> name, "substring")){
  struct token *result;
  int i;
  long n1, n2, max_size;
  char *buffer;
  bool reversed, deterministic = true;
  if(current_token -> type != STRING){
    mf_error(*mf, "Can't get substring from an unknown string.");
    return NULL;
  }
  deterministic = deterministic && current_token -> deterministic;
  if(current_token -> prev -> type != SYMBOL ||
     strcmp(current_token -> prev -> name, "of")){
    mf_error(*mf, "Missing 'of' in substring expression.");
    return NULL;
  }
  if(current_token -> prev -> prev -> type != PAIR){
    mf_error(*mf, "Unknown pair after substring expression.");
    return NULL;
  }
  deterministic = deterministic &&
    current_token -> prev -> prev -> deterministic;
  max_size = (long) strlen(current_token -> name);
  n1 = (long) round(current_token -> prev -> prev -> value);
  if(n1 < 0)
    n1 = 0;
  if(n1 > max_size)
    n1 = max_size;
  n2 = (long) round(current_token -> prev -> prev -> value2);
  if(n2 > max_size)
    n2 = max_size;
  if(n2 < 0)
    n2 = 0;
  if(n1 > n2){
    reversed = true;
    max_size = n1 - n2 + 1;
  }
  else{
    reversed = false;
    max_size = n2 - n1 + 1;
  }
  buffer = (char *) Walloc_arena(_internal_arena, max_size);
  if(buffer == NULL){
    fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
            "value of W_INTERNAL_MEMORY at conf/conf.h.\n");
    exit(1);
  }
  if(!reversed)
    for(i = 0; i < max_size - 1; i ++)
      buffer[i] = current_token -> name[n1 + i];
  else
    for(i = 0; i < max_size - 1; i ++)
      buffer[i] = current_token -> name[n1 - i - 1];
  buffer[max_size - 1] = '\0';
  result = new_token_string(buffer);
  result -> deterministic = deterministic;
  result -> prev = current_token -> prev -> prev -> prev -> prev;
  result -> next = current_token -> next;
  if(result -> prev != NULL)
    result -> prev -> next = result;
  else
    *expression = result;
  if(result -> next != NULL)
    result -> next -> prev = result;
  current_token = result;
}
@

@*2 Concatenação de Strings.

A concatenação de string é feita usando o operador ``&''. Vamos
adicioná-lo à lista de ``sparks'':

@<Metafont: Declara Nova Spark@>+=
_insert_trie(primitive_sparks, _user_arena, INT, "&", 0);
@

Como o operador de concatenação é um operador terciário, ele é
avaliado quando avaliamos uma expressão quaternária:

@<Metafont: String: Expressões Quaternárias@>=
if(current_token -> type == SYMBOL &&
   !strcmp(current_token -> name, "&")){
  size_t new_string_size;
  size_t last_token_size, next_token_size;
  char *buffer;
  struct token *result;
  // O token anterior deve ser uma string:
  if(current_token -> prev == NULL || current_token -> prev -> type != STRING){
    mf_error(*mf, "Missing known string before '&'.");
    return NULL;
  }
  // O próximo token deve ser uma string:
  if(current_token -> next == NULL || current_token -> next -> type != STRING){
    mf_error(*mf, "Missing known string after '&'.");
    return NULL;
  }
  last_token_size = strlen(current_token -> prev -> name);
  next_token_size = strlen(current_token -> next -> name);
  new_string_size = last_token_size + next_token_size + 1;
  buffer = Walloc_arena(_internal_arena, new_string_size);
  if(buffer == NULL){
    fprintf(stderr, "ERROR: Not enough memory. Please, increase the "
            "value of W_INTERNAL_MEMORY at conf/conf.h.\n");
    exit(1);
  }
  memcpy(buffer, current_token -> prev -> name, last_token_size + 1);
  memcpy(&buffer[last_token_size], current_token -> next -> name,
	 next_token_size + 1);

  result = new_token_string(buffer);
  result -> deterministic = current_token -> next -> deterministic &&
    current_token -> prev -> deterministic;
  result -> prev = current_token -> prev -> prev;
  result -> next = current_token -> next -> next;
  if(result -> prev != NULL)
    result -> prev -> next = result;
  else
    *expression = result;
  if(result -> next != NULL)
    result -> next -> prev = result;
  // Se o começo da expressão foi consumido, consertar isso:
  if(*expression == current_token -> prev)
    *expression = result;
  current_token = result;
}
@

E isso conclui a definição de concatenação de strings.

@*1 Comandos de Mensagem.

Os Comandos de Mensagem tem a seguinte gramática:

\alinhaverbatim
<Comando de Mensagem> --> <Operador Mensagem> <Expressão String>
<Operador Mensagem> --> message | errmessage | errhelp
\alinhanormal

O primeiro imprime o resultado da expressão na saída padrão. O segundo
na saída de erro. O terceiro será ignorado, mas no METAFONT original
ajustaria a mensagem a ser exibida caso o usuário pedisse ajuda no
modo interativo após um erro ocorrer.

Primeiro vamos registrar estes novos ``sparks'':

@<Metafont: Declara Nova Spark@>+=
_insert_trie(primitive_sparks, _user_arena, INT, "message", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "errmessage", 0);
_insert_trie(primitive_sparks, _user_arena, INT, "errhelp", 0);
@

E agora vamos implementar estes comandos:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && (!strcmp(statement -> name, "message") ||
                                   !strcmp(statement -> name, "errmessage") ||
                                   !strcmp(statement -> name, "errhelp"))){
    struct token *expr_result;
    // Deve haver uma expressão de string pós o comando
    if(statement -> next == NULL){
        mf_error(*mf, "Missing string expression.");
        return;
    }
    expr_result = eval_string(mf, &(statement -> next));
    if(expr_result == NULL){
        return;
    }
    if(expr_result -> type != STRING){
        mf_error(*mf, "Tried to print unknown string (%s).",
                 expr_result -> name);
        return;
    }
    if(statement -> name[0] == 'm')
        printf("%s\n", expr_result -> name);
    else if(statement -> name[3] == 'm')
        fprintf(stderr, "%s\n", expr_result -> name);
    return;
}
@

@*1 Expansão de Macros.

Vamos enfim começar a tratar a função de expansão de macros, ao menos
o necessário para tratar alguns casos.

@*2 Macros sem Argumentos.

Estas são as macros que consistem apenas em substituição. Não
precisamos ler argumentos para elas e nem substituir os seus
parâmetros pelos argumentos lidos. Tratar o caso mais simples nos
permitirá gerar a versão inicial da função de expandir macros. Esta
função deve receber como argumento uma macro e um ponteiro para um
token, o qual representa o próximo token da lista a ser interpretada,
após a macro. Se a macro tivesse argumentos, ele seria o primeiro
argumento. Como ela não tem, ele é o próximo caractere a ser lido após
a macro. O retorno da função é um ponteiro para o primeiro token
gerado na expansão ou |NULL| caso tenhamos encontrado no argumento um
\monoespaco{begingroup} que terá que ser tratado antes pela próxima iteração do
interpretador.

@<Metafont: Funções Locais Declaradas@>+=
static struct token *expand_macro(struct metafont *, struct macro *,
				  struct token **);
@
@<Metafont: Funções Estáticas@>+=
static struct token *expand_macro(struct  metafont *mf, struct macro *mc,
				  struct token **tok){
  struct token *expansion = NULL, *current_token = NULL, *replacement;
  struct token *begin_arg = NULL, *end_arg = NULL;
  replacement = mc -> replacement_text;
  { // Lendo os argumentos
    struct token *arg = mc -> parameters;
    while(arg != NULL){
      @<Metafont: expand_macro: Lê Argumentos@>
      arg = arg -> next;
    }
  }
  { // Se já tratamos os argumentos sem sair, não encontramos blocos a
    // serem expandidos dentro do argumento. Vamos remover os
    // argumentos da lista de tokens interpretados
    if(begin_arg != NULL){
      if(begin_arg -> prev != NULL)
	begin_arg -> prev -> next = end_arg -> next;
      begin_arg -> prev = NULL;
      if(end_arg -> next != NULL)
	end_arg -> next -> prev = begin_arg -> prev;
      end_arg -> next = NULL;
    }
  }
  while(replacement != NULL){
    @<Metafont: expand_macro: Expande Argumento@>
    if(current_token != NULL){
      current_token -> next = new_token(replacement -> type,
                                        replacement -> value,
                                        replacement -> name,
                                        _internal_arena);
      if(current_token -> next == NULL)
        goto error_no_memory;
      current_token -> next -> prev = current_token;
      current_token = current_token -> next;
    }
    else{
      current_token = new_token(replacement -> type,
                                replacement -> value,
                                replacement -> name,
                                _internal_arena);
      if(current_token == NULL)
        goto error_no_memory;
      expansion = current_token;
      if(*tok != NULL)
        current_token -> prev = (*tok) -> prev;
      if(expansion -> prev != NULL)
        expansion-> prev -> next = expansion;
    }
    replacement = replacement -> next;
  }
  if(current_token != NULL){
    current_token -> next = *tok;
    if(*tok != NULL){
        (*tok) -> prev = current_token;
    }
    if(expansion != NULL)
      *tok = expansion;
  }
 exit_after_restore_macro:
  @<Metafont: expand_macro: Restaura Macro@>
  return *tok;
 error_no_memory:
  fprintf(stderr, "ERROR: Not enough memory. Please increase the value of "
          "W_INTERNAL_MEMORY at conf/conf.h.\n");
  exit(1);
  return NULL;
}
@

Mas e como iremos tratar os argumentos? Por padrão, uma lista de todos
os argumentos pode ser encontrada na própria macro na forma de uma
lista duplamente encadeada. Contudo, à medida quer lemos os argumentos
deixaremos que ela deixe de ser uma lista duplamente encadeada e
torne-se simplesmente encadeada. O ponteiro que seria usado para
apontar para a posição anterior será usado para armazenar o
argumento. Desta forma, durante a expansão poderemos tratar os
argumentos assim:

@<Metafont: expand_macro: Expande Argumento@>=
{
    struct token *arg = mc -> parameters;
    while(arg != NULL){
        if(replacement -> type == SYMBOL && !strcmp(replacement -> name,
                                                    arg -> name)){
            // É um parâmetro a ser substituído
            arg = arg -> prev;
            while(arg != NULL){
                if(current_token != NULL){
                    current_token -> next = new_token(arg -> type,
                                                      arg -> value,
                                                      arg -> name,
                                                      _internal_arena);
                    if(current_token -> next == NULL)
                        goto error_no_memory;
                    current_token -> next -> prev = current_token;
                    current_token = current_token -> next;
                }
                else{
                    current_token = new_token(arg -> type,
                                              arg -> value,
                                              arg -> name,
                                              _internal_arena);
                    if(current_token == NULL)
                        goto error_no_memory;
                    expansion = current_token;
                    expansion -> prev = (*tok) -> prev;
                    expansion-> prev -> next = expansion;
                }
                arg = arg -> next;
            }
            replacement = replacement -> next;
            break;
        }
        arg = arg -> next;
    }
    if(arg != NULL) // Se ocorreu substituição
      continue;
}
@

Naturalmente, isso significa que a lista duplamente encadeada de
argumentos da macro depois deve ser restaurada:

@<Metafont: expand_macro: Restaura Macro@>=
{
    struct token *arg = mc -> parameters;
    if(arg != NULL){
        arg -> prev = NULL;
        while(arg -> next != NULL){
            arg -> next -> prev = arg;
            arg = arg -> next;
        }
    }
}
@

Com relação aos argumentos de macros, vamos começar por hora tratando
apenas um caso. O caso no qual nosso argumento é o sufixo de uma
macro \monoespaco{vardef}. Neste caso, devemos simplesmente formar o
nosso argumento pegando todos os tokens que não forem ``sparks'' e que
sejam simbólicos:

@<Metafont: expand_macro: Lê Argumentos@>=
{
    // Rompemos encadeamento para armazenar expansão
    arg -> prev = NULL;
    if(arg -> type == VARDEF_ARG){
      // Marcamos o começo do argumento
      if(begin_arg == NULL)
	begin_arg = *tok;
      while(*tok != NULL && is_tag(mf, *tok)){
	// T(esquisito) <-->N(()
	struct token *next_token = (*tok) -> next;
	// Atualiza último argumento
	end_arg = *tok;
	if((*tok) -> prev != NULL)
	  (*tok) -> prev -> next = (*tok) -> next;
	if((*tok) -> next != NULL)
	  (*tok) -> next -> prev = (*tok) -> prev;
	(*tok) -> prev = (*tok) -> next = NULL;
	concat_token(&(arg -> prev), *tok);
	*tok = next_token;
      }
    }
    @<Metafont: expand_macro: Lê Expressão Delimitada@>
    @<Metafont: expand_macro: Lê Sufixo Delimitado@>
    @<Metafont: expand_macro: Lê Expressão Não-Delimitada@>
}
@

@*1 Equações e Atribuições.

As Equações e Atribuições são declarações METAFONT. As duas cosias são
muito semelhantes. A sintaxe delas é:

\alinhaverbatim
<Equação> --> <Expressão> = <Lado Direito>
<Atribuição> --> <Variável> := <Lado Direito>
<Lado Direito> --> <Equação>
               +-> <Atribuição>
               +-> <Expressão>
\alinhanormal

Isso significa que podemos ter uma declaração com
vários \monoespaco{=} juntos formando uma equação que possui várias
sub-equações internas.  E tudo isso pode ser o lado direito de uma
atribuição.

Tanto equações como atribuições servem para definir valores para
variáveis, pois elas criam relações de igualdade. Uma equação declara
queduas expressões tem resultados idênticos, e METAFONT deve
interpretá-los e assim tirar suas conclusões. Desta forma, podemos
escrever:

\alinhaverbatim
string a, b, c;
a = b = c;
"Teste" = c;
\alinhanormal

E com isso METAFONT saberá que \monoespaco{a="Teste"}. Mas uma vez que
definimos algo com uma equação, é um erro criar uma equação que
contradiga a anterior. Se uma variável é igual a uma coisa, ela não
pode ser igual à outra diferente, isso é uma contradição. Então se
quisermos mudar o valor de uma variável, devemos usar a atribuição,
não uma equação.

Como saberemos que uma variável é igual à outra? Simples, faremos as
variáveis string terem em sua estrutura um ponteiro para outra
variável que deve ser um sinônimo. Se o valor deste ponteiro for nulo,
então significa que não conhecemos nenhum sinônimo para ela:

@<Metafont: Variável String: Campos@>=
struct string_variable *alias;
@

Por padrão, inicializaremos este campo como nulo:

@<Metafont: Variável String: Inicialização@>=
new_variable -> alias = NULL;
@

Vamos então criar uma função que declara que duas variáveis, dado os
seus nomes, seus nomes como declarados e uma estrutura METAFONT são
iguais. A segunda variável sempre é indefinida. A flag passada por
último define se queremos sobrescrever o valor da primeira variável,
removendo ela de sua lista encadeada de igualdades (ou seja, estamos
usando com um \monoespaco{:=}). Se ela for falsa, estamos apenas
definindo uma igualdade, o que significa que estamos aumentando uma
lista encadeada de igualdades ou definindo o valor dela

@<Metafont: Funções Estáticas@>+=
static void equal_variables(struct metafont *mf, char *name1, char *name2,
                            char *declared1, char *declared2,
                            bool overwrite){
    struct string_variable *var1 = NULL, *var2 = NULL;
    void *arena1 = _user_arena, *arena2 = _user_arena;
    int var1_type = NOT_DECLARED, var2_type = NOT_DECLARED;
    struct metafont *scope1, *scope2;
    char types[8][10] = {"boolean", "path", "string", "numeric", "pen",
                         "picture", "transform", "pair"};
    scope1 = get_scope(mf, declared1);
    if(scope1 -> parent != NULL)
      arena1 = metafont_arena;
    _search_trie(scope1 -> variable_types, INT, declared1, &var1_type);
    if(var1_type == NOT_DECLARED)
        var1_type = NUMERIC;
    scope2 = get_scope(mf, declared2);
    if(scope2 -> parent != NULL)
      arena2 = metafont_arena;
    _search_trie(scope2 -> variable_types, INT, declared2, &var2_type);
    if(var2_type == NOT_DECLARED)
      var2_type = NUMERIC;
    if(var1_type != var2_type){
        mf_error(mf, "Equation cannot be performed (%s=%s).", types[var1_type],
            types[var2_type]);
        return;
    }
    // Elas tem o mesmo tipo. Obter o valor delas:
    if(var1_type == STRING){
        _search_trie(scope1 -> vars[STRING], VOID_P, name1, (void *) &var1);
        _search_trie(scope2 -> vars[STRING], VOID_P, name2, (void *) &var2);
        // Se var2 não existir, criamos ele
        if(var2 == NULL){
            var2 = (struct string_variable *)
                Walloc_arena(arena2, sizeof(struct string_variable));
            var2 -> name = NULL;
            var2 -> deterministic = true;
            var2 -> prev = var2 -> next = NULL;
            _insert_trie(scope2 -> vars[STRING], arena2, VOID_P, name2,
                         (void *) var2);
        }
        if(var1 == NULL){
            // var1 não é definido e precisa ser criado
            var1 = (struct string_variable *)
                Walloc_arena(arena1, sizeof(struct string_variable));
            var1 -> name = NULL;
            var1 -> deterministic = var2 -> deterministic;
            var1 -> prev = NULL;
            var1 -> next = var2;
            if(var2 -> prev != NULL)
                var2 -> prev -> next = var1;
            var2 -> prev = var1;
            _insert_trie(scope1 -> vars[STRING], arena1, VOID_P, name1,
                        (void *) var1);
            return;
        }
        else if(var1 != NULL){
            // var1 (existente) <- var2 (indefinido)
            // A variavel direita não foi definida, a esquerda sim. Se
            // não marcamos para sobrescrever, só tornamos elas iguais
            // ao criar a da direita ou criamos um alias. Se marcamos
            // para sobrescrever, então precisamos criar a da direita
            // e fazer a esquerda virar um alias para a direita:
            if(var1 -> prev != NULL || var1 -> next != NULL){
                // var1 é existente e indefinido, concatenamos duas
                // listas de igualdade
                while(var1 -> next != NULL)
                    var1 = var1 -> next;
                while(var2 -> prev != NULL)
                    var2 = var2 -> prev;
                var1 -> next = var2;
                var2 -> prev = var1;
                // Aumentada lista de igualdade
                return;
            }
            else{
                if(overwrite){
                    // var1 torna-se indefinido e igual à var2,
                    // independente das flags
                    var1 -> next = var2;
                    var1 -> prev = var2 -> prev;
                    if(var2 -> prev != NULL)
                        var2 -> prev -> next = var1;
                    var2 -> prev = var1;
                    return;
                }
                else{
                    int tamanho = strlen(var1 -> name);
                    // Todos os valores da lista de igualdades de var2
                    // ficam igual a var1
                    while(var2 -> prev != NULL)
                        var2 = var2 -> prev;
                    while(var2 != NULL){
                        struct string_variable *next_var;
                        var2 -> prev = NULL;
                        var2 -> name = (char *) Walloc_arena(arena2,
                                                             tamanho + 1);
                        memcpy(var1 -> name, var2 -> name, tamanho + 1);
                        next_var = var2 -> next;
                        var2 -> next = NULL;
                        var2 = next_var;
                    }
                    return;
                }
            }
        }
    }
}
@

Agora que temos uma forma de dizer que $a=b$, e não apenas que
$a=$``Teste'', podemos implementar estes que são um dos últimos tipos
de declaração. Para isso primeiro devemos observar que equações e
atribuições, se junts na mesma declaração, devem ser sempre
interpretados da direita para a esquerda.

O plano para tratar equações e atribuições então será o seguinte:
primeiro percorremos toda a declaração que recebemos. Só faremos isso
depois de checar se não estamos diante de qualquer outro tipo de
declaração. Logo, só poderemos estar diante ou de uma
equação/atribuição ou de uma expressão isolada (que só faz sentido no
final de um bloco de declarações). O que diferencia uma coisa da outra
é justamente a presença de \monoespaco{=} e \monoespaco{:=}. Então
devemos percorrer tudo até o final até achar um destes tokens. Se não
achamos, então não é euqação/atribuição e continuamos em frente. Se
for, a cada um dos \monoespaco{=} e \monoespaco{:=} que encontrarmos,
vamos armazenar em um array para irmos percorrendo como uma pilha.

Feito isso, para cada token \monoespaco{=} e \monoespaco{:=} que
iremos percorrer, faremos o seguinte:

1. Usamos o \monoespaco{eval} no que está à direita dele. Se o
resultado for nulo, ou entramos em um grupo ou achamos um erro. De
qualquer forma interrompemos tudo e retornamos nulo. Caso contrário,
enquanto o token que temos memorizado por último for um \monoespaco{=}
ao invés de um \monoespaco{:=}, iremos usar \monoespaco{eval} no quê
está antes também. Caso contrário, é só ler como variável o que está
lá obtendo seu nome e seu nome conforme declarado.

2. Feito isso, temos que checar o que obtemos em cada lado da
avaliação. Se do lado direito temos uma string, usamos a função que
criamos quando introduzimos variáveis de string para armazenar a
string à direita na variável à esquerda. Se não for uma string, temos
uma variável indefinida.Usaremos a função que acabamos de definir logo
acima.

3. Depois de fazer isso, fazemos a substituição necessária e vamos
para o próximo \monoespaco{=} ou \monoespaco{:=}. Se acabamos de sair
de um \monoespaco{:=}, então só temos que checar se não há mais
equações ou atribuições, ou sinalizamos erro. Se acabaram os tokens de
atribuição e equação, então terminamos.

Então, vamos ao código:

@<Metafont: Executa Declaração@>=
{
  struct token *tok = statement, *last_separator = NULL;
  struct token *last_semicolon = NULL;
  bool found_equation_or_attribution = false;
  int type = -1;
  struct token *token_stack[512];
  int token_stack_position = -1;
  // Ligamos os tokens = e := uns nos outros:
  while(tok != NULL){
    if(tok -> type == SYMBOL &&
       (!strcmp(tok -> name, ":=") || !strcmp(tok -> name, "="))){
      token_stack_position ++;
      token_stack[token_stack_position] = tok;
      last_separator = tok;
      found_equation_or_attribution = true;
    }
    last_semicolon = tok;
    tok = tok -> next;
  }
  // Enquanto temos um destes tokens para tratar:
  while(last_separator != NULL){
    char left_var[1024], left_var_type[1024];
    char right_var[1024], right_var_type[1024];
    struct token *left, *right = eval(mf, &(last_separator -> next));
    if(right == NULL){ // Erro ou begingroup encontrado:
      for(tok = statement; tok -> next != NULL; tok = tok -> next)
        tok -> next -> prev = tok;
      return;
    }
    if(last_separator -> name[0] == ':'){
      if(token_stack_position > 0){
        mf_error(*mf, "Not a variable before ':='.");
        return;
      }
      variable(mf, &statement, left_var, 1024, left_var_type, &type, true);
      if(statement -> type != SYMBOL || (strcmp(statement -> name, "=") &&
                                         strcmp(statement -> name, ":="))){
        mf_error(*mf, "Not a variable before ':='.");
        return;
      }
      if(right -> type == SYMBOL){
          // O lado direito não avaliou para um literal
        variable(mf, &right, right_var, 1024, right_var_type, &type, true);
          equal_variables(*mf, left_var, right_var, left_var_type,
                          right_var_type, true);

      }
      else{
          // O lado direito é um literal
          if(right -> type == STRING)
              new_defined_string_variable(left_var, left_var_type, right, *mf,
                                          true);
      }
      return; // Acabamos, depois de um ':=' não há mais nada
    }
    else{
        // Estamos em um '=', não ':='
        if(token_stack_position > 0)
            left = eval(mf, &(token_stack[token_stack_position - 1] -> next));
        else
            left = eval(mf, &statement);
        if(right -> type == SYMBOL && left -> type == SYMBOL){
          variable(mf, &left, left_var, 1024, left_var_type, &type, false);
          variable(mf, &right, right_var, 1024, right_var_type, &type, false);
          equal_variables(*mf, left_var, right_var, left_var_type,
                          right_var_type, false);
        }
        else if(right -> type == SYMBOL){
          variable(mf, &right, right_var, 1024, right_var_type, &type, false);
          new_defined_string_variable(right_var, right_var_type, left, *mf,
                                      false);
        }
        else if(left -> type == SYMBOL){
            // Obtém variável como string e depois a restaura
            variable(mf, &left, left_var, 1024, left_var_type, &type, false);
            new_defined_string_variable(left_var, left_var_type, right, *mf,
                                        false);
        }
        else{
            // Igualdade entre dois literais, isso é um erro:
          if(left -> type == right -> type && !strcmp(left -> name,
                                                      right -> name)){
            mf_error(*mf, "Redundant equation.");
            return;
          }
          else{
            mf_error(*mf, "Inconsistent equation (%s = %s).", left -> name,
                     right -> name);
            return;
          }
        }
    }
    last_separator -> prev -> next = last_semicolon;
    last_semicolon -> prev = last_separator -> prev;
    token_stack_position --;
    if(token_stack_position >= 0)
      last_separator = token_stack[token_stack_position];
    else
      last_separator = NULL;
  }
  if(found_equation_or_attribution)
    return;
}
@

Por fim, existe uma última preocupação que devemos ter. Uma variável
pode estar em uma lista encadeada de igualdade. Contudo, ela pode ser
ua variável local a um bloco, e que será desalocada assim que sairmos
deste bloco. Isso significa que quando acabamos com um escopo,
precisamos percorrer todas as variáveis de string locais à ele e
removê-las da lista de igualdade na qual estão.

O modo de remover uma variável string é por meio da função:

@<Metafont: Funções Locais Declaradas@>+=
static void remove_string_variable_from_equalty_list(void *string_var);
@

@<Metafont: Funções Estáticas@>+=
static void remove_string_variable_from_equalty_list(void *string_var){
    struct string_variable *string = (struct string_variable *) string_var;
    if(string -> prev != NULL)
        string -> prev -> next = string -> next;
    if(string -> next != NULL)
        string -> next -> prev = string -> prev;
}
@

E agora vamos declarar e definir uma função que já usamos em alguns
códigos prévios, devido à sua utilidade ser aparente pelo nome. A
função que finaliza um escopo atual antes de destruir suas
estruturas. Essa função é a que removerá todas as strings locais que
existirem de qualquer lista de igualdade antes de desalocá-las:

@<Metafont: Funções Locais Declaradas@>+=
static void end_scope(struct metafont *mf);
@

@<Metafont: Funções Estáticas@>+=
static void end_scope(struct metafont *mf){
    _map_trie(remove_string_variable_from_equalty_list, mf -> vars[STRING]);
}
@

@*1 Parâmetros de Expressões.

A utilidade do \monoespaco{vardef} que declaramos não é apenas
declarar um número potencialmente infinito de variáveis cujo valor é
deduzido por meio de expressões mais complexas e sofisticadas baseadas
no nome. Devido à ordem em que elas são avaliadas, isso faz com que
elas sejam a forma correta de declarar novos operadores unários, os
quais podem receber parâmetros.

O primeiro tipo de parâmetros são expressões, os quais podem ser
delimitados ou não-delimitados. Se esperamos um parâmetro delimitado,
então devemos ler:

\alinhaverbatim
( <Expressão> )
\alinhanormal

Onde o delimitador não precisa ser necessariamente o parênteses, mas
qualquer coisa que tenha sido definida como delimitador. Ao invés de
fechar o parênteses, podemos ter depois uma vírgula e outros
parâmetros. Em tais casos, se não lemos o último parâmetro, apenas
substituímos a vírgula por \monoespaco{)(}, ou qualquer que seja o
delimitador.

Em tais casos, podemos ter que ler:

\alinhaverbatim
( <Expressão> ,
\alinhanormal

onde depois da vírgula teremos mais argumentos antes do fechamento de
parênteses.

@<Metafont: expand_macro: Lê Expressão Delimitada@>=
else if(arg -> type == EXPR){
  struct token *begin_delim, *end_delim;
  struct token *next_token = (*tok) -> next;
  bool last_arg = (arg -> next == NULL);
  char *delim;
  int number_of_delimiters = 0;
  // Primeiro temos que ler o delimitador
  begin_delim = *tok;
  delim = delimiter(mf, begin_delim);
  if(delim == NULL){
    mf_error(mf, "Missing argument.");
    return NULL;
  }
  // Achar o fim do delimitador
  number_of_delimiters ++;
  end_delim = begin_delim -> next;
  while(end_delim != NULL){
    if(end_delim -> type == SYMBOL && !strcmp(end_delim -> name, delim))
      break;
    end_delim = end_delim -> next;
  }
  if(end_delim == NULL || end_delim == begin_delim -> next){
    mf_error(mf, "Missing or invalid argument.");
    return NULL;
  }
  end_delim -> prev -> next = NULL;
  next_token = begin_delim -> next;
  arg -> prev = eval(&mf, &next_token);
  end_delim -> prev -> next = end_delim;
  if(!last_arg && next_token -> next != NULL &&
     next_token -> next -> type == SYMBOL &&
     !strcmp(next_token -> next -> name, ",")){
    // Trocando a vírgula por novo '('
    begin_delim -> next = next_token -> next -> next;
    next_token -> next -> next -> prev = begin_delim;
    arg -> prev -> next = NULL;
    *tok = begin_delim;
  }
  else{
    arg -> prev -> next = NULL;
    *tok = end_delim -> next;
    begin_delim -> prev -> next = end_delim -> next;
    end_delim -> next -> prev = begin_delim -> prev;
  }
}
@

Caso não seja uma expressão delimitada, devemos ler a maior expresão
possível, sem a ajuda de delimitadores para ajudar. Para isso vamos
simplesmente confiar na nossa função \monoespaco{eval} para fazer o
trabalho por nós:


@<Metafont: expand_macro: Lê Expressão Não-Delimitada@>=
else if(arg -> type == UNDELIMITED_EXPR){
  // Sabemos que a expressão não começa com um '(', pois ela não é
  // delimitada. Entretanto, ela pode começar com um 'begingroup'.
  // Em tais casos, não avaliaremos o 'begingroup', apenas copiaremos
  // ele até o seu 'endgroup' e armazenaremos isso como o argumento.
  // Nos demias casos, apenas avaliamos a expressão.
  if((*tok) -> type == SYMBOL && !strcmp((*tok) -> name, "begingroup")){
    int number_of_begins = 1;
    struct token *begin = *tok, *end = *tok;
    while(number_of_begins > 0){
      if((*tok) != NULL && (*tok) -> next == NULL)
	(*tok) -> next = get_statement(mf);
      *tok = (*tok) -> next;
      if(*tok == NULL){
	mf_error(mf, "Missing or invalid argument.");
	return NULL;
      }
      if((*tok) -> type == SYMBOL && !strcmp((*tok) -> name, "begingroup"))
	number_of_begins ++;
      else if((*tok) -> type == SYMBOL && !strcmp((*tok) -> name, "endgroup")){
	number_of_begins --;
	end = *tok;
      }
    }
    if((*tok) -> next != NULL){
      *tok = (*tok) -> next;
      (*tok) -> prev = NULL;
    }
    end -> next = NULL;
    arg -> prev = begin;
  }
  else{
    arg -> prev = eval(&mf, tok);
    *tok = (*tok) -> next;
    (*tok) -> prev = arg -> prev -> prev;
    arg -> prev -> prev = NULL;
    arg -> prev -> next = NULL;
  }
}
@

@*1 Parâmetros de Sufixos.

Um sufixo pode ser qualquer quantidade de tags ou subscritos,
inclusive nenhum. São usados para nos referirmos a variáveis ou a
sufixos de variáveis. Eles podem também ser argumentos de macros tais
como os \monoespaco{vardefs} que estamos construindo. Assim como as
expressões, eles podems ser passados como parâmetros delimitados ou
não-delimitados para macros.

Vamos tratar primeiro o caso não-delimitado, lembrando que primeiro
temos que buscar os delimitadores. Aparentemente seria mais fácil
fazer isso em sufixos que em expressões, pois embora uma eexpressão
como $(x+1)(x-1)$ tenha seus próprios delimitadores que precisam ser
levados em conta, espera-se que delimitadores não façam parte de nomes
de variáveis. Contudo, deve-se lembrar que isso na verdade é falso,
pois podemos sim ter uma variável passada como argumento na forma
$var[(x+1)(x-1)]$. Então temos que ser tão estritos aqui como no caso
de expressões:

@<Metafont: expand_macro: Lê Sufixo Delimitado@>=
else if(arg -> type == SUFFIX){
  struct token *begin_delim, *end_delim;
  bool last_arg = (arg -> next == NULL);
  char *delim;
  // Nosso tratamento de delimitradores será tão estrito como o
  // último. Então temos que ter uma contagem de quantos lemos.
  int number_of_delimiters = 0;
  begin_delim = *tok;
  delim = delimiter(mf, begin_delim);
  if(delim == NULL){
    mf_error(mf, "Missing argument.");
    return NULL;
  }
  // Achar o fim do delimitador
  number_of_delimiters ++;
  end_delim = begin_delim -> next;
  while(end_delim != NULL){
    if(end_delim -> type == SYMBOL && (!strcmp(end_delim -> name, delim) ||
				       !strcmp(end_delim -> name, ",")))
      break;
    // Checando se não é um tag nem um número:
    if(!is_tag(mf, end_delim) && end_delim -> type != NUMERIC){
      // Se não é um tag, tem que ser um subscrito tipo [(expressão numérica)].
      end_delim = end_delim -> next;
      if(end_delim == NULL || end_delim -> type != SYMBOL ||
	 strcmp(end_delim -> name, "[") || end_delim -> next == NULL){
	mf_error(mf, "Missing or invalid suffix argument.");
	return NULL;
      }
      end_delim = end_delim -> next;
      end_delim = eval_numeric(&mf, &end_delim);
      if(end_delim == NULL)
	goto  exit_after_restore_macro; // Possivelmente um begingroup encontrado
      end_delim = end_delim -> next;
      if(end_delim == NULL || strcmp(end_delim -> name, "]")){
	mf_error(mf, "Missing or invalid suffix argument. Missing ']'.");
	return NULL;
      }
    }
    end_delim = end_delim -> next;
  }
  if(end_delim == NULL){
    mf_error(mf, "Missing or invalid suffix argument.");
    return NULL;
  }
  // Substituir o delimitador ',' por '(' se der
  if(!last_arg && strcmp(end_delim -> name, delim)){
    struct token *new_delim = new_token_symbol(begin_delim -> name);
    new_delim -> next = end_delim -> next;
    new_delim -> prev = end_delim -> prev;
    if(end_delim -> next != NULL)
      end_delim -> next -> prev = new_delim;
    if(end_delim -> prev != NULL)
      end_delim -> prev -> next = new_delim;
    end_delim = new_delim;
  }
  // Copiar o conteúdo entre delimitadores para o espaço do argumento:
  end_delim -> prev -> next = NULL; // Rompe temporariamente o encadeamento
  // A arena interna é onde estão os tokens temporários interpretados:
  arg -> prev = copy_token_list(begin_delim -> next, _internal_arena);
  end_delim -> prev -> next = end_delim; // Conserta encadeamento
  if(begin_delim -> prev != NULL)
    begin_delim -> prev -> next = end_delim -> next;
  if(end_delim -> next != NULL)
    end_delim -> next -> prev = begin_delim -> prev;
  begin_delim -> prev = begin_delim -> next = NULL;
  end_delim -> prev = end_delim -> next = NULL;
}
@
