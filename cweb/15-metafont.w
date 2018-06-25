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
            ret = new_token_identifier(buffer);
            *next_position = position;
            *next_line = line;
            return ret;
        }
    }
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
é armazenado pelo nosso interpretador. Ali dentro podemos armazxenar
qualquer token já lido, e que está pendente para ser interpretado:

@<Metafont: Variáveis Estáticas@>+=
struct metafont{
  struct token *pending_tokens;
  @<METAFONT: Estrutura METAFONT@>
};
@

Essa estrutura será inicializada por:

@<Metafont: Funções Estáticas@>+=
struct metafont *new_metafont(void){
    struct metafont *structure = (struct metafont *) Walloc(sizeof(struct metafont));
    if(structure == NULL)
        goto end_of_memory_error;
    structure -> pending_tokens = NULL;
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
    if(mf -> pending_token){
        first_token = mf -> pending_token;
        first_token -> next -> prev = NULL;
        mv -> pending_token = first_token -> next;
        first_token -> next = NULL;
    }
    else{
        first_token = next_token(source, &source, line, &line, filename);
    }
    while(!expand_token(&first_token, source, &source));
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
    // Se o primeiro token é um 'end' ou 'dump', terminamos de ler:
    if(current_token -> type == SYMBOL &&
       (!strcmp(current_token -> name, "end") ||
        !strcmp(current_token -> name, "dump"))){
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
            current_token = next_token(source, &source, line, &line, filename);
        if(current_token -> next == NULL)
            goto source_incomplete_or_with_error;
        while(!expand_token(&current_token, source, &source));
    }
    // Obtida declaração no loop acima, finalizando
    if(current_token -> next != NULL){
        current_token -> next -> prev = NULL;
        if(mf -> pending_tokens == NULL)
            mf -> pending_tokens = current_token -> next;
        else
            concat_tokens(mf -> pending_tokens, current_token -> next);
    }
    current_token -> next = NULL;
    return first_token;
source_incomplete_or_with_error:
    fprintf(stderr, "ERROR: %s:%d: Source with error or incomplete, aborting.\n",
            filename, line);
    return NULL;
}
@


@*1 Declaração de Variáveis.

Vamos declarar agoira uma estrutura que irá armazenar tudo o que o
METAFONT precisa para funcionar. Listas de variáveis, definições
internas, etc:


Ela será criada por:


Esta será a estrutura que nosso analisador sintático irá receber e
modificar ao longo de sua execução.

Todo programa METAFONT tem a forma:

\alinhaverbatim
<Programa> --> <Lista de Declarações> end
           |-> <Lista de Declarações> dump
\alinhanormal

Onde end e dump são tokens de identificadores. No METAFONT criado por
Knuth, o segundo é usado para gerar um arquivo com macros definidas
para que sejam usadas de maneira mais rápida por futuras
execuções. Para nós essa distinção não faz sentido. Então as usaremos
como sinônimos.

Já a <Lista de Declarações> tem a forma:

\alinhaverbatim
<Lista de Declarações> --> <Vazio>
                       |-> <Declaração> ; <Lista de Declarações>
\alinhanormal

Com isso já podemos criar a base de nosso analisador sintático. Já
temos a noção de que todo programa é uma lista de declarações
potencialmente vazia, separada pelo token de caractere único de
ponto-e-vírgula e sempre terminada por \monoespaco{end}
ou \monoespaco{dump}:

@<Metafont: Funções Estáticas@>+=
void parser(struct metafont *M, char *source, char *filename, int line,
            int *next_line){
    bool end_of_file = false;
    char *c = source;
    struct token *list_of_tokens, *last_token, *new_token;
    while(!end_of_file){
        bool have_statement = false;
        new_token = next_token(c, &c, line, &line, filename);
        list_of_tokens = new_token;
        last_token = list_of_tokens;
        @<METAFONT: Checa caso de Declaração Vazia@>
        while(!have_statement){
            new_token = next_token(c, &c, line, &line, filename);
            if(new_token == NULL){
                *next_line = line;
                return;
            }
            append_token(last_token, new_token);
            last_token = new_token;
            @<METAFONT: Interpreta Tokens@>
        }
        list_of_tokens = new_token = last_token = NULL;
    }
}
@

Basicamente primeiro começamos lendo o primeiro token da nossa
lista. Mas nossa lista de tokens pode ser vazia ou podemos ter uma
declaração com um só token. São os casos de encontrarmos apenas um
ponto-e-vírgula, pois a seguinte declaração é válida:

