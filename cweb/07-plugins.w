@* Plugins e Agendadores.

Um projeto Weaver pode suportar \italico{plugins}. Mas o que isso
significa depende se o projeto está sendo compilado para ser um
executável ELF ou uma página web. Por causa deles, iremos suportar
também algumas funções que irão peritir agendar uma função para ser
executada no futuro ou periodicamente. Faremos isso porque esta é a
forma de suportarmos programação interativa: o usuário pode pedir para
que um plugin seja recarregado sempre que ele sofrer alterações. E em
seguida pode modificar o código do plugin e recompilá-lo, vendo as
mudanças instantaneamente, sem precisar fechar o jogo e abri-lo
novamente.

Do ponto de vista de um usuário, o que chamamos de \italico{plugin}
deve ser um único arquivo com código C (digamos que
seja \monoespaco{myplugin.c}). Este arquivo pode ser copiado e colado
para o diretório \monoespaco{plugins} de um Projeto Weaver e então
subitamente podemos passar a ativá-lo e desativá-lo por meio das funções
|W.enable_plugin(plugin_id)| e |W.disable_plugin(plugin_id)| sendo que
o ID do \italico{plugin} pode ser obtido com
|plugin_id = W.get_plugin("my_plugin")|.

Quando um \italico{plugin} está ativo, ele pode passar a executar
alguma atividade durante todo \italico{loop} principal e também pode
executar atividades de inicialização no momento em que é ativado. No
momento em que é desativado, ele executa suas atividades de
finalização. Um plugin também pode se auto-ativar automaticamente
durante a inicialização dependendo de sua natureza.

Uma atividade típica que pode ser implementadas via \italico{plugin}
é um esquema de tradução de teclas do teclado para que teclados com
símbolos exóticos sejam suportados. Ele só precisaria definir o
esquema de tradução na inicialização e nada precisaria ser feito em
cada iteração do \italico{loop} principal. Ou pode ser feito
um \italico{plugin} que não faça nada em sua inicialização, mas em
todo \italico{loop} principal mostre no canto da tela um indicador de
quantos \italico{frames} por segundo estão sendo executados.

Mas as possibilidades não param nisso. Uma pessoa pode projetar um
jogo de modo que a maior parte das entidades que existam nele sejam na
verdade \italico{plugins}. Desta forma, um jogador poderia
personalizar sua instalação do jogo removendo elementos não-desejados
do jogo ou adicionando outros meramente copiando arquivos. Da mesma
forma, ele poderia recompilar os \italico{plugins} enquanto o jogo
executa e as mudanças que ele faria poderiam ser refletidas
imediatamente no jogo em execução, sem precisar fechá-lo. Essa técnica
é chamada de \negrito{programação interativa}.

O segredo para isso é compilar \italico{plugins} como bibliotecas
compartilhadas e carregá-los dinamicamente se o nosso programa for
compilado para um executável Linux.

Neste ponto, esbarramos em algumas limitações do ambiente
Web. Programas compilados por meio de Emscripten só podem ter os tais
``\italico{plugins}'' definidos durante a compilação. Para eles, o
código do \italico{plugin} deve ser injetado em seu proprio código
durante a compilação. De fato, pode-se questionar se podemos realmente
chamar tais coisas de \italico{plugins}.

@*1 Interface dos Plugins.

Todo \italico{plugin}, cujo nome é |MYPLUGIN| (o nome deve ser único
para cada \italico{plugin}), e cujo código está
em \monoespaco{plugins/MYPLUGIN.c}, deve definir as seguintes funções:

\macronome|void _init_plugin_MYPLUGIN(W_PLUGIN)|: Esta função será
executada somente uma vez quando o seu jogo detectar a presença do
\italico{plugin}. Tipicamente isso será durante a inicialização do
programa. Mas o \italico{plugin} pode ser adicionado à algum diretório
do jogo no momento em que ele está em execução. Neste caso, o jogo o
detectará assim que entrar no próximo \italico{loop} principal e
executará a função neste momento.

\macronome|void _fini_plugin_MYPLUGIN(W_PLUGIN)|: Esta função será
executada apenas uma vez quando o jogo for finalizado.

\macronome|void _run_plugin_MYPLUGIN(W_PLUGIN)|: Esta função será
executada toda vez que um \italico{plugin} estiver ativado e
estivermos em uma iteração do \italico{loop} principal.

\macronome|void _enable_MYPLUGIN(W_PLUGIN)|: Esta função será executada
toda vez que um plugin for ativado por meio de
|W.enable_plugin(plugin_id)|.

\macronome|void _disable_MYPLUGIN(W_PLUGIN)|: Esta função será executada
toda vez que um plugin for ativado por meio de
|W.disable_plugin(plugin_id)|.

Um \italico{plugin} terá acesso à todas as funções e variáveis que são
mencionadas no sumário de cada capítulo, com as notáveis exceções de
|Winit|, |Wquit|, |Wloop|, |Wsubloop|, |Wexit| e |Wexit_loop|. Mesmo
nos casos em que o plugin é uma biblioteca compartilhada invocada
dinamicamente, isso é possível graças ao argumento |W_PLUGIN| recebido
como argumento pelas funções. Ele na verdade é a estrutura |W|:

@<Declaração de Cabeçalhos Finais@>=
// Mágica para fazer plugins entenderem a estrutura W:
#define W_PLUGIN struct _weaver_struct *_W
#ifdef W_PLUGIN_CODE
#define W (*_W)
#endif
@

Com a ajuda da macro acima dentro dos \italico{plugins} poderemos usar
funções e variáveis na forma |W.flush_input()| e não na deselegante
forma |W->flush_input()|. O nosso Makefile será responsável por
definir |W_PLUGIN_CODE| para os \italico{plugins}.

Para saber onde encontrar os \italico{plugins} durante a execução,
definimos em \monoespaco{conf/conf.h} as seguintes macros:

\macronome|W_INSTALL_DATA|: O diretório em que os dados do jogo
(texturas, sons, shaders) será instalado.

\macronome|W_INSTALL_PROG|: O diretório em que o arquivo executável do jogo será
instalado.

\macronome|W_PLUGIN_PATH|: Uma string com lista de diretórios
separadas por dois pontos (``:''). Se for uma string vazia, isso
significa que o suporte à \italico{plugins} dee ser desativado.

\macronome|W_MAX_SCHEDULING|: O número máximo de funções que
podem ser agendadas para executar periodicamente ou apenas uma vez em
algum momento do futuro.

Definiremos agora os valores padrão:

@(project/src/weaver/conf_end.h@>+=
#ifndef W_INSTALL_DATA
#define W_INSTALL_DATA "/usr/share/games/"W_PROG
#endif
#ifndef W_INSTALL_PROG
#define W_INSTALL_PROG "/usr/games/"
#endif
#ifndef W_PLUGIN_PATH
#if W_DEBUG_LEVEL == 0
#define W_PLUGIN_PATH  W_INSTALL_DATA"/plugins"
#else
#define W_PLUGIN_PATH  "compiled_plugins"
#endif
#endif
#ifndef W_MAX_SCHEDULING
#define W_MAX_SCHEDULING 8
#endif
@

@*1 Estruturas Básicas.

Todas as informações sobre \italico{plugins} serão armazenadas nos
arquivos \monoespaco{plugins.c} e \monoespaco{plugins.h}:

@<Cabeçalhos Gerais Dependentes da Estrutura Global@>=
#include "plugins.h"
@
@(project/src/weaver/plugins.h@>=
#ifndef _plugins_h_
#define _plugins_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
#if W_TARGET == W_ELF
#include <dlfcn.h> // dlopen, dlsym, dlclose, dlerror
#include <sys/types.h> // stat
#include <sys/stat.h> // stat
#include <unistd.h> // stat
#include <pthread.h> // pthread_mutex_init, pthread_mutex_destroy
#include <string.h> // strncpy
#include <stdio.h> // perror
#include <libgen.h> // basename
#include <sys/types.h> // opendir, readdir
#include <dirent.h> // opendir, readdir
#include <errno.h>
#endif
#include <stdbool.h>
@<Declarações de Plugins@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/plugins.c@>=
#include "plugins.h"
@

Primeiro temos que definir que tipo de informação teremos que
armazenar para cada plugin. A resposta é a estrutura:

@<Declarações de Plugins@>+=
struct _plugin_data{
#if W_TARGET == W_ELF
  char library[256];
  void *handle;
  ino_t id;
#ifdef W_PREVENT_SELF_ENABLING_PLUGINS
  bool finished_initialization;
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_t mutex;
#endif
#endif
  char plugin_name[128];
  void (*_init_plugin)(struct _weaver_struct *);
  void (*_fini_plugin)(struct _weaver_struct *);
  void (*_run_plugin)(struct _weaver_struct *);
  void (*_enable_plugin)(struct _weaver_struct *);
  void (*_disable_plugin)(struct _weaver_struct *);
  void *plugin_data;
  bool enabled, defined;
};
@

As primeiras variáveis dentro dele são usadas somente se estivermos
compilando um programa executável. Neste caso carregaremos os plugins
dinamicamente por meio de funções como |dlopen|. A primeira delas é o
nome do arquivo onde está o \italico{plugin}, o qual é um biblioteca
compartilhada. O segundo será o seu \italico{handle} retornado por
|dlopen|. E o |id| na verdade será o INODE do arquivo. Um valor único
para ele que mudará toda vez que o arquivo for modificado. Assim
saberemos quando o nosso \italico{plugin} sofreu alguma mudança
durante sua execução, mesmo que o novo \italico{plugin} tenha sido
criado exatamente ao mesmo tempo que o antigo. O nosso comportamento
esperado será então abandonar o \italico{plugin} antigo e chamar o
novo.

Se estamos executando mais de uma \italico{thread}, é importante
termos um mutex. Afinal, não queremos que alguém tente ativar ou
desativar o mesmo \italico{plugin} simultaneamente e nem que faça isso
enquanto ele está sendo recarregado após ser modificado.

A variável |plugin_name| conterá o nome do plugin.

As próximas 5 variáveis são ponteiros para as funções que
o \italico{plugin} define conforme listado acima. E por último, há
|plugin_data| e |defined|. Elas são inicializadas assim que o programa
é executado como |NULL| e $0$. O |defined| armazena se este é
realmente um \italico{plugin} existente ou apenas um espaço alocado
para futuramente armazenarmos um \italico{plugin}.  O |plugin_data| é
um ponteiro que nunca mudaremos. O espaço é reservado para o
próprio \italico{plugin} modificar e atribuir como achar melhor. Desta
forma, ele tem uma forma de se comunicar com o programa principal.

A próxima função interna será responsável por inicializar
um \italico{plugin} específico passando como argumento o seu caminho:

@<Declarações de Plugins@>+=
#if W_TARGET == W_ELF
void _initialize_plugin(struct _plugin_data *data, char *path);
#endif
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
void _initialize_plugin(struct _plugin_data *data, char *path){
  struct stat attr;
  char *p, buffer[256];
  size_t plugin_name_length = strlen(data -> plugin_name);
  int i;
#ifdef W_PREVENT_SELF_ENABLING_PLUGINS
  data -> finished_initialization = false;
#endif
#if W_DEBUG_LEVEL >= 1
  if(strlen(path) >= 128){
    fprintf(stderr, "ERROR: Plugin path bigger than 255 characters: %s\n",
            path);
    return;
  }
#endif
  strncpy(data -> library, path, 255);
  // A biblioteca é carregada agora. Pode ser tentador tentar usar a
  // flag RTLD_NODELETE para que nossos plugins tornem-se capazes de
  // suportar variáveis globais estáticas, mas se fizermos isso,
  // perderemos a capacidade de modificá-los enquanto o programa está
  // em execução.
  data -> handle = dlopen(data -> library, RTLD_NOW);
  if (!(data -> handle)){
    fprintf(stderr, "%s\n", dlerror());
    return;
  }
  dlerror(); // Limpa qualquer mensagem de erro existente
  if(stat(data -> library, &attr) == -1){
    perror("_initialize_plugin:");
    return;
  }
  data -> id = attr.st_ino; // Obtém id do arquivo
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&(data -> mutex), NULL) != 0){
    perror("_initialize_plugin:");
    return;
  }
#endif
  p = basename(data -> library);
  for(i = 0; *p != '.'; i ++){
    if(i > 127){
      fprintf(stderr, "ERROR: Plugin name bigger than 127 characters: %s\n",
              path);
      return;
    }
    data -> plugin_name[i] = *p;
    p ++;
  }
  data -> plugin_name[i] = '\0'; // Armazenado nome do plugin
  // Obtendo nome de _init_plugin_PLUGINNAME e a obtendo:
  // buffer: 256 de tamanho, data -> plugin_name tem no máximo 128
  memcpy(buffer, "_init_plugin_", 14);
  memcpy(&buffer[13], data -> plugin_name, plugin_name_length + 1);
  data -> _init_plugin = dlsym(data -> handle, buffer);
  if(data -> _init_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _fini_plugin_PLUGINNAME:
  memcpy(buffer, "_fini_plugin_", 14);
  memcpy(&buffer[13], data -> plugin_name, plugin_name_length + 1);
  data -> _fini_plugin = dlsym(data -> handle, buffer);
  if(data -> _fini_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _run_plugin_PLUGINNAME:
  memcpy(buffer, "_run_plugin_", 13);
  memcpy(&buffer[12], data -> plugin_name, plugin_name_length + 1);
  data -> _run_plugin = dlsym(data -> handle, buffer);
  if(data -> _run_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _enable_PLUGINNAME:
  memcpy(buffer, "_enable_plugin_", 16);
  memcpy(&buffer[15], data -> plugin_name, plugin_name_length + 1);
  data -> _enable_plugin = dlsym(data -> handle, buffer);
  if(data -> _enable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _disable_PLUGINNAME:
  memcpy(buffer, "_disable_plugin_", 17);
  memcpy(&buffer[16], data -> plugin_name, plugin_name_length + 1);
  data -> _disable_plugin = dlsym(data -> handle, buffer);
  if(data -> _disable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // As últimas variáveis. O 'defined' deve ser a última. Ela atesta
  // que já temos um plugin com dados válidos. Executamos a função de
  // inicialização do plugin só depois de o marcarmos como definido
  // para que funções de inicialização de plugins possam obter e usar
  // dados sobre o próprio plugin em que estão.
  data -> plugin_data = NULL;
  data -> enabled = false;
  data -> defined = true;
  if(data -> _init_plugin != NULL)
    data -> _init_plugin(&W);
#ifdef W_PREVENT_SELF_ENABLING_PLUGINS
  data -> finished_initialization = true;
#endif
#if W_DEBUG_LEVEL >= 3
  fprintf(stderr, "WARNING (3): New plugin loaded: %s.\n", data -> plugin_name);
#endif
}
#endif
@

É uma função grande devido à quantidade de coisas que fazemos e à
checagem de erro inerente à cada uma delas. A maior parte dos erros
faz com que tenhamos que desistir de inicializar o \italico{plugin}
devido à ele não atender à requisitos. No caso dele não definir as
funções que deveria, podemos continuar, mas é importante que
sinalizemos o erro. A existência dele irá impedir que consigamos gerar
uma versão funcional quando compilamos usando Emscripten. Mas não
impede de continuarmos mantendo o \italico{plugin} quando somos um
executável C. Basta não usarmos a função não-definida. De qualquer
forma, isso provavelmente indica um erro. A função pode ter sido
definida com o nome errado.

O uso da macro |RTLD_NODELETE| faz com que este código só funcione em
versões do glibc maiores ou iguais à 2.2. Atualmente nenhuma das 10
maiores distribuições Linux suporta versões da biblioteca mais antigas
que isso. E nem deveriam, pois existem vulnerabilidades críticas
existentes em tais versões.

Assim como temos uma função auxiliar para inicializar um plugin, vamos
ao código para finalizá-lo, o qual é executado na finalização do
programa em todos os \italico{plugins}:

@<Declarações de Plugins@>+=
#if W_TARGET == W_ELF
void _finalize_plugin(struct _plugin_data *data);
#endif
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
void _finalize_plugin(struct _plugin_data *data){
  // Tornamos inválido o plugin:
  data -> defined = false;
  // Começamos chamando a função de finalização:
  if(data -> _fini_plugin != NULL)
    data -> _fini_plugin(&W);
  // Destruimos o mutex:
#ifdef W_MULTITHREAD
  if(pthread_mutex_destroy(&(data -> mutex)) != 0)
    fprintf(stderr, "ERROR: Finalizing plugin %s: couldn't destroy mutex.",
	    data -> plugin_name);
#endif
  // Nos desligando do plugin
  if(dlclose(data -> handle) != 0)
    fprintf(stderr, "Error unlinking plugin %s: %s\n", data -> plugin_name,
      dlerror());
#if W_DEBUG_LEVEL >= 3
  fprintf(stderr, "WARNING (3): Plugin finalized: %s.\n", data -> plugin_name);
#endif
}
#endif
@

A função de finalizar um \italico{plugin} pode ser chamada na
finalização do programa, caso queiramos recarregar um \italico{plugin}
ou se o \italico{plugin} foi apagado durante a execução do programa.

Mas existe uma outra ação que podemos querer fazer: recarregar
o \italico{plugin}. Isso ocorreria caso nós detectássemos que o
arquivo do \italico{plugin} sofreu algum tipo de modificação. Neste
caso, o que fazemos é semelhante a finalizá-lo e inicializá-lo
novamente. A diferença é que o \italico{plugin} continua válido
durante todo o tempo, apenas tem o seu mutex bloqueado caso
alguma \italico{thread} queira usar ele neste exato momento:

@<Declarações de Plugins@>+=
bool _reload_plugin(int plugin_id);
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
bool _reload_plugin(int plugin_id){
  char buffer[256];
  struct stat attr;
  struct _plugin_data *data = &(_plugins[plugin_id]);
  size_t string_length, plugin_name_length = strlen(data -> plugin_name);
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(data -> mutex));
#endif
  // Primeiro vamos ver se realmente precisamos fazer algo. O plugin
  // pode não ter mudado, então nada precisaria ser feito com ele. Ele
  // já está corretamente carregado:
  if(stat(_plugins[plugin_id].library, &attr) == -1){
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(data -> mutex));
#endif
    return false; // Não conseguimos ler informação sobre o arquivo do plugin.
  }               // Vamos apenas torcer para que tudo acabe bem.
  if(data -> id == attr.st_ino){
    // Plugin não-modificado. Ele já está certo!
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(data -> mutex));
#endif
    return true;
  }
  // O plugin foi modificado!
  data -> id = attr.st_ino;
  //  Removemos o plugin carregado
  if(dlclose(data -> handle) != 0){
    fprintf(stderr, "Error unlinking plugin %s: %s\n", data -> plugin_name,
      dlerror());
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(data -> mutex));
#endif
    return false;
  }
  // E o abrimos novamente
  data -> handle = dlopen(data -> library, RTLD_NOW);
  if (!(data -> handle)){
    fprintf(stderr, "%s\n", dlerror());
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(data -> mutex));
#endif
    return false;
  }
  dlerror(); // Limpa qualquer mensagem de erro existente
  // Agora temos que obter novos ponteiros para as funções do plugin
  // Obtendo nome de _init_plugin_PLUGINNAME e a obtendo:
  string_length = 13;
  memcpy(buffer, "_init_plugin_", string_length + 1);
  memcpy(&buffer[13], data -> plugin_name, plugin_name_length + 1);
  data -> _init_plugin = dlsym(data -> handle, buffer);
  if(data -> _init_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _init_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _fini_plugin_PLUGINNAME:
  string_length = 13;
  memcpy(buffer, "_fini_plugin_", string_length + 1);
  memcpy(&buffer[13], data -> plugin_name, plugin_name_length + 1);
  data -> _fini_plugin = dlsym(data -> handle, buffer);
  if(data -> _fini_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _fini_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _run_plugin_PLUGINNAME:
  string_length = 12;
  memcpy(buffer, "_run_plugin_", string_length + 1);
  memcpy(&buffer[12], data -> plugin_name, plugin_name_length + 1);
  data -> _run_plugin = dlsym(data -> handle, buffer);
  if(data -> _run_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _run_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _enable_PLUGINNAME:
  string_length = 15;
  memcpy(buffer, "_enable_plugin_", string_length + 1);
  memcpy(&buffer[15], data -> plugin_name, plugin_name_length + 1);
  data -> _enable_plugin = dlsym(data -> handle, buffer);
  if(data -> _enable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _enable_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _disable_PLUGINNAME:
  string_length = 16;
  memcpy(buffer, "_disable_plugin_", string_length + 1);
  memcpy(&buffer[16], data -> plugin_name, plugin_name_length + 1);
  data -> _disable_plugin = dlsym(data -> handle, buffer);
  if(data -> _disable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _disable_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(data -> mutex));
#endif
#if W_DEBUG_LEVEL >= 3
  fprintf(stderr, "WARNING (3): New plugin reloaded: %s.\n",
          data -> plugin_name);
#endif
  return true;
}
#endif
@

A função de recarregar \italico{plugins} é suficientemente útil para
que desejemos exportá-la na estrutura |W|:

@<Funções Weaver@>+=
bool (*reload_plugin)(int);
@

@<API Weaver: Inicialização@>+=
W.reload_plugin = &_reload_plugin;
@

No caso de Emscripten, não temos como recarregar dinamicamente um
plugin. Então esta função não fará nada, apenas retornará verdadeiro:

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_WEB
bool _reload_plugin(int plugin_id){
  return (bool) (plugin_id + 1);
}
#endif
@

@*1 Listas de Plugins.

Não é apenas um \italico{plugin} que precisamos suportar. É um número
desconhecido deles. Para saber quantos, precisamos checar o número de
arquivos não-ocultos presentes nos diretórios indicados por
|W_PLUGIN_PATH|. Mas além deles, pode ser que novos \italico{plugins}
sejam jogados em tais diretórios durante a execução. Por isso,
precisamos de um espaço adicional para comportar
novos \italico{plugins}. Não podemos deixar muito espaço ou vamos ter
que percorrer uma lista muito grande de espaços vazios só para er se
há algum \italico{plugin} ativo lá. Mas se deixarmos pouco ou nenhum,
novos \italico{plugins} não poderão ser adicionados durane a
execução. Nosso gerenciador de memória deliberadamente não aceita
realocações.

A solução será observar durante a inicialização do programa
quantos \italico{plugins} existem no momento. Em seguida, alocamos
espaço para eles e mais 25. Se um número maior de \italico{plugins}
for instalado, imprimiremos uma mensagem na tela avisando que parra
poder ativar todos eles será necessário reiniciar o programa. Como
ainda não temos casos de uso desta funcionalidade
de \italico{plugins}, isso parece ser o suficiente no momento.

O ponteiro para o vetor de \italico{plugins} será declarado como:

@<Declarações de Plugins@>+=
struct _plugin_data *_plugins;
int _max_number_of_plugins;
#ifdef W_MULTITHREAD
  pthread_mutex_t _plugin_mutex;
#endif
@

E iremos inicializar a estutura desta forma na inicialização. É
importante que os \italico{plugins} sejam a última coisa a ser
inicializada no programa para que suas funções |_init_plugin| já sejam
capazes de usar todas as funções existentes na API:

@<API Weaver: Últimas Inicializações@>+=
#if W_TARGET == W_ELF
{
  int i = 0;
  if(strcmp(W_PLUGIN_PATH, "")){ // Teste para saber se plugins são suportados
    char *begin = W_PLUGIN_PATH, *end = W_PLUGIN_PATH;
    char dir[256]; // Nome de diretório
    DIR *directory;
    struct dirent *dp;
    _max_number_of_plugins = 0;
    while(*end != '\0'){
      end ++;
      while(*end != ':' && *end != '\0') end ++;
      // begin e end agora marcam os limites do caminho de um diretório
      if(end - begin > 255){
        fprintf(stderr, "ERROR: Path too big in W_PLUGIN_PATH.\n");
        begin = end + 1;
        continue; // Erro: vamos para o próximo diretório
      }
      strncpy(dir, begin, (size_t) (end - begin));
      dir[(end - begin)] = '\0';
      // dir agora possui o nome do diretório que devemos checar
      directory = opendir(dir);
      if(directory == NULL){
#if W_DEBUG_LEVEL >= 2
        fprintf(stderr, "WARNING (2): Trying to access plugin directory %s: "
                        "%s\n", dir, strerror(errno));
#endif
        // Em caso de erro, desistimos deste diretório e tentamos ir
        // para o outro:
        begin = end + 1;
        continue;
      }
      // Se não houve erro, iteramos sobre os arquivos do diretório
      while ((dp = readdir(directory)) != NULL){
        if(dp -> d_name[0] != '.' && dp -> d_type == DT_REG)
          _max_number_of_plugins ++; // Só levamos em conta arquivos
                                     // regulares não-ocultos
      }
      // E preparamos o próximo diretório para a próxima iteração:
      begin = end + 1;
    }
    // Fim do loop. Já sabemos quantos plugins são.
    @<Plugins: Inicialização@>
  }
}
#endif
@

Tudo isso foi só para sabermos o número de \italico{plugins} durante a
inicialização. Ainda não inicializamos nada. Isso só podemos enfim
fazer de posse deste número, o qual está na variável |_max_number_of_plugins|:

@<Plugins: Inicialização@>=
{
  _max_number_of_plugins += 25;
#if W_DEBUG_LEVEL >= 3
  printf("WARNING (3): Supporting maximum of %d plugins.\n",
         _max_number_of_plugins);
#endif
  _plugins = (struct _plugin_data *) _iWalloc(sizeof(struct _plugin_data) *
               (_max_number_of_plugins));
  if(_plugins == NULL){
    fprintf(stderr, "ERROR (0): Too many plugins. Not enough memory!\n");
    Wexit();
  }
  for(i = 0; i < _max_number_of_plugins; i ++){
    _plugins[i].defined = false;
  }
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_plugin_mutex, NULL) != 0){
    perror("Initializing plugin mutex:");
    Wexit();
  }
#endif
}
@

Agora para inicializar os \italico{plugins} precisamos mais uma vez
percorrer a árvore de diretórios e procurar por cada um dos arquivos
como fizemos na contagem:

@<Plugins: Inicialização@>+=
{
  size_t dir_length, d_name_length;
  begin = end = W_PLUGIN_PATH;
  i = 0;
  while(*end != '\0'){
    end ++;
    while(*end != ':' && *end != '\0') end ++;
    // begin e end agora marcam os limites do caminho de um diretório
    if(end - begin > 255){
      // Ignoramos caminho grande demais, o aviso disso já foi dado
      // quando contamos o número de plugins
      begin = end + 1;
      continue;
    }
    strncpy(dir, begin, (size_t) (end - begin));
    dir[(end - begin)] = '\0';
    dir_length = (end - begin);
    // dir agora possui o nome do diretório que devemos checar
    directory = opendir(dir);
    if(directory == NULL){
      // Em caso de erro, desistimos deste diretório e tentamos ir
      // para o outro. Não precia imprimir mensagem de erro
      // independente do nível de depuração, pois já imprimimos quando
      // estávamos contando o número de plugins
      begin = end + 1;
      continue;
    }
    // Se não houve erro, iteramos sobre os arquivos do diretório
    while ((dp = readdir(directory)) != NULL){
      if(dp -> d_name[0] != '.' && dp -> d_type == DT_REG){
	d_name_length = strlen(dp -> d_name);
        if(dir_length + 1 + d_name_length > 255){
          fprintf(stderr, "Ignoring plugin with too long path: %s/%s.\n",
                  dir, dp -> d_name);
          continue;
        }
        if(i >= _max_number_of_plugins){
          fprintf(stderr, "Ignoring plugin %s/%s, not prepared for so much "
                  "new plugins being added.\n", dir, dp -> d_name);
          continue;
        }
	memcpy(&dir[dir_length], "/", 2);
	memcpy(&dir[dir_length + 1], dp -> d_name, d_name_length + 1);
        _initialize_plugin(&(_plugins[i]), dir);
        i ++;
      }
    }
    // E preparamos o próximo diretório para a próxima iteração:
    begin = end + 1;
  }
}
@

Da mesma forma que no começo do programa criamos e preenchemos esta
estrutura,no seu encerramento iremos precisar finalizá-la fechando a
ligação com o \italico{plugin} e destruindo o que existe de mutex:

@<API Weaver: Encerramento@>=
#if W_TARGET == W_ELF
{
  int j;
  for(j = 0; j < _max_number_of_plugins; j ++)
    if(_plugins[j].defined)
      _finalize_plugin(&(_plugins[j]));
}
#endif
@

Próximo passo: checar se um \italico{plugin} existe ou não. Esta é a
hora de definir a função |W.get_plugin| que retorna um número de
identificação único para cada ID. Tal número nada mas será do que a
posição que o \italico{plugin} ocupa no vetor de \italico{plugins}. E
se o \italico{plugin} pedido não existir, a função retornará -1:

@<Declarações de Plugins@>+=
int _Wget_plugin(char *plugin_name);
@

@(project/src/weaver/plugins.c@>+=
int _Wget_plugin(char *plugin_name){
  int i;
  for(i = 0; i < _max_number_of_plugins; i ++)
    if(!strcmp(plugin_name, _plugins[i].plugin_name))
      return i;
  return -1; // Caso em que não foi encontrado
}
@

Agora adicionamos a função à estrutura |W|:

@<Funções Weaver@>+=
int (*get_plugin)(char *);
@

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
W.get_plugin = &_Wget_plugin;
#endif
@


Mas e para checar se algum \italico{plugin} foi modificado ou se
existe um novo \italico{plugin} colocado em algum dos diretórios?
Novamente teremos que usar o código de percorrer os diretórios
procurando por arquivos. Iremos então colocar isso dentro de uma
função que será executada imediatamente antes de todo \italico{loop}
principal:

@<Declarações de Plugins@>+=
void _reload_all_plugins(void);
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
void _reload_all_plugins(void){
  if(strcmp(W_PLUGIN_PATH, "")){ // Teste para saber se plugins são suportados
#ifdef W_MULTITHREAD// Potencialmente modificamos a lista de plugins aqui
    pthread_mutex_lock(&(_plugin_mutex));
#endif
    char *begin = W_PLUGIN_PATH, *end = W_PLUGIN_PATH;
    char dir[256]; // Nome de diretório
    DIR *directory;
    size_t dir_length, d_name_length;
    struct dirent *dp;
    while(*end != '\0'){
      end ++;
      while(*end != ':' && *end != '\0') end ++;
      // begin e end agora marcam os limites do caminho de um diretório
      if(end - begin > 255){
        // Caminho gtrande demais, ignoramos
        begin = end + 1;
        continue; // Erro: vamos para o próximo diretório
      }
      strncpy(dir, begin, (size_t) (end - begin));
      dir[(end - begin)] = '\0';
      dir_length = (end - begin);
      // dir agora possui o nome do diretório que devemos checar
      directory = opendir(dir);
      if(directory == NULL){
        // Em caso de erro, desistimos deste diretório e tentamos ir
        // para o outro sem aviso (possivelmente já devemos ter dado o
        // aviso do erro na inicialização e não vamos ficar repetindo):
        begin = end + 1;
        continue;
      }
      // Se não houve erro, iteramos sobre os arquivos do diretório
      while ((dp = readdir(directory)) != NULL){
        if(dp -> d_name[0] != '.' && dp -> d_type == DT_REG){
          char buffer[128];
          int id, i;
          strncpy(buffer, dp -> d_name, 128);
          buffer[127] = '\0';
          for(i = 0; buffer[i] != '.' && buffer[i] != '\0'; i ++);
          buffer[i] = '\0'; // Nome do plugin obtido
          id = W.get_plugin(buffer);
          if(id != -1){
            if(!W.reload_plugin(id)){
              _plugins[id].defined = false; // Falhamos em recarregá-lo, vamos
                                            // desistir dele por hora
            }
          }
          else{
            // É um novo plugin que não existia antes!
	    d_name_length = strlen(dp -> d_name);
            if(dir_length + 1 + d_name_length > 255){
              fprintf(stderr, "Ignoring plugin with too long path: %s/%s.\n",
                      dir, dp -> d_name);
              continue;
            }
	    memcpy(&dir[dir_length], "/", 2);
	    memcpy(&dir[dir_length + 1], dp -> d_name, d_name_length);
            for(i = 0; i < _max_number_of_plugins; i ++){
              if(_plugins[i].defined == false){
                _initialize_plugin(&(_plugins[i]), dir);
                break;
              }
            }
            if(i == _max_number_of_plugins){
              fprintf(stderr, "WARNING (0): Maximum number of plugins achieved."
                      " Couldn't load %s.\n", buffer);
            }
          }
        }
      }
      // E preparamos o próximo diretório para a próxima iteração:
      begin = end + 1;
    } // Fim do loop, passamos por todos os diretórios.
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(_plugin_mutex));
#endif
  }
}
#endif
@

A função de recarregar todos os \italico{plugins} é suficientemente
importante para que um usuário possa querer usar por conta
própria. Por exemplo, quando se está usando programação interativa é
interessante ficar recarregando todos os \italico{plugins}
periodicamente para poder ver as mudanças feitas no código
rapidamente. Por isso colocaremos a função dentro de |W|:

@<Funções Weaver@>+=
void (*reload_all_plugins)(void);
@

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
W.reload_all_plugins = &_reload_all_plugins;
#endif
@

E iremos também invocar esta função automaticamente antes de cada loop
principal:

@<Código Imediatamente antes de Loop Principal@>=
#if W_TARGET == W_ELF
  W.reload_all_plugins();
#endif
@

Caso esejamos em Emscripten, a função de recarregar plugins meramente
será ignorada:

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_WEB
void _reload_all_plugins(void){
  return;
}
#endif
@

E finalmente, durante a execução do \italico{loop} principal iremos
executar a função de cada \italico{plugin} associada à execução
contínua:

@<Código a executar todo loop@>+=
{
  int i;
  for(i = 0; i < _max_number_of_plugins; i ++)
    if(_plugins[i].defined && _plugins[i].enabled)
      _plugins[i]._run_plugin(&W);
}
@

@*1 Listas de Plugins em ambiente Emscripten.

Caso estejamos compilando para Javascript, tudo muda. Não temos mais
acesso à funções como |dlopen|. Não há como executar código em C
dinamicamente. Só códigos Javascript, o que não iremos suportar. Mas
como então fazer com que possamos tratar a lista de plugins de forma
análoga?

Para começar, precisamos saber quantos plugins são. Mas não iremos
checar os plugins compilados, mas sim o código deles que iremos
injetar estaticamene. Sendo assim, o próprio Makefile do projeto pode
nos informar facilmente o número por meio de uma macro
|_W_NUMBER_OF_PLUGINS|. De posse deste número, podemos inicializar a
lista de plugins com o número correto deles, que não irá aumentar e
nem diminuir, pois não podemos adicioná-los ou removê-los
dinamicamente.

De posse deste número, podemos começar alocando o número correto de
plugins na nossa lista:

@<API Weaver: Últimas Inicializações@>+=
#if W_TARGET == W_WEB
{
_max_number_of_plugins = _W_NUMBER_OF_PLUGINS;
_plugins = (struct _plugin_data *) Walloc(sizeof(struct _plugin_data) *
              _max_number_of_plugins);
#include "../../.hidden_code/initialize_plugin.c"
}
#endif
@

A grande novidade que temos no código acima é o |#include|. Ele irá
inserir o código de inicialização de cada plugin que sejá gerado pelo
Makefile no momento da compilação.

Não nos esqueçamos de desalocar a memória locada para os plugins:

@<API Weaver: Encerramento@>+=
#if W_TARGET == W_WEB
Wfree(_plugins);
#endif
@

Além desta inclusão iremos inserir também o seguinte cabeçalho gerado
pelo Makefile durante a compilação e que tem todas as funções
definidas em cada plugin:

@<Cabeçalhos Gerais Dependentes da Estrutura Global@>+=
#if W_TARGET == W_WEB
#include "../../.hidden_code/header.h"
#endif
@

E da mesma forma que inicializmaos todos os plugins, teremos depois
que encerrá-los na finalização. Isso será mais fácil que a finalização
fora do Emscripten:

@<API Weaver: Encerramento@>+=
#if W_TARGET == W_WEB
{
  int i;
  for(i = 0; i < _max_number_of_plugins; i ++)
    _plugins[i]._fini_plugin(&W);
}
#endif
@

@*1 Um Agendador de Funções.

Mas e se estamos desenvolvendo o jogo e queremos invocar então
|W.reload_all_plugins| uma vez a cada segundo para podermos usar
programação interativa de uma forma mais automática e assim o nosso
jogo em execução se atualize automaticamente à medida que recompilamos
o código? Será interessante termos para isso uma função tal como
\monoespaco{W.run\_periodically( W.reload\_all\_plugins, 1.0)}, que
faz com que a função passada como argumento seja executada uma vez a
cada 1 segundo. Alternativamente também pode ser útil uma função
\monoespaco{W.run\_futurelly( W.reload\_all\_plugins, 1.0)} que
execute a função passada como argumento após 1 segundo, mas depois não
a executa mais.

Cada subloop deve ter então uma lista de funções agendadas para serem
executadas. E podemos estipular em |W_MAX_SCHEDULING| o número máximo
delas. Então podemos usar uma estrutura como esta para armazenar
funções agendadas e ela deve ter um mutex para que diferentes threads
possam usar o agendador:

@<Cabeçalhos Weaver@>=
#ifdef W_MULTITHREAD
pthread_mutex_t _scheduler_mutex;
#endif
struct{
  bool periodic; // A função é periódica ou será executada só uma vez?
  unsigned long last_execution; // Quando foi executada pela última vez
  unsigned long period; // De quanto em quanto tempo tem que executar
  void (*f)(void); // A função em si a ser executada
} _scheduled_functions[W_MAX_SUBLOOP][W_MAX_SCHEDULING];
@

Isso precisa ser inicializado criando o mutex e preenchendo os valores
de cada |f| com |NULL| para marcarmos cada posição como vazia:

@<API Weaver: Inicialização@>+=
{
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_scheduler_mutex, NULL) != 0){ // Inicializa mutex
    perror(NULL);
    exit(1);
  }
#endif
  int i, j;
  for(i = 0; i < W_MAX_SUBLOOP; i ++)
    for(j = 0; j < W_MAX_SCHEDULING; j ++) // Marca posição na agenda como vazia
      _scheduled_functions[i][j].f = NULL;
}
@

