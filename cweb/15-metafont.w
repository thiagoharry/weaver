@* METAFONT.

METAFONT é uma linguagem criaa inicialmente para efinir fontes e
computador. Mas e fato, ela é uma linguagem capaz de definir desenhos
e imagens com uma única cor. Ela descreve todas as formas por meio de
equações geométricas, com ajuda e curvas de Bézier cúbicas. A versão
atual da linguagem foi criada em 1984 por Donald Knuth. A Engine
Weaver a usará como uma forma de receber instruções de desenhos e para
representar fontes.

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
@<Metafont: Funções Primitivas Estáticas@>
@<Metafont: Funções Estáticas@>
@<Metafont: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "metafont.h"
@

@<Metafont: Declarações@>+=
// A definir...
@

@<Metafont: Inclui Cabeçalhos@>+=
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

@*1 O Analizador Léxico.

A linguagem METAFONT possui as seguintes regras léxicas:

Regra 01: Pontos escartáveis: Se o próximo caractere for um espaço ou
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

Dito isso, o analizador léxico irá sempre produzir 7 tipos de tokens:
números, strings, ``('', ``)'', ``,'', ``;'' e
identificadores. Podemos representar cada token pela estrutura:

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
ponto-flutuante é melhor por ser mais rápida, ter pelo menos uma casa
decimal a mais de precisão e por ser capaz de representar uma maior
gama de números. Então não iremos manter a compatibilidade nisso.

Podemos criar os seguintes construtores para tais diferentes tokens:

@<Metafont: Funções Estáticas@>+=
static struct token *new_token(int type, float value, char *name){
    struct token *ret;
    ret = (struct token *) _iWalloc(sizeof(struct token));
    if(ret == NULL){
        fprintf(stderr, "ERROR (0): Not enough memory to parse METAFONT "
                "source. Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.\n");
        return NULL;
    }
    ret -> type = type;
    ret -> value = value;
    ret -> name = name;
    ret -> prev = ret -> next = NULL;
    return ret;
}
#define new_token_number(a) new_token(NUMBER, a, NULL)
#define new_token_string(a) new_token(STRING, 0.0, a)
#define new_token_symbol(a) new_token(SYMBOL, 0.0, a)
@

Na prática estaremos com muita frequência formando listas encadeadas
de tokens à medida que formos interpretando eles de um código-fonte ou
caso queiramos armazenar o significado de uma macro. Para ajudar com
isso, usaremos as funções para ligar um token no outro:

@<Metafont: Funções Estáticas@>+=
// Coloca sequência de tokens 'after' após primeiro token de 'before'
static void append_token(struct token *before, struct token *after){
    if(before -> next != NULL){
        before -> next -> prev = after;
        after -> next = before -> next;
    }
    before -> next = after;
    after -> prev = before;
}
// Coloca sequência de tokens 'after' após a sequência de tokens 'before'
static void concat_token(struct token *before, struct token *after){
    while(before -> next != NULL)
        before = before -> next;
    before -> next = after;
    after -> prev = before;
}
@

Vamos também ter que classificar caracteres de acordo com as famílias
que formam um mesmo identificador. A seguinte função retorna um número
distinto para cada família de caracteres, ou -1 se for uma família
inválida.

@<Metafont: Funções Estáticas@>+=
static int character_family(char c){
    char *families = "ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz\n"
        "<=>:|\n"
        "`'\n"
        "+-\n"
        "/*\\\n"
        "!?\n"
        "#&@@$\n"
        "[\n"
        "]\n"
        "{}\n"
        ".\n"
        "^~\n"
        ",\n"
        ";\n"
        "(\n"
        ")\n";
    char *p;
    int number = 0;
    for(p = families; *p != '\0'; p ++){
        if(*p == '\n')
            number ++;
        else if(*p == c){
            return number;
        }

    }
    return -1;
}
@

