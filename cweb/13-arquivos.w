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
#if W_TARGET == W_ELF
static sqlite3 *database;
#endif
@

Agora vamos à questão de onde devemos armazenar o banco de dados de um
projeto Weaver.  O local escolhido deverá ser um diretório oculto na
``home'' de um usuário. Iremos escolher então o endereço
\monoespaco{.weaver\_data/XXX/XXX.db} no diretório do usuário, onde ``XXX''
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
  size_t path_length = 0, w_prog_length = strlen(W_PROG);
  int ret;
  char *p, *zErrMsg = NULL;
  // Temos que obter o diretório home do usuário. Primeiro tentamos
  // ler a variável de ambiente HOME:
  p = getenv("HOME");
  if(p != NULL){
    path_length = strlen(p);
    if(path_length + 2 * w_prog_length + 17 > 255){
      fprintf(stderr, "ERROR: Path too long: %s/.weaver_data/%s/%s.db\n", p,
	      W_PROG, W_PROG);
      exit(1);
    }
    memcpy(path, p, path_length + 1);
  } 
  else{
    // Se não conseguimos obter a variável HOME, usamos getpwuid para
    // obter o diretório configurado no /etc/passwd:
    struct passwd *pw = getpwuid(getuid());
    if(pw != NULL){
      path_length = strlen(pw -> pw_dir);
      if(path_length + 2 * w_prog_length + 17 > 255){
	fprintf(stderr, "ERROR: Path too long: %s/.weaver_data/%s/%s.db\n", p,
		W_PROG, W_PROG);
	exit(1);
      }
      memcpy(path, pw -> pw_dir, path_length + 1);
    }
    else{
      // Se tudo falhar, tentamos usar o /tmp/ e avisamos o usuário:
      fprintf(stderr,
              "WARNING (0): Couldn't get home directory. Saving data in /tmp."
              "\n");
      path_length = 4;
      memcpy(path, "/tmp", 5);
    }
  }
  // Criando o endereço do diretório cuidando com buffer overflows:
  memcpy(&path[path_length], "/.weaver_data/", 15);
  path_length += 14;
  mkdir(path, 0755);
  // Criando o .weaver_data/W_PROG:
  memcpy(&path[path_length], W_PROG, w_prog_length + 1);
  path_length += w_prog_length;
  memcpy(&path[path_length], "/", 2);
  path_length ++;
  mkdir(path, 0755);
  // Adicionando o nome do arquivo:
  memcpy(&path[path_length], W_PROG, w_prog_length + 1);
  path_length += w_prog_length;
  memcpy(&path[path_length], ".db", 4);
  path_length +=3;
  // Se o banco de dados não existir, ele será criado:
  ret = sqlite3_open(path, &database);
  if(ret != SQLITE_OK){
    fprintf(stderr,
            "WARNING (0): Can't create or read database %s. "
            "Data won't be saved: %s\n",
            path,
            sqlite3_errmsg(database));
  }
  // Criando tabelas se elas não existirem. Tabela de inteiros:
  ret = sqlite3_exec(database,
                     "CREATE TABLE IF NOT EXISTS "
                     "int_data(name TEXT PRIMARY KEY, value INT);",
                     NULL, NULL, &zErrMsg);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): SQL error: %s\n ", zErrMsg);
    sqlite3_free(zErrMsg);
  }
  // Tabela de floats:
  if(ret == SQLITE_OK){
    ret = sqlite3_exec(database,
                       "CREATE TABLE IF NOT EXISTS "
                       "float_data(name TEXT PRIMARY KEY, value REAL);",
                       NULL, NULL, &zErrMsg);
    if(ret != SQLITE_OK){
      fprintf(stderr, "WARNING (0): SQL error: %s\n ", zErrMsg);
      sqlite3_free(zErrMsg);
    }
  }
  // Tabela de strings:
  if(ret == SQLITE_OK){
    ret = sqlite3_exec(database,
                       "CREATE TABLE IF NOT EXISTS "
                       "string_data(name TEXT PRIMARY KEY, value TEXT);",
                       NULL, NULL, &zErrMsg);
    if(ret != SQLITE_OK){
      fprintf(stderr, "WARNING (0): SQL error: %s\n ", zErrMsg);
      sqlite3_free(zErrMsg);
    }
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

@*1 Gravando Dados no Banco de Dados.

Salvar os dados será diferente se estamos executando via web ou
nativamente. Via web, só o que emos que fazer será criar
cookies. Nativamente, usaremos o Sqlite3 para armazenar os dados na
tabela. Os dados que salvamos podem ser inteiros, números em ponto
flutuante e strings.

No caso de inteiros, a função que usaremos será declarada como:

@<Banco de Dados: Declarações@>=
void _write_integer(char *name, int value);
@

Esta função será uma das funções |W| a ser tornada pública:

@<Funções Weaver@>+=
  void (*write_integer)(char*, int);
@
@<API Weaver: Inicialização@>+=
  W.write_integer = &_write_integer;
@

A definição, caso estejamos rodando nativamente com Sqlite é:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
void _write_integer(char *name, int value){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "INSERT OR REPLACE INTO int_data VALUES (?, ?);",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o valor da variável na expressão:
  ret = sqlite3_bind_int(stmt, 2, value);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret != SQLITE_DONE){
    fprintf(stderr, "WARNING (0): Possible problem saving data.\n");
    return;
  }
  // Encerrando
  sqlite3_finalize(stmt);
}
#endif
@

