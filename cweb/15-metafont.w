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
    if(after == NULL)
        return;
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
         @<Metafont: Chegamos ao Fim do Código-Fonte@>
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
                current_token -> next = next_token(source, &source, line, &line,
                                                   filename);
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
    @<Metafont: Imediatamente após gerarmos uma declaração completa@>
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
    bool end_execution = false, first_loop = (mf -> parent == NULL);
    while(!end_execution){
        if(mf -> pending_tokens == NULL)
            _iWbreakpoint();
        if(first_loop){
            @<Metafont: Antes de Obter a Primeira Declaração@>
            first_loop = false;
        }
        @<METAFONT: Imediatamente antes de ler próxima declaração@>
        statement = get_statement(mf, source, &source, line, &line, filename);
        if(statement == NULL)
            end_execution = true;
        else
            run_single_statement(&mf, statement, source, &source, line, &line,
                                 filename);
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
void run_single_statement(struct metafont **mf, struct token *statement,
                            char *source, char **next_source,
                            int line, int *next_line, char *filename){
    if(statement -> type == SYMBOL && !strcmp(statement -> name, ";"))
        return;
    @<Metafont: Executa Declaração@>
    fprintf(stderr, "ERROR: %s:%d: Ignoring isolated expression (%s).\n",
            filename, line, (statement == NULL)?("NULL"):(statement -> name));
    return;
clean_exit:
    *next_source = source;
    *next_line = line;
    return;
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
        _insert_trie((*mf) -> internal_quantities, DOUBLE, list -> name, 0.0);
        list = list -> next;
    }
    goto clean_exit;
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
        statement -> next -> next = get_statement(*mf, source, &source,
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
        fprintf(stderr, "ERROR: %s:%d: Extra tokens found after everyjob (%s).\n",
                filename, line,
                (statement -> next -> next == NULL)?("NULL"):
                (statement -> next -> next -> name));
        return;
    }
    // Se não ocorreu erro, armazena o nome do token:
    if((*mf) -> everyjob_token_name == NULL ||
       strlen((*mf) -> everyjob_token_name) < strlen(statement -> next -> name))
        (*mf) -> everyjob_token_name = (char *)
            Walloc(strlen(statement -> next -> name) + 1);
    strcpy((*mf) -> everyjob_token_name, statement -> next -> name);
    goto clean_exit;
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
        fprintf(stderr, "ERROR: %s:%d: Extra tokens found after %s (%s).\n",
                filename, line, statement -> name,
                (statement -> next  == NULL)?("NULL"):
                (statement -> next -> name));
        return;
    }
    goto clean_exit;
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
    fprintf(stderr, "ERROR: %s:%d: A group begun and never ended.\n",
            filename, line);
}
@

Vamos agora tratar o caso de encontrarmos um \monoespaco{begingroup}
no começo de uma declaração. Além de criar uma nova estrutura METAFONT
filha, passamos para ela os tokens pendentes que antes estavam em seu
pai.

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "begingroup")){
    *mf = new_metafont(*mf);
    statement = statement -> next;
    statement -> prev = NULL;
    (*mf) -> pending_tokens = statement;
    if(statement != NULL)
        concat_token((*mf) -> pending_tokens,
                     (*mf) -> parent -> pending_tokens);
    else
        (*mf) -> pending_tokens = (*mf) -> parent -> pending_tokens;
    (*mf) -> parent -> pending_tokens = NULL;
    goto clean_exit;
}
@

Já tratar o comando \monoespaco{endgroup} é mais complicado, pois ele
aparece tipicamente na penúltima posição, podendo aparecer na última
caso o código esteja incorreto por estar incompleto. Sendo assim,
vamos criar uma forma da fuinção que monta uma nova declaração avisar
o nosso interpretador caso ela leia um \monoespaco{endgroup} na
penúltima ou última posição:

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
    if(mf -> parent == NULL){
        fprintf(stderr,
                "ERROR: %s:%d: Extra 'endgroup' while not in 'begingroup'.\n",
                filename, line);
    }
    else{
        //p = mf;
        mf = mf -> parent;
        //Wfree(p);
    }
}
@

Só temos que tomar cuidado que se nós terminamos de interpretar um
código, mas não terminamos todos os grupos, temos o trabalho de limpar
a nossa memória antes de encerrar:

@<Metafont: Após terminar de interpretar um código@>=
while(mf -> parent != NULL){
    //struct metafont *p = mf;
    mf = mf -> parent;
    //Wfree(p);
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
structure -> variable_types = _new_trie();
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
        structure -> vars[i] = _new_trie();
}
@