E agora precisamos de uma função que dada uma string previsa retornar
o próximo token lido dela ou NULL se não houverem mais tokens. Além
disso, é importante retornar uma nova posição na string que foi lida à
partir da qual poderemos querer ler mais tokens. Também irá receber a
linha inicial, um ponteiro para a nova linha após a execução e um nome
de arquivo de onde viria o código. Essas coisas são úteis para
mensagens de erro. No caso, a função que fará isso será a seguinte
implementação de autômato finito:

@<Metafont: Funções Estáticas@>+=
static struct token *next_token(char *source, char **next_position,
                                int line, int *next_line, char *filename){
    struct token *ret;
    char *position = source, *begin;
    char *buffer;
    while(*position != '\0'){
        if(*position == '\n'){
            position ++;
            line ++;
            continue;
        }
        else if(*position == ' ' ||
                (*position == '.' && (*(position + 1)) != '.' &&
                 !isdigit(*(position + 1)))){
            // Regra 01: Caractere descartável
            position ++;
            continue;
        }
        else if(*position == '%'){
            // Regra 02: Comentário
            while(*position != '\n' && *position != '\0')
                position ++;
        }
        else if(isdigit(*position) || (*position == '.' &&
                                       isdigit(*(position + 1)))){
            // Regra 03: Token numérico
            int number_of_points = 0;
            begin = position;
            do{
                if(*position == '.'){
                    if(number_of_points == 1 ||
                       !isdigit(*(position + 1))){
                        break;
                    }
                    else
                        number_of_points ++;
                }
                position ++;
            }while(isdigit(*position) || *position == '.');
            buffer = (char *) _iWalloc(position + 1 - begin);
            if(buffer == NULL)
                goto error_no_memory;
            strncpy(buffer, begin, position - begin);
            buffer[position - begin] = '\0';
            ret = new_token_number(atof(buffer));
            *next_position = position;
            *next_line = line;
            return ret;
        }
        else if(*position == '"'){
            // Regra 04: String
            position ++;
            begin = position;
            while(*position != '"'){
                if(*position == '\n'){
                    fprintf(stderr, "ERROR (%s:%d): Incomplete string.\n",
                            filename, line);
                    line ++;
                    break;
                }
                position ++;
            }
            buffer = (char *) _iWalloc(position - begin + 1);
            if(buffer == NULL)
                goto error_no_memory;
            strncpy(buffer, begin, position - begin);
            buffer[position - begin] = '\0';
            ret = new_token_string(buffer);
            *next_position = position + 1;
            *next_line = line;
            return ret;
        }
        // Regra 05: Tokens caracteres
        else if(*position == '('){
            buffer = (char *) _iWalloc(2);
            if(buffer == NULL)
                goto error_no_memory;
            buffer[0] = '(';
            buffer[1] = '\0';
            *next_position = position + 1;
            *next_line = line;
            return new_token_symbol(buffer);
        }
        else if(*position == ')'){
            buffer = (char *) _iWalloc(2);
            if(buffer == NULL)
                goto error_no_memory;
            buffer[0] = ')';
            buffer[1] = '\0';
            *next_position = position + 1;
            *next_line = line;
            return new_token_symbol(buffer);
        }
        else if(*position == ','){
            buffer = (char *) _iWalloc(2);
            if(buffer == NULL)
                goto error_no_memory;
            buffer[0] = ',';
            buffer[1] = '\0';
            *next_position = position + 1;
            *next_line = line;
            return new_token_symbol(buffer);
        }
        else if(*position == ';'){
            buffer = (char *) _iWalloc(2);
            if(buffer == NULL)
                goto error_no_memory;
            buffer[0] = ';';
            buffer[1] = '\0';
            *next_position = position + 1;
            *next_line = line;
            return new_token_symbol(buffer);
        }
        else{
            // Regra 06: Tokens identificadores
            int family_number = character_family(*position);
            int current_family;
            if(family_number == -1){
                fprintf(stderr,
                        "ERROR (%s:%d): Invalid character(%c).\n",
                        filename, line, *position);
                position ++;
                continue;
            }
            begin = position;
            do{
                position ++;
                current_family = character_family(*position);
            }while(current_family == family_number);
            buffer = (char *) _iWalloc(position - begin + 1);
            if(buffer == NULL)
                goto error_no_memory;
            strncpy(buffer, begin, position - begin);
            buffer[position - begin] = '\0';
            ret = new_token_symbol(buffer);
            *next_position = position;
            *next_line = line;
            return ret;
        }
    }
    return NULL;
error_no_memory:
    fprintf(stderr, "ERROR (0): Not enough memory to parse METAFONT "
            "source. Please, increase the value of W_INTERNAL_MEMORY "
            "at conf/conf.h.\n");
    return NULL;
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
interessante se houvesse uma que rotorna listas de tokens que formam
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
interpretado. Também armazenamos uma estrutura-pai. Isso nos permitirá
definir mais tarde escopo para algumas de nossas declarações e
interpretações:

@<Metafont: Variáveis Estáticas@>+=
struct metafont{
  struct token *pending_tokens;
  struct metafont *parent;
  @<METAFONT: Estrutura METAFONT@>
};
@

Essa estrutura será inicializada por:

@<Metafont: Funções Estáticas@>+=
struct metafont *new_metafont(struct metafont *parent){
    struct metafont *structure = (struct metafont *) Walloc(sizeof(struct metafont));
    if(structure == NULL)
        goto end_of_memory_error;
    structure -> pending_tokens = NULL;
    structure -> parent = parent;
    @<METAFONT: Inicializa estrutura METAFONT@>
    return structure;
end_of_memory_error:
    fprintf(stderr, "ERROR (0): Not enough memory to parse METAFONT "
            "source. Please, increase the value of W_MEMORY "
            "at conf/conf.h.\n");
    return NULL;
}
@

Agora vamos nos concentrar apenas na função que ficará responsável por
obter o próximo token (seja um já lido, mas ainda não interpretado, ou
um que ainda precisa ser lido de uma string) e expandi-lo:

@<Metafont: Funções Estáticas@>+=
@<Metafont: Função Estática expand_token@>
static struct token *get_first_token(struct metafont *mf, char *source,
                                char **next_position,
                                int line, int *next_line, char *filename){
    struct token *first_token = NULL;
    // Obtemos o primeiro token
    if(mf -> pending_tokens){
        first_token = mf -> pending_tokens;
        first_token -> next -> prev = NULL;
        mf -> pending_tokens = first_token -> next;
        first_token -> next = NULL;
    }
    else{
         first_token = next_token(source, &source, line, &line, filename);
    }
    while(expand_token(&first_token, source, &source));
    *next_line = line;
    *next_position = source;
    return first_token;
}
@

Por fim, podemos fazer a nossa função que separa uma declaração:

@<Metafont: Funções Estáticas@>+=
static struct token *get_statement(struct metafont *mf, char *source,
                                   char **next_position,
                                   int line, int *next_line, char *filename){
    struct token *first_token, *current_token;
    first_token = get_first_token(mf, source, &source, line, &line, filename);
    current_token = first_token;
    // Se o primeiro token é um NULL, 'end' ou 'dump', terminamos de ler:
    if(current_token == NULL ||
       (current_token -> type == SYMBOL &&
       (!strcmp(current_token -> name, "end") ||
        !strcmp(current_token -> name, "dump")))){
        while(*(*next_position) != '\0')
            (*next_position) ++;
         return NULL;
    }
    // Se não, vamos expandindo cada token até acharmos o fim da declaração
    while(1){
        if(current_token -> type == SYMBOL &&
           !strcmp(current_token -> name, ";"))
            break;
        // Se não saímos do loop, temos que ir para o próximo token
        if(current_token -> next == NULL)
            current_token -> next = next_token(source, &source, line, &line,
                                               filename);
        if(current_token -> next == NULL)
            goto source_incomplete_or_with_error;
        current_token -> next -> prev = current_token;
        current_token = current_token -> next;
        while(expand_token(&current_token, source, &source));
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
    *next_line = line;
    *next_position = source;
    return first_token;
source_incomplete_or_with_error:
    fprintf(stderr, "ERROR: %s:%d: Source with error or incomplete, aborting.\n",
            filename, line);
    return NULL;
}
@

Fazendo isso, por fim podemos terminar a estrutura básica da leitura e
interpretação de um código METAFONT na forma de uma string por meio da
função abaixo que fica obtendo declarações e as executa:

@<Metafont: Funções Estáticas@>+=
@<Metafont: Função run_single_statement@>
void run_statements(struct metafont *mf, char *source, char *filename){
    struct token *statement;
    int line = 1;
    bool end_execution = false, first_loop = true;
    while(!end_execution){
        if(mf -> pending_tokens == NULL)
            _iWbreakpoint();
        if(first_loop){
            @<Metafont: Antes de Obter a Primeira Declaração@>
            first_loop = false;
        }
        statement = get_statement(mf, source, &source, line, &line, filename);
        if(statement == NULL)
            end_execution = true;
        else
            run_single_statement(mf, statement, source, &source, line, &line,
                                 filename);
        if(mf -> pending_tokens == NULL)
            _iWtrash();
    }
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
  void run_single_statement(struct metafont *mf, struct token *statement,
                            char *source, char **next_source,
                            int line, int *next_line, char *filename){
    if(statement -> type == SYMBOL && !strcmp(statement -> name, ";"))
        return;
    @<Metafont: Executa Declaração@>
    fprintf(stderr, "ERROR: %s:%d: Ignoring isolated expression (%s).\n",
            filename, line, (statement == NULL)?("NULL"):(statement -> name));
}
@


Outra coisa que ainda não definimos é a função que expande um único
token para um ou mais tokens. Essa é a implementação das macros de
METAFONT, as quais serão definidas logo em seguida.

@<Metafont: Função Estática expand_token@>=
bool expand_token(struct token **first_token, char *source, char **next_char){
     // todo
     return false;
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

A qual deverá ser inicializada como vazia para qualquer inicialização
de estrutura METAFONT:

@<METAFONT: Inicializa estrutura METAFONT@>=
structure -> internal_quantities = _new_trie();
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
    _insert_trie(T, DOUBLE, "tracingtitles", 0.0);
    _insert_trie(T, DOUBLE, "tracingequations", 0.0);
    _insert_trie(T, DOUBLE, "tracingcapsules", 0.0);
    _insert_trie(T, DOUBLE, "tracingchoices", 0.0);
    _insert_trie(T, DOUBLE, "tracingspecs", 0.0);
    _insert_trie(T, DOUBLE, "tracingpens", 0.0);
    _insert_trie(T, DOUBLE, "tracingcommands", 0.0);
    _insert_trie(T, DOUBLE, "tracingrestores", 0.0);
    _insert_trie(T, DOUBLE, "tracingmacros", 0.0);
    _insert_trie(T, DOUBLE, "tracingedges", 0.0);
    _insert_trie(T, DOUBLE, "tracingoutput", 0.0);
    _insert_trie(T, DOUBLE, "tracingonline", 0.0);
    _insert_trie(T, DOUBLE, "tracingstats", 0.0);
    _insert_trie(T, DOUBLE, "pausing", 0.0);
    _insert_trie(T, DOUBLE, "showstopping", 0.0);
    _insert_trie(T, DOUBLE, "proofing", 0.0);
    _insert_trie(T, DOUBLE, "turningcheck", 0.0);
    _insert_trie(T, DOUBLE, "warningcheck", 0.0);
    _insert_trie(T, DOUBLE, "smoothing", 0.0);
    _insert_trie(T, DOUBLE, "autorounding", 0.0);
    _insert_trie(T, DOUBLE, "glanularity", 0.0);
    _insert_trie(T, DOUBLE, "glanularity", 0.0);
    _insert_trie(T, DOUBLE, "fillin", 0.0);
    _insert_trie(T, DOUBLE, "year", (double) year);
    _insert_trie(T, DOUBLE, "month", (double) month);
    _insert_trie(T, DOUBLE, "day", (double) day);
    _insert_trie(T, DOUBLE, "time", (double) time_in_minutes);
    _insert_trie(T, DOUBLE, "charcode", 0.0);
    _insert_trie(T, DOUBLE, "charext", 0.0);
    _insert_trie(T, DOUBLE, "charwd", 0.0);
    _insert_trie(T, DOUBLE, "charht", 0.0);
    _insert_trie(T, DOUBLE, "chardp", 0.0);
    _insert_trie(T, DOUBLE, "charic", 0.0);
    _insert_trie(T, DOUBLE, "chardx", 0.0);
    _insert_trie(T, DOUBLE, "chardy", 0.0);
    _insert_trie(T, DOUBLE, "designsize", 0.0);
    _insert_trie(T, DOUBLE, "hppp", 0.0);
    _insert_trie(T, DOUBLE, "vppp", 0.0);
    _insert_trie(T, DOUBLE, "xoffset", 0.0);
    _insert_trie(T, DOUBLE, "yoffset", 0.0);
    _insert_trie(T, DOUBLE, "boundarychar", -1.0);
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
             |-> <Declaração>
             |-> <Definição>
             |-> <Composta>
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

@<Metafont: Funções Primitivas Estáticas@>=
static struct token *symbolic_token_list(struct token **token,
                                         char *filename, int line){
    struct token *first_token = *token, *current_token;
    current_token = first_token;
    while(1){
        // Se o token atual não for simbólico, isso é um erro.
        if(current_token == NULL || current_token -> type != SYMBOL){
            fprintf(stderr, "ERROR: %s:%d: Missing symbolic token.\n",
                    filename, line);
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
    struct token *list = symbolic_token_list(&current_token, filename, line);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(current_token == NULL || current_token -> type != SYMBOL ||
       strcmp(current_token -> name, ";")){
        fprintf(stderr, "ERROR: %s:%d: Extra token at newinternal command (%s).\n",
                filename, line,
                (current_token == NULL)?("NULL"):(current_token -> name));
        return;
    }
    // Executa o comando
    while(list != NULL){
        _insert_trie(mf -> internal_quantities, DOUBLE, list -> name, 0.0);
        list = list -> next;
    }
    return;
}
@


% Comandos inner e outer dependem de grupo

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
        fprintf(stderr, "ERROR: %s:%d: Missing symbolic token.\n",
                filename, line);
        return;
    }
    // Se aconteceu do token definido como everyjob ser um ';', pegamos mais um:
    if(!strcmp(statement -> next -> name, ";")){
        statement -> next -> next = get_statement(mf, source, &source,
                                                  line, &line, filename);
        if(statement -> next -> next != NULL)
            statement -> next -> next -> prev = statement -> next;
        *next_line = line;
        *next_source = source;
    }
    // E em seguida deve haver um ponto-e-vírgula:
    if(statement -> next -> next == NULL ||
       statement -> next -> next -> type != SYMBOL ||
       strcmp(statement -> next -> next -> name, ";")){
        fprintf(stderr, "ERROR: %s:%d: Extra tokens found (%s).\n",
                filename, line,
                (statement -> next -> next == NULL)?("NULL"):
                (statement -> next -> next -> name));
        return;
    }
    // Se não ocorreu erro, armazena o nome do token:
    if(mf -> everyjob_token_name == NULL ||
       strlen(mf -> everyjob_token_name) < strlen(statement -> next -> name))
        mf -> everyjob_token_name = (char *)
            Walloc(strlen(statement -> next -> name) + 1);
    strcpy(mf -> everyjob_token_name, statement -> next -> name);
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
  

Teste temporário do analizador léxico:

@<Metafont: Declarações@>+=
void _metafont_test(char *);
@

@<Metafont: Definições@>+=
void _metafont_test(char *teste){
    struct metafont *M = new_metafont(NULL);
    run_statements(M, teste, "teste.mf");
}
@