\alinhaverbatim
<Declaração> --> <Vazio>
\alinhanormal

Então teremos que checar se logo o primeiro token que encontramos é um
simples ponto-e-vírgula. Ou se chegamos ao fim encontrando
um \monoespaco{end} ou um \monoespaco{dump}. No primeiro caso, nós
apenas terminamos de ler a declaração atual. Nos dois últimos casos,
além disso, nós terminamos de interpretar nosso código METAFONT:

@<METAFONT: Checa caso de Declaração Vazia@>+=
{
    if(list_of_tokens == NULL){
        // Sem mais tokens
        *next_line = line;
        return;
    }
    else if(list_of_tokens -> type == SCOLON){
        have_statement = true;
    }
    else if(list_of_tokens -> type == IDENTI){
        if(!strcmp("end", list_of_tokens -> name) ||
           !strcmp("dump", list_of_tokens -> name)){
            have_statement = true;
            end_of_file = true;
        }
    }
}
@

Agora vamos à interpretação de declarações em si. Toda declaração,
além de poder ser vazia, como já visto, pode ter a forma:

\alinhaverbatim
<Declaração> --> <Título>
             |-> <Equação>
             |-> <Atribuição>
             |-> <Declaração>
             |-> <Definição>
             |-> <Declaração Composta>
             |-> <Comando>
\alinhanormal

Representamos isso então com:

@<METAFONT: Interpreta Tokens@>+=
  @<METAFONT: Declaração@>
  //@<METAFONT: Titulo@>
  //@<METAFONT: Equação@>
  //@<METAFONT: Atribuição@>
  //@<METAFONT: Definição@>
  //@<METAFONT: Declaração Composta@>
  //@<METAFONT: Comando@>
@

Vamos passar para as declarações. Elas são fáceis de serem
reconhecidas porque podemos reconhecê-las apenas pelo primeiro token
que elas tem. Sua definição é:

\alinhaverbatim
<Declaração> --> <Tipo> <Lista de Declarações>
<Tipo> --> boolean | string | path | pen | picture | transform | pair | numeric
<Lista de Declarações> --> <Variável Declarada>
                       |-> <Lista de Declarações> , <Variável Declarada>
<Variável Declarada> --> <Token Simbólico> <Sufixo Declarado>
<Sufixo Declarado> --> <Vazio>
                   |-> <Sufixo Declarado> <Tag>
                   |-> <Sufixo Declarado> [ ]
<Tag> --> <Tag Externa>
      |-> <Quantidade Interna>
\alinhanormal

Onde uma Tag Externa é qualquer identificador que não está associado à
uma macro ou comando interno (neste caso eles seriam chamados de
``sparks'', não de ``tags''). Ela também pode ser uma quantidade
interna, que basicamente são casos especiais de variáveis que são
embutidas dentro da linguagem METAFONT, mas que não podem conter
sufixos, ao contrário das demais variáveis.

A existência de sufixos decorre do fato de que toda variável METAFONT
pode ser encararada como composta de mais de um token. Assim, pelas
regras do nosso analizador léxico, x1 seria formado por dois tokens:
``x'' e ``1''. Mas seria possível ter umas única variável chamada x1 e
outra chamada de x2, ambas formadas por dois tokens. Isso deve estar
entre uma das primeiras implementações do conceito de ``namespace''.

Como o caractere de ponto é ignorado fora de numerais, podemos também
nos referir à variáveis como \monoespaco{estrutura.tamanho.x}, que
isso também é tratado como uma variável cujo nome tem três tokens. Ou
o ponto poderia ser substituído por um espaço sem trocar o significado.

O uso de ``['' e ``]'' serve para declarar um número infinito de
variáveis com números em seu nome. Se \monoespaco{string escritorio}
declara esta variável como uma string, então \monoespaco{string
escritorio[]nome} declara qualquer variável de três tokens que começa
com \monoespaco{escritorio} e termina com \monoespaco{nome} tendo
qualquer número no meio.

Durante a declaração, nunca podemos escolher como sufixo um
número. Esta é uma restrição semântica. Combinado com a regra
anterior, isso reforça a restrição de METAFONT de que se
\monoespaco{x2} é um tipo de variável, então \monoespaco{x56} deverá
ser do mesmo tipo. Variáveis assim só podem ser declaradas na
forma \monoespaco{x[]}.