Já se estivermos executando na web, a definição passa a ser:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
void _write_integer(char *name, int value){
  EM_ASM_({
      document.cookie = "int_" + Pointer_stringify($0) + "=" + $1 +
        "; expires=Fri, 31 Dec 9999 23:59:59 GMT";
    }, name, value);
}
#endif
@

E assim estamos armazenando números inteiros. Exceto na web, em que
todos os números são tratados como ponto-flutuante (mas de qualquer
forma, o compilador garante que somente inteiros são passados).

Vamos agora ao armazenamento de números em ponto-flutuante. A função é
declarada como:

@<Banco de Dados: Declarações@>+=
void _write_float(char *name, float value);
@

Tornando a função pública em |W|:

@<Funções Weaver@>+=
  void (*write_float)(char*, float);
@
@<API Weaver: Inicialização@>+=
  W.write_float = &_write_float;
@

Definindo a função com Sqlite:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
void _write_float(char *name, float value){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "INSERT OR REPLACE INTO float_data VALUES (?, ?);",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o valor da variável na expressão:
  ret = sqlite3_bind_double(stmt, 2, value);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret != SQLITE_DONE){
    fprintf(stderr, "WARNING (0): Possible problem saving data.\n");
    return;
  }
  // Encerrando
  sqlite3_finalize(stmt);
}
#endif
@

Definindo a mesma função para funcionar usando cookies:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
void _write_float(char *name, float value){
  EM_ASM_({
      document.cookie = "float_" + Pointer_stringify($0) + "=" + $1 +
        "; expires=Fri, 31 Dec 9999 23:59:59 GMT";
    }, name, value);
}
#endif
@

E agora a última função de escrita. A função para escrever uma
string. Primeiro sua declaração e preparação:

@<Banco de Dados: Declarações@>+=
void _write_string(char *name, char *value);
@

Tornando a função pública em |W|:

@<Funções Weaver@>+=
  void (*write_string)(char *, char *);
@
@<API Weaver: Inicialização@>+=
  W.write_string = &_write_string;
@

A implementação com Sqlite:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
void _write_string(char *name, char *value){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "INSERT OR REPLACE INTO string_data VALUES (?, ?);",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Inserindo o valor da variável na expressão:
  ret = sqlite3_bind_text(stmt, 2, value, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    fprintf(stderr, "WARNING (0): Can't save data.\n");
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret != SQLITE_DONE){
    fprintf(stderr, "WARNING (0): Possible problem saving data.\n");
    return;
  }
  // Encerrando
  sqlite3_finalize(stmt);
}
#endif
@

E a implementação usando cookies:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
void _write_string(char *name, char *value){
  EM_ASM_({
      document.cookie = "string_" + Pointer_stringify($0) + "=" +
        Pointer_stringify($1) + "; expires=Fri, 31 Dec 9999 23:59:59 GMT";
    }, name, value);
}
#endif
@

@*1 Lendo do Banco de Dados.

Para ler as informações armazenadas, vamos precisar de funções com a
seguinte assinatura:

@<Banco de Dados: Declarações@>+=
bool _read_integer(char *name, int *value);
bool _read_float(char *name, float *value);
bool _read_string(char *name, char *value, int n);
@

E elas serão colocadas em |W|:

@<Funções Weaver@>+=
  bool (*read_integer)(char *, int *);
  bool (*read_float)(char *, float *);
  bool (*read_string)(char *, char *, int);
@
@<API Weaver: Inicialização@>+=
  W.read_integer = &_read_integer;
  W.read_float = &_read_float;
  W.read_string = &_read_string;
@

A função que lê um inteiro checa o primeiro argumento para sabver o
nome da variável que deve ser lida. O segundo argumento é um ponteiro
para inteiro que indica onde ela deve olocar o resultado se conseguir
encontrá-lo. E a função deve retornar um booleano que indica se ela
conseguiu encontrar a variável pedida ou não. Usando Sqlite, fazemos
assim:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
bool _read_integer(char *name, int *value){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "SELECT value FROM int_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return false;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    return false;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret == SQLITE_ROW){
    *value = sqlite3_column_int(stmt, 0);
    sqlite3_finalize(stmt);
    return true;
  }
  else{
    sqlite3_finalize(stmt);
    return false;
  }
}
#endif
@

