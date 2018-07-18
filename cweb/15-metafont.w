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
@<Metafont: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@

@(project/src/weaver/metafont.c@>=
#include "weaver.h"
@<Metafont: Inclui Cabeçalhos@>
@<Metafont: Variáveis Estáticas@>
@<Metafont: Funções Estáticas@>
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
    struct metafont *parent;
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
    structure -> buffer_position = 0;
    structure -> line = 1;
    structure -> error = false;
    @<METAFONT: Inicializa estrutura METAFONT@>
    @<METAFONT: Executa Arquivo de Inicialização@>
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
    mf = _new_metafont(NULL, "fonts/init.mf");
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
    char ret = mf -> buffer[mf -> buffer_position];
    size_t size;
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
    char ret = mf -> buffer[mf -> buffer_position];
    size_t size;
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
void mf_error(struct metafont *mf, char *message){
    if(! mf -> error){
        fprintf(stderr, "ERROR: Metafont: %s:%d: %s\n",
                mf -> filename, mf -> line, message);
        mf -> error = true;
        // Finaliza a leitura de mais código:
        if(mf -> fp != NULL){
            fclose(mf -> fp);
            mf -> fp = NULL;
        }
        mf -> buffer_position = 0;
        mf -> buffer[mf -> buffer_position] = '\0';
    }
}
@

E também uma função para finalizar o interpretador sem erros:

@<Metafont: Funções Estáticas@>+=
void mf_end(struct metafont *mf){
    // Finaliza a leitura de mais código:
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
/*\\
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
#define NUMBER 1
#define STRING 2
#define SYMBOL 3
struct token{
    int type;
    float value; // Para números
    char *name; // Para strings e identificadores
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
    struct token *ret;
    ret = (struct token *) Walloc_arena(memory_arena, sizeof(struct token));
    if(ret == NULL)
        goto error_no_memory;
    ret -> type = type;
    ret -> value = value;
    if(name != NULL){
        ret -> name = Walloc_arena(memory_arena, strlen(name) + 1);
        if(ret -> name == NULL)
            goto error_no_memory;
        strcpy(ret -> name, name);
    }
    else
        ret -> name = name;
    ret -> prev = ret -> next = NULL;
    return ret;
error_no_memory:
    fprintf(stderr, "ERROR (0): Not enough memory to parse METAFONT "
            "source. Please, increase the value of %s "
            "at conf/conf.h.\n",
            (memory_arena == _user_arena)?"W_MAX_MEMORY":
            "W_INTERNAL_MEMORY");
    return NULL;
}
#define new_token_number(a) new_token(NUMBER, a, NULL, _internal_arena)
#define new_token_string(a) new_token(STRING, 0.0, a, _internal_arena)
#define new_token_symbol(a) new_token(SYMBOL, 0.0, a, _internal_arena)
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
            strcpy(family, ".");
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
        strcpy(family, "abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ");
        break;
    case '<': case '=': case '>': case ':': case '|':
        strcpy(family, "<=>:|");
        break;
    case '`': case '\'':
        strcpy(family, "`'");
        break;
    case '+': case '-':
        strcpy(family, "+-");
        break;
    case '/': case '*': case '\\':
        strcpy(family, "/*\\");
        break;
    case '!': case '?':
        strcpy(family, "!?");
        break;
    case '#': case '&': case '@@': case '$':
        strcpy(family, "#&@@$");
        break;
    case '[':
        strcpy(family, "[");
        break;
    case ']':
        strcpy(family, "]");
        break;
    case '{': case '}':
        strcpy(family, "{}");
        break;
    case '~': case '^':
        strcpy(family, "~^");
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
static void concat_token(struct token *before, struct token *after){
    if(after == NULL)
        return;
    while(before -> next != NULL)
        before = before -> next;
    before -> next = after;
    after -> prev = before;
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
interpretado.:

@<METAFONT: Estrutura METAFONT@>+=
struct token *pending_tokens;
@


Essa estrutura será inicializada por:

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> pending_tokens = NULL;
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
            if(mf -> pending_tokens == NULL)
                current_token -> next = next_token(mf);
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
            concat_token(mf -> pending_tokens, current_token -> next);
    }
    current_token -> next = NULL;
    @<Metafont: Imediatamente após gerarmos uma declaração completa@>
    return first_token;
source_incomplete_or_with_error:
    mf_error(mf, "Source with error or incomplete, aborting.");
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
        if(mf -> pending_tokens == NULL)
            _iWbreakpoint();
        if(first_loop){
            @<Metafont: Antes de Obter a Primeira Declaração@>
            first_loop = false;
        }
        @<METAFONT: Imediatamente antes de ler próxima declaração@>
        statement = get_statement(mf);
        if(statement == NULL)
            end_execution = true;
        else
            run_single_statement(&mf, statement);
        @<METAFONT: Imediatamente após executar declaração@>
        if(mf -> pending_tokens == NULL)
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
    if(statement -> type == SYMBOL && !strcmp(statement -> name, ";"))
        return;
    @<Metafont: Executa Declaração@>
    mf_error(*mf, "Isolated expression. I couldn't find a = or := after it.");
    return;
}
@

Outra coisa que ainda não definimos é a função que expande um único
token para um ou mais tokens. Essa é a implementação das macros de
METAFONT, as quais serão definidas logo em seguida.

@<Metafont: Função Estática expand_token@>=
bool expand_token(struct metafont *mf, struct token **first_token){
     // todo
     return false;
}
@

Com isso, podemos enfim fazer cada estrutura Metafont executar logo
após sua inicialização:

@<METAFONT: Executa Arquivo de Inicialização@>=
run_statements(structure);
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
          |-> <Comando message>
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
    strcpy((*mf) -> everyjob_token_name, statement -> next -> name);
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
    if(statement != NULL)
        concat_token((*mf) -> pending_tokens,
                     (*mf) -> parent -> pending_tokens);
    else
        (*mf) -> pending_tokens = (*mf) -> parent -> pending_tokens;
    (*mf) -> parent -> pending_tokens = NULL;
    return;
}
@

Já tratar o comando \monoespaco{endgroup} é mais complicado, pois ele
aparece tipicamente na penúltima posição (antes de um
ponto-e-vírgula), podendo aparecer na última caso o código esteja
incorreto por estar incompleto. Sendo assim, vamos criar uma forma da
fuinção que monta uma nova declaração avisar o nosso interpretador
caso ela leia um \monoespaco{endgroup} na penúltima ou última posição:

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
#define HINT_ENDGROUP 1
@

Quando somos avisados que temos que encerrar o grupo, após executarmos
a última declaração (da qual nós removeremos o token
\monoespaco{endgroup} antes), cuidaremos de remover a estrutura
METAFONT filha atual e voltarmos para a estrutura pai, restaurando o
escopo anterior:

@<METAFONT: Imediatamente após executar declaração@>=
if(mf -> hint == HINT_ENDGROUP){
    //struct metafont *p;
    // Caso de erro: usar endgroup sem begingroup:
    if(mf -> parent == NULL)
        mf_error(mf, "Extra 'endgroup' while not in 'begingroup'.");
    else{
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
// Curiosidade: a verdade é que nem sempre isso é uma declaração
// completa. Nós apenas paramos no ';', mas construções patológicas na
// linguagem podem usar o token ';' para outras coisas além de separar
// declarações. Mas não importa, embora possamos nos enganar, podemos
// nos recuperar destes enganos. O máximo que pode ocorrer é que
// construções patológicas na linguagem podem nos induzir a retornar
// mensagens de erro eradas.
if(first_token -> type != SYMBOL ||
     strcmp(first_token -> name, "begingroup")){
    if(current_token -> type == SYMBOL &&
       !strcmp(current_token -> name, "endgroup")){
        if(current_token -> prev != NULL)
            current_token -> prev -> next = NULL;
        else
            first_token = NULL;
        mf -> hint = HINT_ENDGROUP;
    }
    else if(current_token -> prev != NULL &&
            current_token -> prev -> type == SYMBOL &&
            !strcmp(current_token -> prev -> name, "endgroup")){
        if(current_token -> prev -> prev != NULL){
            current_token -> prev -> prev -> next = current_token;
            current_token -> prev = current_token -> prev -> prev;
        }
        else{
            current_token -> prev = NULL;
            first_token = current_token;
        }
        mf -> hint = HINT_ENDGROUP;
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
//#define STRING        2 // Já definido
#define PEN           3
#define PICTURE       4
#define TRANSFORM     5
#define PAIR          6
#define NUMERIC       7
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
    struct metafont *scope = (*mf);
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    while(scope -> parent != NULL){
        void *result;
        if(_search_trie(scope -> variable_types, VOID_P,
                        statement -> name, &result))
            break;
        scope = scope -> parent;
    }
    current_arena = (scope -> parent == NULL)?_user_arena:metafont_arena;
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        mf_error(*mf, "Missing symbolic token.");
        return;
    }
    end_delimiter = (char *) Walloc_arena(current_arena,
                                          strlen(statement -> name) + 1);
    if(end_delimiter == NULL){
        fprintf(stderr, "ERROR: Not enough memory to parse METAFONT. "
                "Please, increase the value of %s at conf/conf.h.\n",
                (current_arena==_user_arena)?"W_MAX_MEMORY":"W_INTERNAL_MEMORY");
        return;
    }
    strcpy(end_delimiter, statement -> name);
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
        struct metafont *scope = (*mf);
        while(scope -> parent != NULL){
            int dummy_result;
            if(_search_trie(scope -> variable_types, INT,
                            list -> name, &dummy_result))
                break;
            scope = scope -> parent;
        }
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
@

A definição acima conta com todas as sparks que já definimos em nossa
gramática. Outras ainda serão inseridas.

Com isso vamos escrever agora um código para interpretar e consumir
uma variável declarada e armazena em 'dst' uma string com o nome dela,
com cada sufixo separado pore espaços:

@<Metafont: Funções Estáticas@>=
void declared_variable(struct metafont *mf, struct token **token,
                       char *dst, int dst_size){
    struct token *first_token = *token, *current_token;
    dst[0] = '\0';
    // O primeiro token apenas deve ser simbólico
    if(first_token == NULL || first_token -> type != SYMBOL){
        mf_error(mf, "Missing symbolic token.");
        return;
    }
    current_token = first_token -> next;
    strncpy(dst, first_token -> name, dst_size - 1);
    strcat(dst, " ");
    dst_size -= (strlen(first_token -> name) + 1);
    while(current_token != NULL){
        // Se o token atual for ',' ou ';', devemos encerrar
	if(current_token -> type == SYMBOL &&
	   (!strcmp(current_token -> name, ",") ||
	    !strcmp(current_token -> name, ";"))){
	    current_token = current_token -> prev;
	    break;
	}
        // Os demais tokens precisam ser '[', ']' ou tags
	if(current_token -> type != SYMBOL ||
           (!is_tag(mf, current_token) &&
	    (strcmp(current_token -> name, "[") ||
             strcmp(current_token -> name, "]")))){
            mf_error(mf, "Illegal sufix.");
            return;
        }
	// Se não, apenas incrementa o contador do tamanho do nome do token
        strncpy(dst, first_token -> name, dst_size - 1);
        strcat(dst, " ");
        dst_size -= (strlen(current_token -> name) + 1);
    }
    dst[dst_size - 1] = '\0';
    if(current_token == NULL && first_token -> prev == NULL)
        *token = NULL;
    else if(current_token == NULL){
        first_token -> prev -> next = NULL;
	*token = NULL;
    }
    else if(first_token -> prev == NULL)
        *token = current_token -> next;
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
        while(scope -> parent != NULL){
            already_declared = _search_trie(scope -> variable_types, INT,
	                                    buffer,
					    &current_type_if_already_declared);
            if(already_declared)
                break;
            scope = scope -> parent;
        }
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
	    mf_error(*mf, "Missing symbolic token.");
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
#define PRIMARY   4
#define SECONDARY 5
#define TERTIARY  6
#define EXPR      7
#define SUFFIX    8
#define TEXT      9
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
            char *name = (char *)
                Walloc_arena(arena,
                             strlen(parameter_list -> name) + 1);
            if(name == NULL) goto error_no_memory;
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

E agora uma versão desta função apenas para parâmetros não-delimitados:

@<Metafont: Funções Estáticas@>+=
static struct token *undelimited_parameters(struct metafont *mf,
                                            struct token **token,
                                            void *arena){
    struct token *tok = *token;
    int type = NOT_DECLARED;
    char *name;
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
            type = EXPR;
        else if(!strcmp(tok -> name, "suffix"))
            type = SUFFIX;
        else if(!strcmp(tok -> name, "text"))
            type = TEXT;
        else return NULL;
    }
    tok = tok -> next;
    if(tok == NULL){
        mf_error(mf, "Missing symbolic token.");
        return NULL;
    }
    name = (char *) Walloc_arena(arena, strlen(tok -> name) + 1);
    if(name == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase"
                " the value of W_%s_MEMORY at conf/conf.h\n",
                (arena == _user_arena)?"MAX":"INTERNAL");
        return NULL;
    }
    *token = tok -> next;
    return new_token(type, 0.0, name, arena);
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
        char *name = NULL;
        if(tok == NULL || (depth <= 0 && tok -> type == SYMBOL &&
                           !strcmp(tok -> name, "enddef")))
            break;
        // Checando se é um token 'outer'
        if(tok -> type == SYMBOL && _search_trie(mf -> outer_tokens, INT,
                                                 tok -> name, &dummy)){
            mf_error(mf, "Forbidden token at macro.");
            return NULL;
        }
        // Contagem de sub-macros
        if(!strcmp(tok -> name, "def") || !strcmp(tok -> name, "vardef") ||
           !strcmp(tok -> name, "primarydef") ||
           !strcmp(tok -> name, "secondarydef") ||
           !strcmp(tok -> name, "tertiarydef"))
            depth ++;
        else if(!strcmp(tok -> name, "enddef"))
            depth --;
        // Adicionando token ao resultado:
        if(tok -> type != NUMERIC){
            name = (char *) Walloc_arena(arena, strlen(tok -> name) + 1);
            if(name == NULL) goto error_no_memory;
        }
        if(result != NULL){
            current_token -> next = new_token(tok -> type,
                                              tok -> value, name, arena);
            if(current_token -> next == NULL)
                goto end_of_function;
            current_token -> next -> prev = current_token;
            current_token = current_token -> next;
        }
        else{
            result = new_token(tok -> type, tok -> value, name, arena);
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
    return result;
error_no_memory:
    fprintf(stderr, "ERROR: Not enough memory. Please, increase"
            " the value of W_%s_MEMORY at conf/conf.h\n",
            (arena == _user_arena)?"MAX":"INTERNAL");
    return NULL;
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
    while(scope -> parent != NULL){
        int dummy_result;
        if(_search_trie(scope -> variable_types, INT,
                        name, &dummy_result)){
            current_arena = metafont_arena;
            break;
        }
        scope = scope -> parent;
    }
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
    new_macro -> parameters = undelimited_header;
    if(new_macro -> parameters == NULL)
        new_macro -> parameters = delimited_headers;
    else
        new_macro -> parameters -> next = delimited_headers;
    if(delimited_headers != NULL)
        delimited_headers -> prev = undelimited_header;
    // Token = ou :=
    if(statement == NULL || statement -> type != SYMBOL ||
       (strcmp(statement -> name, "=") && strcmp(statement -> name, ":="))){
        mf_error(*mf, "Missing '=' or ':=' at macro definition.");
        return;
    }
    // Texto de substituição:
    new_macro -> replacement_text = replacement_text(*mf, &statement,
                                                     current_arena);
    // Armazena a macro
    _insert_trie((*mf) -> macros, current_arena, VOID_P, name,
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

Note que todos os trechos acima já foram definidos previamente. Uma
Variável Declarada foi definida na declaraçãod e variáveis.