Geralmente a declaração serve para avisar METAFONT qual o tipo de uma
variável e é obrigatória para todas as variáveis, exceto as
numéricas. Qualquer variável declarada (e as numéricas
não-declaradas), caso não tenham um valor definido, serão tratadas
como tendo um valor padrão. Se elas já tinham um valor antes (podem já
ter sido declaradas antes), então o valor anterior é esquecido;

Dito isso, começamos então definindo os 8 tipos diferentes que uma
variável METAFONT pode ter:

@<Metafont: Variáveis Estáticas@>+=
// Tipo de variável
#define BOOLEAN   1
//#define STRING    2 //(já definido)
#define PATH      3
#define PEN       4
#define PICTURE   5
#define TRANSFORM 6
#define PAIR      7
#define NUMERIC   8
@

E dentro da estrutura METAFONT iremos armazenar em uma árvore trie
todas as variáveis declaradas e o tipo delas:

@<METAFONT: Estrutura METAFONT@>+=
struct _trie *declarations;
@

A qual será inicializada com um simples:

@<METAFONT: Inicializa estrutura METAFONT@>+=
structure -> declarations = _new_trie();
if(structure -> declarations == NULL)
    goto end_of_memory_error;
@

Quando obtemos os tokens, checamos se estamos diante de uma declaração
apenas checando o primeiro token e nos certificando de ser um dos
nomes de tipos de variáveis:

@<METAFONT: Declaração@>+=
{
    int type = -1;
    if(list_of_tokens -> type == IDENTI){
        if(!strcmp(list_of_tokens -> name, "boolean"))
            type = BOOLEAN;
        else if(!strcmp(list_of_tokens -> name, "string"))
            type = STRING;
        else if(!strcmp(list_of_tokens -> name, "path"))
            type = PATH;
        else if(!strcmp(list_of_tokens -> name, "pen"))
            type = PEN;
        else if(!strcmp(list_of_tokens -> name, "picture"))
            type = PICTURE;
        else if(!strcmp(list_of_tokens -> name, "transform"))
            type = TRANSFORM;
        else if(!strcmp(list_of_tokens -> name, "pair"))
            type = PAIR;
        else if(!strcmp(list_of_tokens -> name, "numeric"))
            type = NUMERIC;
    }
    if(type != -1){
        char buffer[4098];
        buffer[0] = '\0';
        int p = 0;
        while(last_token -> type != SCOLON){
            // O primeiro token deve ser simbólico
            if(buffer[0] == '\0' && last_token -> type != IDENTI &&
               last_token -> type != SCOMMA){
                printf("DEBUG: Foi %d%c\n", last_token -> type, last_token -> type);
                fprintf(stderr,
                        "ERROR (%s:%d): Missing symbolic token.\n",
                        filename, line);
                break;
            }
            // Tokens numéricos não são permitidos
            else if(last_token -> type == NUMERIC){
                fprintf(stderr,
                        "ERROR (%s:%d): Illegal suffix of declared variable.\n",
                        filename, line);
                break;
            }
            // Se não é o primeiro token, mas um sufixo, coloca um espaço:
            if(buffer[0] != '\0'){
                buffer[p % 4098] = ' ';
                p ++;
            }
            // Forma nome da variável em buffer se aplicável
            if(last_token -> name != NULL && last_token -> type != SCOMMA){
                char *n = last_token -> name;
                while(*n != '\0'){
                    buffer[p % 4098] = *n;
                    p ++;
                    n ++;
                }
            }
            new_token = next_token(c, &c, line, &line, filename);
            if(new_token == NULL){
                *next_line = line;
                return;
            }
            last_token = new_token;
            // Em caso de vírgula ou ponto-e-vírgula, salva a variável:
            if(last_token -> type == SCOMMA || last_token -> type == SCOLON){
                buffer[p % 4098] = '\0';
                printf("DEBUG: Salva variável %s, tipo %d\n", buffer, type);
                _insert_trie(M -> declarations, INT, buffer, type);
                buffer[0] = '\0';
                p = 0;
            }
        }
        have_statement = true;
    }
}
@








Teste temporário do analizador léxico:

@<Metafont: Declarações@>+=
void _metafont_test(char *);
@

@<Metafont: Definições@>+=
void _metafont_test(char *teste){
    int line;
    struct metafont *M = new_metafont();
    parser(M, teste, "teste.mf", 1, &line);
}
@
