@*Leitura e Escrita de Dados.

Em um jogo é importane que sejamos capazes de ler e escrever dados que
sejam preservados mesmo quando o jogo for encerrado, para que possam
ser obidos novamente no futuro. Um dos usos mais antigos disso é
armazenar a pontuação máxima obtida por um jogador em um dado jogo, e
assim estimular uma competição por maiores pontos.

Jogos mais sofisticados podem armazenar muitas outras informações,
tais como o nome do jogador, nome de personagens e várias informações
sobre escolhas tomadas.

É importante então que sejamos capazes de armazenar e recuperar depois
três tipos de dados: inteiros, número em ponto flutuante e strings. E
cada armazenamento pode ter um nome específico. Isso tornará o
gerenciamento de leitura e escrita muito mais intuitiva do que o uso
direto de arquivos que precisam ser sempre abertos e fechados. Weaver
deverá cuidar de toda essa burocracia sem que um programador tenha que
se preocupar com isso.

A leitura e escrita de dados em arquivos não é algo tão simples como
parece. Uma queda de energia ou falha fatal do jogo em momentosruins
pode acabar corrompendo todos os dados salvos. A melhor forma de evitar
isso é usar um banco de dados se estivermos rodando um programa
nativo. Se estivermos executando em um navegador de Internet, aí o
problema torna-se outro. Nós nem mesmo seremos capazes de abrir
arquivos, salvar dados precisa ser feito por meio de cookies.

Então, uma grande vantagem de abstrairmos coisas como gerenciamento de
arquivos e criarmos apenas uma interface para ler e escrever variáveis
permanentes, é que essa mesma interface pode ser usada taqnto em jogos
executados nativamente com aqueles que executam em um navegador.

@*1 Inicializando o Sqlite.

O Sqlite é uma biblioteca de banco de dados que permite criar e
acessar arquivos simples como sendo um banco de dados relacional,
mantendo as características de um banco de dados relacional. Como por
exemplo, uma alta tolerância à falhas e à perda de dados, mesmo em
caso de quedas de energia e acesso simultâneo a uma mesma base de
dados. A biblioteca foi projetada e criada em 2000 por Dwayne Richard
Hipp.

As características do Sqlite são bastante importantes para evitarmos o
trágico problema de arquivos sendo corrompidos e fazendo com que um
usuário perca todos os seus dados caso a energia acabe ou o jogo seja
fechado no momento em que ele está salvando dados.

O código da biblioteca será inserido estaticamente junto com o código
da engine Weaver em projetos Weaver. Então só temos que nos preocupar
em inicializar a biblioteca e criar uma interface para suas
funcionalidades.

Primeiro vamos criar o arquivo que conterá tudo isso:

@(project/src/weaver/database.h@>=
#ifndef _database_h_
#define _database_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Banco de Dados: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/database.c@>=
#include "weaver.h"
@<Banco de Dados: Inclui Cabeçalhos@>
@<Banco de Dados: Variáveis Estáticas@>
//@<Banco de Dados: Funções Estáticas@>
@<Banco de Dados: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "database.h"
@

Iremos usar o Sqlite somente se estivermos rodando o jogo
nativamente. Se estivermos rodando na web, usaremos outra solução
(cookies):

@<Banco de Dados: Inclui Cabeçalhos@>=
#if W_TARGET == W_ELF
#include <sys/stat.h>  // mkdir
#include <sys/types.h> // mkdir, getpwuid, getuid
#include <unistd.h> // getuid
#include <stdlib.h> // getenv
#include <pwd.h> // getpwuid
#include "../misc/sqlite/sqlite3.h"
#endif
@

Precisamos de um ponteiro que irá representar nossa conexão com o
banco de dados:

@<Banco de Dados: Variáveis Estáticas@>=
static sqlite3 *database;
@

Agora vamos à questão de onde devemos armazenar o banco de dados de um
projeto Weaver.  O local escolhido deverá ser um diretório oculto na
``home'' de um usuário. Iremos escolher então o endereço
\monoespaco{.weaver/XXX/XXX.db} no diretório do usuário, onde ``XXX''
é o nome do projeto Weaver em execução. Na inicialização iremos então
nos assegurar de que o banco de dados existe, e se não existir iremos
criá-lo:

@<Banco de Dados: Declarações@>=
#if W_TARGET == W_ELF
void _initialize_database(void);
#endif
@

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
void _initialize_database(void){
  char path[256];
  int ret, size;
  char *p;
  // Temos que obter o diretório home do usuário. Primeiro tentamos
  // ler a variável de ambiente HOME:
  p = getenv("HOME");
  if(p != NULL){
    size = strlen(p);
    strncpy(path, p, 255);
    path[255] = '\0';
  } 
  else{
    // Se não conseguimos obter a variável HOME, usamos getpwuid para
    // obter o diretório configurado no /etc/passwd:
    struct passwd *pw = getpwuid(getuid());
    if(pw != NULL){
      size = strlen(pw -> pw_dir);
      strncpy(path, pw -> pw_dir, 255);
      path[255] = '\0';
    }
    else{
      // Se tudo falhar, tentamos usar o /tmp/ e avisamos o usuário:
      fprintf(stderr,
              "WARNING (0): Couldn't get home directory. Saving data in /tmp."
              "\n");
      size = 4;
      strncpy(path, "/tmp", 255);
    }
  }
  // Criando o endereço do diretório cuidando com buffer overflows:
  if(size + 9 < 256){
    size += 9;
    strcat(path, "/.weaver/");
    mkdir(path, 0755);
  }
  // Criando o .weaver/W_PROG:
  size += strlen(W_PROG) + 1;
  if(size < 256){
    strcat(path, W_PROG);
    strcat(path, "/");
    mkdir(path, 0755);
  }
  // Adicionando o nome do arquivo:
  size += strlen(W_PROG) + 3;
  if(size < 256){
    strcat(path, W_PROG);
    strcat(path, ".db");
  }
  // Se o banco de dados não existir, ele será criado:
  ret = sqlite3_open(path, &database);
  if(ret != SQLITE_OK){
    fprintf(stderr,
            "WARNING (0): Can't create or read database %s. "
            "Data won't be saved: %s\n",
            path,
            sqlite3_errmsg(database));
  }
}
#endif
@

Para que essa função seja executada na inicialização, adicionamos ela
na lista de funções a serem usadas na inicialização:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
{
  _initialize_database();
}
#endif
@

Precisamos também finalizar a conexão quando o programa for encerrado:

@<Banco de Dados: Declarações@>=
#if W_TARGET == W_ELF
void _finalize_database(void);
#endif
@

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
void _finalize_database(void){
  sqlite3_close(database);
}
#endif
@

E ambém edicionamos a função de finalização para ser executada na
finalização:

@<API Weaver: Finalização@>+=
#if W_TARGET == W_ELF
{
  _finalize_database();
}
#endif
@