E no fim não esqueçamos de destruir o mutex:

@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
  pthread_mutex_destroy(&_scheduler_mutex);
#endif
@

E imediatamente antes de entrarmos em um novo loop, devemos limpar
também todas as funções periódicas associadas ao loop em que
estávamos. Mas não faremos isso no caso de um subloop, pois depois que
o subloop termina, ainda podemos voltar ao loop atual e retomar a
execução de suas funções periódicas:

@<Código antes de Loop, mas não de Subloop@>=
{
  int i;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++)
    _scheduled_functions[_number_of_loops][i].f = NULL;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
}
@

Além disso, quando encerramos um Subloop, também é necessário
limparmos as suas funções periódicas para que elas acabem não sendo
executadas novamente em outros subloops diferentes:

@<Código após sairmos de Subloop@>=
{
  int i;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++)
    _scheduled_functions[_number_of_loops][i].f = NULL;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
}
@

E toda iteração de loop principal temos que atualizar os valores de
marcação de tempo de cada função e, se estiver na hora, devemos
executá-las:

@<Código a executar todo loop@>+=
{
  int i;
  void (*f)(void);
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++){
    if(_scheduled_functions[_number_of_loops][i].f == NULL)
      break;
    if(_scheduled_functions[_number_of_loops][i].period <
      W.t - _scheduled_functions[_number_of_loops][i].last_execution){
      f = _scheduled_functions[_number_of_loops][i].f;
      if(!_scheduled_functions[_number_of_loops][i].periodic){
          int j;
          _scheduled_functions[_number_of_loops][i].f = NULL;
          for(j = i + 1; j < W_MAX_SCHEDULING; j ++){
              _scheduled_functions[_number_of_loops][j - 1].periodic =
                  _scheduled_functions[_number_of_loops][j].periodic;
              _scheduled_functions[_number_of_loops][j - 1].last_execution =
                  _scheduled_functions[_number_of_loops][j].last_execution;
              _scheduled_functions[_number_of_loops][j - 1].period =
                  _scheduled_functions[_number_of_loops][j].period;
              _scheduled_functions[_number_of_loops][j - 1].f =
                  _scheduled_functions[_number_of_loops][j].f;
          }
          _scheduled_functions[_number_of_loops][W_MAX_SCHEDULING - 1].f = NULL;
          i --;
      }
      else
          _scheduled_functions[_number_of_loops][i].last_execution = W.t;
      f();
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
}
@

E finalmente funções para interagir com código executado periodicamente:

@<Cabeçalhos Weaver@>+=
void _run_periodically(void (*f)(void), float t); // Torna uma função periódica
void _run_futurelly(void (*f)(void), float t); // Executa ela 1x no futuro
float _cancel(void (*f)(void));  // Cancela uma função agendada
float _period(void (*f)(void));  // Obém o período de uma função agendada
@

Todas elas interagem sempre com as listas de funções agendadas do loop
atual.

A função que adiciona uma nova função periódica segue abaixo. Ela tem
que se preocupar também caso o espaço para se colocar uma nova função
no agendador tenha se esgotado. Passar para ela uma função que já é
periódica atualiza o seu período.

@<API Weaver: Definições@>+=
void _run_periodically(void (*f)(void), float t){
  int i;
  unsigned long period = (unsigned long) (t * 1000000);
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++){
    if(_scheduled_functions[_number_of_loops][i].f == NULL ||
       _scheduled_functions[_number_of_loops][i].f == f){
      _scheduled_functions[_number_of_loops][i].f = f;
      _scheduled_functions[_number_of_loops][i].period = period;
      _scheduled_functions[_number_of_loops][i].periodic = true;
      _scheduled_functions[_number_of_loops][i].last_execution = W.t;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
  if(i == W_MAX_SCHEDULING){
    fprintf(stderr, "ERROR (1): Can't schedule more functions.");
    fprintf(stderr, "Please, define W_MAX_SCHEDULING in conf/conf.h "
            "with a value bigger than the current %d.\n",
            W_MAX_SCHEDULING);
  }
}
@

Agora o código para fazer com que uma função seja executada pelo
agendador somente uma vez. Ela é idêntica, apenas ajustando a variável
|periodic| para um valor falso:

@<API Weaver: Definições@>+=
void _run_futurelly(void (*f)(void), float t){
  int i;
  unsigned long period = (unsigned long) (t * 1000000);
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++){
    if(_scheduled_functions[_number_of_loops][i].f == NULL ||
       _scheduled_functions[_number_of_loops][i].f == f){
      _scheduled_functions[_number_of_loops][i].f = f;
      _scheduled_functions[_number_of_loops][i].period = period;
      _scheduled_functions[_number_of_loops][i].periodic = false;
      _scheduled_functions[_number_of_loops][i].last_execution = W.t;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
  if(i == W_MAX_SCHEDULING){
    fprintf(stderr, "ERROR (1): Can't schedule more functions.");
    fprintf(stderr, "Please, define W_MAX_SCHEDULING in conf/conf.h "
            "with a value bigger than the current %d.\n",
            W_MAX_SCHEDULING);
  }
}
@

Para remover uma função do agendador, podemos usar a função
abaixo. Ela retorna quanto tempo faltava para a próxima execução da
função agendada se ela não tivesse sido cancelada. Chamá-la para uma
função que não está agendada deve ser inócuo e deve retornar infinito.

@<API Weaver: Definições@>+=
float _cancel(void (*f)(void)){
  int i;
  unsigned long period, last_execution;
  float return_value = NAN;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++){
    if(_scheduled_functions[_number_of_loops][i].f == f){
      period = _scheduled_functions[_number_of_loops][i].period;
      last_execution = _scheduled_functions[_number_of_loops][i].last_execution;
      return_value = ((float) (period - (W.t - last_execution))) / 1000000.0;
      for(; i < W_MAX_SCHEDULING - 1; i ++){
        _scheduled_functions[_number_of_loops][i].f =
                                  _scheduled_functions[_number_of_loops][i+1].f;
        _scheduled_functions[_number_of_loops][i].period =
                             _scheduled_functions[_number_of_loops][i+1].period;
        _scheduled_functions[_number_of_loops][i].last_execution =
                     _scheduled_functions[_number_of_loops][i+1].last_execution;
      }
      _scheduled_functions[_number_of_loops][i].f = NULL;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_scheduler_mutex);
#endif
  return return_value;
}
@

Por fim, pode ser importante checar se uma função é periódica ou não e
obter o seu período. A função abaixo retorna o período de uma função
periódica. Vamos definir o período de uma função agendada para
executar somente uma vez como sendo infinito. E o período de uma
função que não está agendada como sendo NaN.

@<API Weaver: Definições@>+=
float _period(void (*f)(void)){
  int i;
  float result = -1.0;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  for(i = 0; i < W_MAX_SCHEDULING; i ++)
    if(_scheduled_functions[_number_of_loops][i].f == f){
      if(_scheduled_functions[_number_of_loops][i].periodic == true)
        result =  (float) (_scheduled_functions[_number_of_loops][i].period) /
          1000000.0;
      else
        result = INFINITY;
    }
  if(result < 0.0)
    result =  NAN;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_scheduler_mutex);
#endif
  return result;
}
@

E finalmente colocamos tudo isso dentro da estrutura |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
void (*run_periodically)(void (*f)(void), float);
void (*run_futurelly)(void (*f)(void), float);
float (*cancel)(void (*f)(void));
float (*period)(void (*f)(void));
@

@<API Weaver: Inicialização@>=
W.run_periodically = &_run_periodically;
W.run_futurelly = &_run_futurelly;
W.cancel = &_cancel;
W.period = &_period;
@

@*1 Funções de Interação com Plugins.

Já vimos que podemos obter um número de identificação
do \italico{plugin} com |W.get_plugin|. Vamos agora ver o que podemos
fazer com tal número de identificação. Primeiro podemos ativar e
desativar um \italico{plugin}, bem como checar se ele está ativado ou
desativado:

@<Declarações de Plugins@>+=
bool _Wenable_plugin(int plugin_id);
bool _Wdisable_plugin(int plugin_id);
bool _Wis_enabled(int plugin_id);
@

@(project/src/weaver/plugins.c@>+=
bool _Wenable_plugin(int plugin_id){
#ifdef W_PREVENT_SELF_ENABLING_PLUGINS
    if(_plugins[plugin_id].finished_initialization == false)
      return false;
#endif
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(_plugins[plugin_id].mutex));
#endif
  if(!_plugins[plugin_id].enabled){
    _plugins[plugin_id].enabled = true;
    if(_plugins[plugin_id]._enable_plugin != NULL)
      _plugins[plugin_id]._enable_plugin(&W);
#if W_DEBUG_LEVEL >=3
    fprintf(stderr, "WARNING (3): Plugin enabled: %s.\n",
            _plugins[plugin_id].plugin_name);
#endif
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(_plugins[plugin_id].mutex));
#endif
  return true;
}
bool _Wdisable_plugin(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(_plugins[plugin_id].mutex));
#endif
  if(_plugins[plugin_id].enabled){
    if(_plugins[plugin_id]._disable_plugin != NULL)
      _plugins[plugin_id]._disable_plugin(&W);
    _plugins[plugin_id].enabled = false;
#if W_DEBUG_LEVEL >=3
    fprintf(stderr, "WARNING (3): Plugin disabled: %s.\n",
            _plugins[plugin_id].plugin_name);
#endif
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(_plugins[plugin_id].mutex));
#endif
  return true;
}
bool _Wis_enabled(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
  return _plugins[plugin_id].enabled;
}
@

Ativar ou desativar um \italico{plugin} é o que define se ele irá
executar em um \italico{loop} principal ou não.

Tais funções serão colocadas na estrutura |W|:

@<Funções Weaver@>+=
bool (*enable_plugin)(int);
bool (*disable_plugin)(int);
bool (*is_plugin_enabled)(int);
@

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
W.enable_plugin = &_Wenable_plugin;
W.disable_plugin = &_Wdisable_plugin;
W.is_plugin_enabled = &_Wis_enabled;
#endif
@

E agora iremos definir funções para gravar um novo valor no
|plugin_data| de um \italico{plugin}. Qualquer tipo de estrutura de
dados pode ser armazenada ali, pois ela é um ponteiro do tipo |void *|.
Armazenar coisas ali é a única forma que um \italico{plugin} tem
para se comunicar com o programa principal e também é o modo do
programa passar informações personalizadas para \italico{plugins}. O
tipo de informação que será armazenada ali ficará à cargo de quem
projetar cada \italico{plugin}. Muitos \italico{plugins} talvez optem
por ignorá-lo por não terem necessidade de se comunicar com o programa
principal.

@<Declarações de Plugins@>+=
void *_Wget_plugin_data(int plugin_id);
bool _Wset_plugin_data(int plugin_id, void *data);
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
void *_Wget_plugin_data(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return NULL;
  return _plugins[plugin_id].plugin_data;
}
bool _Wset_plugin_data(int plugin_id, void *data){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
  _plugins[plugin_id].plugin_data = data;
  return true;
}
#endif
@

E como de praxe, armazenamos as novas funções em |W|:

@<Funções Weaver@>+=
void *(*get_plugin_data)(int);
bool (*set_plugin_data)(int, void*);
@

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
W.get_plugin_data = &_Wget_plugin_data;
W.set_plugin_data = &_Wset_plugin_data;
#endif
@

@*1 Sumário das Variáveis e Funções referentes à Plugins.

\macronome As seguintes 12 novas funções foram definidas:

\macrovalor|int W.get_plugin(char *)|: Obtém o número de identificação
de um plugin dado o seu nome. Se o plugin não for encontrado, retorna
-1.

\macrovalor|bool W.reload_plugin(int plugin_id)|: Checa se o plugin
indicado pelo seu número de identificação sofreu qualquer alteração
enquanto o programa está em execução. Se for o caso, carregamos as
novas alterações. Ser tudo correr bem, retornamos verdadeiro e se
algum erro ocorrer ao tentar recarregá-lo, retornamos falso.

\macrovalor|void W.reload_all_plugins(void)|: Faz com que todos os
plugins que carregamaos sejam recarregados para refletir qualquer
alteração que possam ter sofrido enquanto o programa está em execução.

\macrovalor|bool enable_plugin(int id)|: Ativa um dado plugin dado o
seu número de identificação. Um plugin ativado tem o seu código
específico executado em cada iteração do loop principal. O ato de
ativar um plugin também pode executar código relevante específico de
cada plugin. Retorna se tudo correu bem na ativação do plugin.

\macrovalor|bool disable_plugin(int id)|: Desativa um plugin dado o
seu número de identificação. Um plugin desaivado deixa de ser
executado todo turno e pode executar código específico dele durante a
desativação.

\macrovalor|bool is_plugin_enabled(int id)|: Dado um plugin
identificado pelo seu número de identificação, retorna se ele está
ativado.

\macrovalor|void *get_plugin_data(int id)|: Dado um plugin
identificado pelo seu número de identificação, retorna o dado
arbitrário que ele pode estar armazenando e que é específico do
plugin. Pode ser |NULL| se não houver dado nenhum armazenado.

\macrovalor|bool set_plugin_data(int id, void *dado)|: Dado um plugin
caracterizado pelo seu número de identificação, armazena nela o dado
arbitrário passado como segundo argumento.

\macrovalor|void W.periodic(void (*f)(void), float p)|: Faz com que no
loop em que estamos, a função |f| seja executada periodicamente a cada
|p| segundos. Se ela já foi passada antes para a mesma função, então
apenas atualizamos o seu valor de |p|.

\macrovalor|void W.nonperiodic(void (*f)(void))|: Faz com que a função
|f| deixe de ser executada periodicamente caso ela tenha sido passada
previamente para |W.periodic|.

\macrovalor|float W.is_periodic(void (*f)(void))|: Retorna o período
de uma função periódica e NaN se a função não for periódica. Como a
ocorrência de um NaN (Not a Number) pode ser testada com a função
|isnan|, então esta é a forma recomendada de descobrir se uma dada
função é periódica ou não.

\macrovalor|float W.cancel(void (*f)(void))|: Cancela uma função
agendada para executar no futuro, seja ela periódica ou não. Retorna o
tempo que faltava para a função ser executada em segundos antes dela
ser cancelada. Se a função não estava agendada, retorna NaN (Not a
Number).