Ler um número em ponto-flutuante do Sqlite segue a mesma lógica:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
bool _read_float(char *name, float *value){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "SELECT value FROM float_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return false;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    return false;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret == SQLITE_ROW){
    *value = sqlite3_column_double(stmt, 0);
    sqlite3_finalize(stmt);
    return true;
  }
  else{
    sqlite3_finalize(stmt);
    return false;
  }
}
#endif
@

E ler uma string tem apenas a diferença de que temos que copiar a
string preenchida pela função |sqlite3_column_text| antes de infocarmos
outras funções que tem o potencial de desalocá-la, e devemos copiar
no máximo o número de bytes passado como tereiro argumento:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_ELF
bool _read_string(char *name, char *value, int size){
  int ret;
  sqlite3_stmt *stmt;
  const unsigned char *p;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "SELECT value FROM string_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return false;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    return false;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  if(ret == SQLITE_ROW){
    p = sqlite3_column_text(stmt, 0);
    strncpy(value, (const char *) p, size);
    sqlite3_finalize(stmt);
    return true;
  }
  else{
    sqlite3_finalize(stmt);
    return false;
  }
}
#endif
@

Já para lermos um inteiro quando executamos na web via cookies:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
bool _read_integer(char *name, int *value){
  // Primeiro checamos se o cookie existe:
  int exists = EM_ASM_INT({
      var nameEQ = "int_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0)
          return 1;
      }
      return 0;
    }, name);
  if(!exists)
    return false;
  // Se não encerramos, o valor existe. Vamos obtê-lo:
  *value = EM_ASM_INT({
      var nameEQ = "int_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0)
          return parseInt(c.substring(nameEQ.length,c.length), 10);
      }
    }, name);
  return true;
}
#endif
@

Ler um número em ponto fluuante do Javascript é exatamente a mesma
coisa, já que lá é tudo número em ponto flutuante mesmo. Só precisamos
converter para float usando |EM_ASM_DOUBLE|:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
bool _read_float(char *name, float *value){
  // Primeiro checamos se o cookie existe:
  int exists = EM_ASM_INT({
      var nameEQ = "float_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0)
          return 1;
      }
      return 0;
    }, name);
  if(!exists)
    return false;
  // Se não encerramos, o valor existe. Vamos obtê-lo:
  *value = EM_ASM_DOUBLE({
      var nameEQ = "float_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0)
          return parseInt(c.substring(nameEQ.length,c.length), 10);
      }
    }, name);
  return true;
}
#endif
@

Agora ler uma string é um pouco mais complexo, pois precisamos invocar
algumas funções especiais do Emscripten dentro do código Javascript
para podermos copiar uma string Javascript para C:

@<Banco de Dados: Definições@>=
#if W_TARGET == W_WEB
bool _read_string(char *name, char *value, int size){
  // Primeiro checamos se o cookie existe:
  int exists = EM_ASM_INT({
      var nameEQ = "string_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0)
          return 1;
      }
      return 0;
    }, name);
  if(!exists)
    return false;
  // Se não encerramos, o valor existe. Vamos obtê-lo:
  EM_ASM_({
      var nameEQ = "string_" + Pointer_stringify($0) + "=";
      var ca = document.cookie.split(';');
      for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0){
          stringToUTF8(c.substring(nameEQ.length,c.length), $1, $2);
        }
      }
    }, name, value, size);
  return true;
}
#endif
@

@*1 Removendo do Banco de Dados.

Uma vez que podemos guardar coisas, será importante tambem poder jogar
fora o que armazenamos, sem substituir por outra coisa. Enfim, devemos
ser capazes de remover entradas do banco de dados recebendo o seu nome
omo argumento. As funções que farão isso serão:

@<Banco de Dados: Declarações@>+=
void _delete_integer(char *name);
void _delete_float(char *name);
void _delete_string(char *name);
void _delete_all(void);
@

E elas serão colocadas em |W|:

@<Funções Weaver@>+=
  void (*delete_integer)(char *);
  void (*delete_float)(char *);
  void (*delete_string)(char *);
  void (*delete_all)(void);
@
@<API Weaver: Inicialização@>+=
  W.delete_integer = &_delete_integer;
  W.delete_float = &_delete_float;
  W.delete_string = &_delete_string;
  W.delete_all = &_delete_all;
@

Apagando um inteiro via Sqlite:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_ELF
void _delete_integer(char *name){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "DELETE FROM int_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    sqlite3_finalize(stmt);
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  sqlite3_finalize(stmt);
}
#endif
@

Apagando um número em ponto-flutuante via Sqlite:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_ELF
void _delete_float(char *name){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "DELETE FROM float_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    sqlite3_finalize(stmt);
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  sqlite3_finalize(stmt);
}
#endif
@

