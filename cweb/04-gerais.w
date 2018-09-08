@* Bibliotecas Auxiliares.

A função deste capítulo é reunir qualquer biblioteca que seja
suficientemente genérica para ser utilizada em mais de um local na
Engine Weaver e também que seja suficientemente simples para conter
não mais do que três funções, além de uma inicialização e
finalização que será chamada automaticamente por Weaver.

@*1 Árvore Trie.

Podemos precisar de uma árvore trie para criar uma consulta para nomes
de variáveis, por exemplo. Em casos nos quais será importante obter
rapidamente algum valor que estamos armazenando. Nosso cabeçalho será:

@(project/src/weaver/trie.h@>=
#ifndef _trie_h_
#define _trie_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Trie: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@

E o arquivo com as funções C:

@(project/src/weaver/trie.c@>=
#include "trie.h"
#include <stdarg.h> // va_start
//@<Trie: Variáveis Estáticas@>
@<Trie: Funções Estáticas@>
@<Trie: Definições@>
@

@<Cabeçalhos Weaver@>+=
#include "trie.h"
@

Não há qualquer inicialização geral aqui. O que precisamos é de
funções para:

1- Gerar nova árvore Trie.
2- Inserir um elemento em uma árvore Trie
3- Consultar uma árvore trie

Nós podemos querer alocar ela de qualquer arena de memória que
tenhamos. Mas não precisamos desalocá-la explicitamente, pois podemos
confiar que usaremos esta função de modo que o coletor de lixo saberá
lidar com ela.

É importante sabermos que tipo de elemento estamos armazenando em
nossa trie. Mas podemos passar essa informação na consulta. O que
iremos armazenar é um \monoespaco{union} com a possibilidade de termos
vários tipos. De qulquer forma, os tipos que seriam importantes de
armazenar são: int, double, e ponteiro para void. É importante
fornecermos uma forma de representar tais tipos:

@<Trie: Declarações@>+=
#define INT    1
#define DOUBLE 2
#define VOID_P 3
@

Dito isso, podemos então definir nossa trie como:

@<Trie: Declarações@>+=
struct _trie{
    char *string;
    bool leaf;
    struct _trie *child[256];
    struct _trie *parent;
    union{
        int integer;
        double real;
        void *generic;
    } value;
};
@

Basicamente cada nó da trie contém uma parte da string que forma seu
nome. As folhas são os nós onde existem valores armazenados. Quando
criamos uma nova trie, ela ainda não contém nenhuma folha, pois não
tem nenhum valor armazenado. Seu único nó não é uma folha, contém a
string vazia e todos os seus filhos são nulos. Como o nó não é uma
folha, seu valor é indeterminado e não será consultado nunca:

@<Trie: Declarações@>+=
struct _trie *_new_trie(void *arena);
@

@<Trie: Definições@>+=
struct _trie *_new_trie(void *arena){
    int i;
    struct _trie *ret;
    ret = (struct _trie *) Walloc_arena(arena, sizeof(struct _trie));
    if(ret == NULL)
        goto no_memory_error;
    ret -> string = (char *) Walloc(1);
    if(ret -> string == NULL)
        goto no_memory_error;
    ret -> string[0] = '\0';
    ret -> leaf = false;
    for(i = 0; i < 256; i ++)
        ret -> child[i] = NULL;
    ret -> parent = NULL;
    return ret;
no_memory_error:
    fprintf(stderr, "ERROR: No memory enough. Please increase the value of "
        "%s at conf/conf.h.\n", (arena == _user_arena)?"W_MAX_MEMORY":
            "W_INTERNAL_MEMORY");
    return NULL;
}
@

A mágica da trie começa quando formos inserir um valor. Primeiro
devemos nos mover pela trie até encontrar o maior prefixo da nossa
string existente nos ramos. Uma vez nele, iremos inserir o
valor. Neste caso, ou iremos inserir um novo ramo ou iremos desmembrar
outro ramo já existente em dois e inserir lá:

@<Trie: Declarações@>+=
  void _insert_trie(struct _trie *tree, void *arena, int type, char *name, ...);
@

@<Trie: Definições@>+=
void _insert_trie(struct _trie *tree, void *arena, int type, char *name, ...){
    va_list arguments;
    va_start(arguments, name);
    struct _trie *current_prefix = tree;
    char *match = name, *p = current_prefix -> string;
    while(*match != '\0'){
        if(*p == '\0'){
            // Ramo atual é um prefixo, ir para próximo
            if(current_prefix -> child[(int) *match] != NULL){
                current_prefix = current_prefix -> child[(int) *match];
                p = current_prefix -> string;
            }
            else{
                // Criando novo nodo, pois o que buscamos não existe
                current_prefix -> child[(int) *match] =
                                 _new_node(arena, match, current_prefix);
                current_prefix = current_prefix -> child[(int) *match];
                break;
            }
        }
        else if(*p != *match){
            // Ramo atual não é um prefixo, deve ser desmembrado
                _split_trie(arena, &current_prefix, p, match);
            break;
        }
        else{
            // Checando ramo atual
            p ++;
            match ++;
        }
    }
    // Estamos posicionados no nodo certo. Inserir.
    current_prefix -> leaf = true;
    switch(type){
    case INT:
        current_prefix -> value.integer = va_arg(arguments, int);
        break;
    case DOUBLE:
        current_prefix -> value.real = va_arg(arguments, double);
        break;
    default:
        current_prefix -> value.generic = va_arg(arguments, void *);
        break;
    }
}
@

A função que cria um novo nodo é a mais simples. Ela precisa saber
apenas a string que irá conter e quem é o seu pai. Ela é um nodo novo,
portanto não terá filhos. E não terá um valor, pois não é uma folha:

@<Trie: Funções Estáticas@>+=
  struct _trie *_new_node(void *arena, char *string, struct _trie *parent){
    int i, size = strlen(string);
    struct _trie *ret;
    ret = (struct _trie *) Walloc_arena(arena, sizeof(struct _trie));
    if(ret == NULL)
        goto no_memory_error;
    ret -> string = (char *) Walloc_arena(arena, size + 1);
    if(ret -> string == NULL)
        goto no_memory_error;
    strncpy(ret -> string, string, size);
    ret -> string[size] = '\0';
    ret -> leaf = false;
    for(i = 0; i < 256; i ++)
        ret -> child[i] = NULL;
    ret -> parent = parent;
    return ret;
no_memory_error:
    fprintf(stderr, "ERROR (0): No memory enough. Please increase the value of "
	    "%s at conf/conf.h.\n",(arena==_user_arena)?"W_MAX_MEMORY":
	    "W_INTERNAL_MEMORY");
    return NULL;
}
@

A função que divide um ramo em dois outros é mais complexa. Ela
precisa manter o ramo atual com o prefixo que a nova string e a antiga
tem em comum, e fazer ele divergir em dois ramos. Um vai herdar todas
as características do ramo antigo e o outro será um ramo-folha que
receberá o novo valor.

@<Trie: Funções Estáticas@>+=
void _split_trie(void *arena, struct _trie **origin, char *divergence,
		 char *remaining_match){
    struct _trie *old_way, *new_way;
    int i;
    old_way = _new_node(arena, divergence, *origin);
    new_way = _new_node(arena, remaining_match, *origin);
    for(i = 0; i < 256; i ++){
        old_way -> child[i] = (*origin) -> child[i];
        (*origin) -> child[i] = NULL;
    }
    old_way -> leaf = (*origin) -> leaf;
    (*origin) -> leaf = false;
    (*origin) -> child[(int) *divergence] = old_way;
    (*origin) -> child[(int) *remaining_match] = new_way;
    *divergence = '\0';
    *origin = new_way;
}
@

Por fim, temos que ler um valor armazenado em uma trie. Isso é muito
semelhante ao código de armazenar nela, com a diferença de que assim
que não encontramos um caractere esperado, nós apenas encerraremos e
retornaremos falso para indicar que não achamos nada. Se retornarmos
verdadeiro, é porque achamos e armazenamos o valor achado no último
argumento:

@<Trie: Declarações@>+=
bool _search_trie(struct _trie *tree, int type, char *name, ...);
@

@<Trie: Definições@>+=
bool _search_trie(struct _trie *tree, int type, char *name, ...){
    va_list arguments;
    va_start(arguments, name);
    struct _trie *current_prefix = tree;
    char *match = name, *p = current_prefix -> string;
    while(*match != '\0'){
        if(*p == '\0'){
            // Ramo atual é um prefixo, ir para próximo
            if(current_prefix -> child[(int) *match] != NULL){
                current_prefix = current_prefix -> child[(int) *match];
                p = current_prefix -> string;
            }
            else
                return false;
        }
        else if(*p == *match){
            p ++;
            match ++;
        }
        else
            return false;
    }
    if(*p != '\0' || !(current_prefix -> leaf))
        return false;
    switch(type){
        int *ret;
        double *ret2;
        void **ret3;
    case INT:
        ret = va_arg(arguments, int *);
        *ret = current_prefix -> value.integer;
        return true;
    case DOUBLE:
        ret2 = va_arg(arguments, double *);
        *ret2 = current_prefix -> value.real;
        return true;
    default:
        ret3 = va_arg(arguments, void **);
        *ret3 = current_prefix -> value.generic;
        return true;
    }
}
@

A tarefa de remover um valor de uma trie é muito semelhante à tarefa
de consultar o valor. A diferença é que quando o encontramos, nós
apenas marcamos o nodo emque ele está como não sendo mais uma folha:

@<Trie: Declarações@>+=
void _remove_trie(struct _trie *tree, char *name);
@

@<Trie: Definições@>+=
void _remove_trie(struct _trie *tree, char *name){
    struct _trie *current_prefix = tree;
    char *match = name, *p = current_prefix -> string;
    while(*match != '\0'){
        if(*p == '\0'){
            // Ramo atual é um prefixo, ir para próximo
            if(current_prefix -> child[(int) *match] != NULL){
                current_prefix = current_prefix -> child[(int) *match];
                p = current_prefix -> string;
            }
            else
                return;
        }
        else if(*p == *match){
            p ++;
            match ++;
        }
        else
            return;
    }
    current_prefix -> leaf = false;
}
@

O último recurso que forneceremos será imprimir o valor de cada uma
das strings armazenadas em uma árvore trie. Isso só será efetivamente
definido caso estejamos em modo de depuração. Não será um código que
estamos esperando usar em modo de produção:

@<Trie: Declarações@>+=
#if W_DEBUG_LEVEL >= 1
void _debug_trie_values(char *prefix, struct _trie *tree);
#endif
@

@<Trie: Definições@>+=
#if W_DEBUG_LEVEL >= 1
void _debug_trie_values(char *prefix, struct _trie *tree){
    int i;
    if(tree -> leaf)
        printf(" '%s%s'", prefix, tree -> string);
    for(i = 0; i < 256; i ++)
        if(tree -> child[i] != NULL){
            char buffer[1024];
            strncpy(buffer, prefix, 1024);
            strncat(buffer, tree -> string, 1024 - strlen(prefix));
            _debug_trie_values(buffer, tree -> child[i]);
        }
}
#endif
@