Tendo definido e declarado todas essas coisas, enfim podemos definir o
nosso mais novo comando:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "save")){
    struct token *current_token = statement -> next;
    struct token *list = symbolic_token_list(&current_token, filename, line);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(current_token == NULL || current_token -> type != SYMBOL ||
       strcmp(current_token -> name, ";")){
        fprintf(stderr, "ERROR: %s:%d: Extra token at save command (%s).\n",
                filename, line,
                (current_token == NULL)?("NULL"):(current_token -> name));
        return;
    }
    // Executa o comando
    while(list != NULL){
        int current_type;
        bool already_declared = _search_trie((*mf) -> variable_types, INT,
                                             list -> name, &current_type);
        if(already_declared && current_type != NOT_DECLARED)
            _remove_trie((*mf) -> vars[current_type], list -> name);
        _insert_trie((*mf) -> variable_types, INT, list -> name, NOT_DECLARED);
        list = list -> next;
    }
    goto clean_exit;
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
structure -> delimiters = _new_trie();
@

Fora isso, o comando é bastante
simples:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL && !strcmp(statement -> name, "delimiters")){
    char *end_delimiter;
    struct metafont *scope = (*mf);
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        fprintf(stderr, "ERROR: %s:%d: Missing symbolic token.\n",
                filename, line);
        return;
    }
    while(scope -> parent != NULL){
        void *result;
        if(_search_trie(scope -> variable_types, VOID_P,
                        statement -> name, &result))
            break;
        scope = scope -> parent;
    }
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL){
        fprintf(stderr, "ERROR: %s:%d: Missing symbolic token.\n",
                filename, line);
        return;
    }
    end_delimiter = (char *) Walloc(strlen(statement -> name) + 1);
    if(end_delimiter == NULL){
        fprintf(stderr, "ERROR: Not enough memory to parse METAFONT. "
                "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n");
        return;
    }
    strcpy(end_delimiter, statement -> name);
    _insert_trie(scope -> delimiters, VOID_P, statement -> prev -> name,
                 (void *) end_delimiter);
    statement = statement -> next;
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        fprintf(stderr, "ERROR: %s:%d: ignoring extra tokens.\n",
                filename, line);
        return;
    }
    goto clean_exit;
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
structure -> outer_tokens = _new_trie();
@

Depois disso, podemos definir os comandos de proteção:

@<Metafont: Executa Declaração@>=
if(statement -> type == SYMBOL &&
   (!strcmp(statement -> name, "inner") ||
    !strcmp(statement -> name, "outer"))){
    bool inner_command = (statement -> name[0] == 'i');
    statement = statement -> next;
    struct token *list = symbolic_token_list(&statement, filename, line);
    // Se tem algo diferente de ';' após a lista, isso é um erro:
    if(statement == NULL || statement -> type != SYMBOL ||
       strcmp(statement -> name, ";")){
        fprintf(stderr, "ERROR: %s:%d: Extra token at save command (%s).\n",
                filename, line,
                (statement == NULL)?("NULL"):(statement -> name));
        return;
    }
    // Executa o comando
    while(list != NULL){
        struct metafont *scope = (*mf);
        while(scope -> parent != NULL){
            int dummy_result;
            if(_search_trie(scope -> variable_types, INT,
                            list -> name, &dummy_result))
                break;
            scope = scope -> parent;
        }
        if(inner_command)
            _remove_trie((*mf) -> outer_tokens, list -> name);
        else
            _insert_trie((*mf) -> outer_tokens, INT, list -> name, 0);
        list = list -> next;
    }
    goto clean_exit;
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
structure -> def = _new_trie();
structure -> vardef = _new_trie();
structure -> primarydef = _new_trie();
structure -> secondarydef = _new_trie();
structure -> tertiarydef = _new_trie();
@

E agora sim a seguinte função checa se um token recebido é uma tag:

@<Metafont: Funções Primitivas Estáticas@>=
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

@<Metafont: Declarações@>+=
void _initialize_metafont(void);
@

@<API Weaver: Inicialização@>+=
{
    Wbreakpoint();
    _initialize_metafont();
}
@

No encerramento vamos usar um \monoespaco{Wtrash} para limparmos a
memória inicializada pelo METAFONT na ordem certa:

@<API Weaver: METAFONT: Encerramento@>+=
{
    Wtrash();
}
@

@<Metafont: Definições@>+=
void _initialize_metafont(void){
    primitive_sparks = _new_trie();
    _insert_trie(primitive_sparks, INT, "end", 0);
    _insert_trie(primitive_sparks, INT, "dump", 0);
    _insert_trie(primitive_sparks, INT, ";", 0);
    _insert_trie(primitive_sparks, INT, ",", 0);
    _insert_trie(primitive_sparks, INT, "newinternal", 0);
    _insert_trie(primitive_sparks, INT, "everyjob", 0);
    _insert_trie(primitive_sparks, INT, "batchmode", 0);
    _insert_trie(primitive_sparks, INT, "nonstopmode", 0);
    _insert_trie(primitive_sparks, INT, "scrollmode", 0);
    _insert_trie(primitive_sparks, INT, "errorstopmode", 0);
    _insert_trie(primitive_sparks, INT, "begingroup", 0);
    _insert_trie(primitive_sparks, INT, "endgroup", 0);
    _insert_trie(primitive_sparks, INT, "save", 0);
    _insert_trie(primitive_sparks, INT, "delimiters", 0);
    _insert_trie(primitive_sparks, INT, "outer", 0);
    _insert_trie(primitive_sparks, INT, "inner", 0);
    _insert_trie(primitive_sparks, INT, "[", 0);
    _insert_trie(primitive_sparks, INT, "]", 0);
    _insert_trie(primitive_sparks, INT, "boolean", 0);
    _insert_trie(primitive_sparks, INT, "string", 0);
    _insert_trie(primitive_sparks, INT, "path", 0);
    _insert_trie(primitive_sparks, INT, "pen", 0);
    _insert_trie(primitive_sparks, INT, "picture", 0);
    _insert_trie(primitive_sparks, INT, "transform", 0);
    _insert_trie(primitive_sparks, INT, "pair", 0);
    _insert_trie(primitive_sparks, INT, "numeric", 0);
    //@<Metafont: Declara Nova Spark@>
}
@

A definição acima conta com todas as sparks que já definimos em nossa
gramática. Outras ainda serão inseridas.

De qualquer forma, com isso já podemos escrever o código de declaração
de variáveis:

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
    bool suffix = false;
    struct token *first_token, *last_token;
    int name_size = 0;
    int type;
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
    first_token = statement -> next;
    while(1){
        // O primeiro token apenas deve ser simbólico
        if(!suffix && (statement == NULL || statement -> type != SYMBOL)){
            fprintf(stderr, "ERROR: %s:%d: Missing symbolic token.\n",
                    filename, line);
            return;
        }
        else if(suffix){
            // Os demais tokens precisam ser '[', ']' ou tags
            if(statement == NULL || statement -> type != SYMBOL ||
               (!is_tag(*mf, statement) && (strcmp(statement -> name, "[") ||
                                            strcmp(statement -> name, "]")))){
                fprintf(stderr, "ERROR: %s:%d: Illegal suffix.\n", filename,
                        line);
                return;
            }
        }
        if(!suffix){
            first_token = statement;
            suffix = true;
            // O primeiro token pode ser até mesmo um ';'. Tratar o caso:
            if(!strcmp(statement -> name, ";") && statement -> next == NULL){
                struct token *tok;
                statement -> next = get_first_token(*mf, source, &source,
                                                    line, &line, filename);
                if(statement -> next != NULL)
                    statement -> next -> prev = statement;
                tok = statement -> next;
                while(tok != NULL && strcmp(tok -> name, ";")){
                    tok -> next = get_first_token(*mf, source, &source,
                                                  line, &line, filename);
                    if(tok -> next != NULL)
                        tok -> next -> prev = tok;
                    tok = tok -> next;
                }
            }
        }
        name_size += strlen(statement -> name) + 1;
        // Se o próximo token é ',' ou ';', encerramos a declaração atual:
        if(statement -> next != NULL &&
           statement -> next -> type == SYMBOL &&
           (!strcmp(statement -> next -> name, ",") ||
            !strcmp(statement -> next -> name, ";"))){
            int current_type;
            bool already_declared = false;
            struct metafont *scope = *mf;
            char *buffer = (char *) Walloc(name_size);
            if(buffer == NULL){
                fprintf(stderr, "ERROR: Not enough memory. Please increase the "
                                "value of W_MAX_MEMORY at conf/conf.h.\n");
                exit(1);
            }
            last_token = statement;
            buffer[0] = '\0';
            // Copia o nome da variável
            statement = first_token -> prev;
            do{
                statement = statement -> next;
                strcat(buffer, statement -> name);
                strcat(buffer, " ");
            } while(statement != last_token);
            buffer[name_size - 1] = '\0';
            while(scope -> parent != NULL){
                already_declared = _search_trie(scope -> variable_types, INT,
                                                buffer, &current_type);
                if(already_declared)
                    break;
                scope = scope -> parent;
            }
            // Se a variável já havia sido declarada, seus valores devem ser limpos
            if(scope -> parent == NULL)
                already_declared = _search_trie(scope -> variable_types, INT,
                                                 buffer, &current_type);
            if(already_declared && current_type != NOT_DECLARED)
                _remove_trie(scope -> vars[current_type], buffer);
            _insert_trie(scope -> variable_types, INT, buffer, type);
            // Se o próximo caractere for um ',', vamos pular ele,
            // se for um ';', encerramos
            if(statement -> next != NULL){
                if(statement -> next -> name[0] == ','){
                    statement = statement -> next;
                    name_size = 0;
                    suffix = false;
                }
                else
                    break;
            }
        }
        statement = statement -> next;
    }
    goto clean_exit;
}
@


@<Metafont: Declarações@>+=
void _metafont_test(char *);
@

@<Metafont: Definições@>+=
void _metafont_test(char *teste){
    struct metafont *M = new_metafont(NULL);
    run_statements(M, teste, "teste.mf");
}
@