Apagando uma string via Sqlite:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_ELF
void _delete_string(char *name){
  int ret;
  sqlite3_stmt *stmt;
  // Primeiro preparamos a expressão:
  ret = sqlite3_prepare_v2(database,
                           "DELETE FROM string_data WHERE name = ?;",
                           -1, &stmt, 0);
  if(ret != SQLITE_OK){
    return;
  }
  // Inserindo o nome da variável na expressão:
  ret = sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC);
  if(ret != SQLITE_OK){
    sqlite3_finalize(stmt);
    return;
  }
  // Executando a expressão SQL:
  ret = sqlite3_step(stmt);
  sqlite3_finalize(stmt);
}
#endif
@

Apagando tudo via Sqlite:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_ELF
void _delete_all(void){
  sqlite3_exec(database, "DELETE * FROM int_data; ", NULL, NULL, NULL);
  sqlite3_exec(database, "DELETE * FROM float_data; ", NULL, NULL, NULL);
  sqlite3_exec(database, "DELETE * FROM string_data; ", NULL, NULL, NULL);
}
#endif
@

Apagar qualquer valor via cookies é simplesmente colocar qualquer valor nele
e colocar uma data de valdade no passado:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_WEB
void _delete_integer(char *name){
  EM_ASM_({
      document.cookie = "int_" + Pointer_stringify($0) + "=0" +
        ";expires=Thu, 01 Jan 1970 00:00:01 GMT";
    }, name);
}
void _delete_float(char *name){
  EM_ASM_({
      document.cookie = "float_" + Pointer_stringify($0) + "=0" +
        ";expires=Thu, 01 Jan 1970 00:00:01 GMT";
    }, name);
}
void _delete_string(char *name){
  EM_ASM_({
      document.cookie = "string_" + Pointer_stringify($0) + "=0" +
        ";expires=Thu, 01 Jan 1970 00:00:01 GMT";
    }, name);
}
#endif
@

Já apagar todos os cookies requer que iteremos sobre todos eles para
colocar no passado a data de validade:

@<Banco de Dados: Definições@>+=
#if W_TARGET == W_WEB
void _delete_all(void){
  EM_ASM({
      var cookies = document.cookie.split(";");
      for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i];
        var eqPos = cookie.indexOf("=");
        var name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie;
        document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT";
      }
    });
}
#endif
@

@*1 Sumário das variáveis e Funções de Leitura e Escrita de Dados.

\macronome As seguintes 10 novas funções foram definidas:

\macrovalor|void W.delete_all(void)|: Apaga do banco de dados todos os
valores armazenados pelo programa.

\macrovalor|void W.delete_float(char *name)|: Apaga do banco de dados
o número em ponto\=flutuante identificado pela string passada como
argumento. Ignora valores não-encontrados.

\macrovalor|void W.delete_integer(char *name)|: Apaga do banco de dados
o número inteiro identificado pela string passada como
argumento. Ignora valores não-encontrados.

\macrovalor|void W.delete_string(char *name)|: Apaga do banco de dados
a string identificada pelo argumento. Ignora valores não-encontrados.

\macrovalor|bool W.read_float(char *name, float *value)|: Lê um valor
identificado pelo primeiro argumento que é um número em ponto
flutuante do banco de dados e armazena no local apontado pelo segundo
argumento caso ele seja encontrado. Retorna se a operação foi
bem-sucedida ou não.

\macrovalor|bool W.read_integer(char *name, int *value)|: Lê um valor
identificado pelo primeiro argumento que é um número inteiro do banco
de dados e armazena no local apontado pelo segundo argumento caso ele
seja encontrado. Retorna se a operação foi bem-sucedida ou não.

\macrovalor|bool W.read_string(char *name, char *value, int n)|: Lê um valor
identificado pelo primeiro argumento que é uma string do banco de
dados e armazena no local apontado pelo segundo argumento, copiando no
máximo o número de bytes passado como terceiro argumento. Retorna se a
operação foi bem-sucedida ou não.

\macrovalor|void W.write_float(char *name, float value)|: Armazena no
banco de dados um valor em ponto flutuante identificado pelo nome
passado como primeiro argumento que deverá ser igual ao segundo
argumento. O valor será preservado mesmo após o programa se encerrar.

\macrovalor|void W.write_integer(char *name, int value)|: Armazena no
banco de dados um valor inteiro identificado pelo nome passado como
primeiro argumento que deverá ser igual ao segundo argumento. O valor
será preservado mesmo após o programa se encerrar.

\macrovalor|void W.write_string(char *name, char *value)|: Armazena no
banco de dados uma string identificada pelo nome passado como primeiro
argumento que deverá ser igual ao segundo argumento. O valor será
preservado mesmo após o programa se encerrar.
