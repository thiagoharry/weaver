@* Plugins.

Um projeto Weaver pode suportar \italico{plugins}. Mas o que isso
significa depende se o projeto está sendo compilado para ser um
executável ELF ou uma página web.

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

Uma atividade típica que podem ser implementadas via \italico{plugin}
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

\macronome|W_INSTALL_DIR|: O diretório em que o jogo será instalado.

\macronome|W_PLUGIN_PATH|: Uma string com lista de diretórios
separadas por dois pontos (``:''). Se for uma string vazia, isso
significa que o suporte à \italico{plugins} dee ser desativado.

\macronome|W_MAX_PERIODIC_FUNCTIONS|: O número máximo de funções que
executam periodica e automaicamente em cada subloop.

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
  int i;
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
    return false;
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
  buffer[0] = '\0';
  strcat(buffer, "_init_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _init_plugin = dlsym(data -> handle, buffer);
  if(data -> _init_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _fini_plugin_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_fini_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _fini_plugin = dlsym(data -> handle, buffer);
  if(data -> _fini_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _run_plugin_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_run_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _run_plugin = dlsym(data -> handle, buffer);
  if(data -> _run_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _enable_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_enable_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _enable_plugin = dlsym(data -> handle, buffer);
  if(data -> _enable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define %s.\n",
            data -> plugin_name, buffer);
  // Obtendo _disable_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_disable_plugin_");
  strcat(buffer, data -> plugin_name);
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
    perror("Finalizing plugin %s", data -> plugin_name);
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
#if W_TARGET == W_ELF
bool _reload_plugin(int plugin_id);
#endif
@

@(project/src/weaver/plugins.c@>+=
#if W_TARGET == W_ELF
bool _reload_plugin(int plugin_id){
  char buffer[256];
  struct stat attr;
  struct _plugin_data *data = &(_plugins[plugin_id]);
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
    // Plugiin não-modificado. Ele já está certo!
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
  buffer[0] = '\0';
  strcat(buffer, "_init_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _init_plugin = dlsym(data -> handle, buffer);
  if(data -> _init_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _init_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _fini_plugin_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_fini_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _fini_plugin = dlsym(data -> handle, buffer);
  if(data -> _fini_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _fini_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _run_plugin_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_run_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _run_plugin = dlsym(data -> handle, buffer);
  if(data -> _run_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _run_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _enable_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_enable_plugin_");
  strcat(buffer, data -> plugin_name);
  data -> _enable_plugin = dlsym(data -> handle, buffer);
  if(data -> _enable_plugin == NULL)
    fprintf(stderr, "ERROR: Plugin %s doesn't define _enable_plugin_%s.\n",
            data -> plugin_name, data -> plugin_name);
  // Obtendo _disable_PLUGINNAME:
  buffer[0] = '\0';
  strcat(buffer, "_disable_plugin_");
  strcat(buffer, data -> plugin_name);
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
#if W_TARGET == W_ELF
W.reload_plugin = &_reload_plugin;
#endif
@


@*1 Listas de Plugins.

Não é apenas um \italico{plugin} que precisamos suportar. É um número
desconhecido deles. Para sabver quantos, precisamos checar o número de
arquivos não-oultos presentes nos diretórios indicados por
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
#if W_TARGET == W_ELF
struct _plugin_data *_plugins;
int _max_number_of_plugins;
#ifdef W_MULTITHREAD
  pthread_mutex_t _plugin_mutex;
#endif
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
        if(strlen(dir) + 1 + strlen(dp -> d_name) > 255){
          fprintf(stderr, "Ignoring plugin with too long path: %s/%s.\n",
                  dir, dp -> d_name);
          continue;
        }
        if(i >= _max_number_of_plugins){
          fprintf(stderr, "Ignoring plugin %s/%s, not prepared for so much "
                  "new plugins being added.\n", dir, dp -> d_name);
          continue;
        }
        strcat(dir, "/");
        strcat(dir, dp -> d_name);
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
#if W_TARGET == W_ELF
  int i;
  for(i = 0; i < _max_number_of_plugins; i ++)
    if(!strcmp(plugin_name, _plugins[i].plugin_name))
      return i;
#endif
  return -1; // A função deliberadamente só retorn -1 no Emscripten
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
#if W_TARGET == W_ELF
void _reload_all_plugins(void);
#endif
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
            if(strlen(dir) + 1 + strlen(dp -> d_name) > 255){
              fprintf(stderr, "Ignoring plugin with too long path: %s/%s.\n",
                      dir, dp -> d_name);
              continue;
            }
            strcat(dir, "/");
            strcat(dir, dp -> d_name);
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

E finalmente, durante a execução do \italico{loop} principal iremos
executar a função de cada \italico{plugin} associada à execução
contínua:

@<Código a executar todo loop@>+=
#if W_TARGET == W_ELF
{
  int i;
  for(i = 0; i < _max_number_of_plugins; i ++)
    if(_plugins[i].defined && _plugins[i].enabled)
      _plugins[i]._run_plugin(&W);
}
#endif
@

@*1 Adendo: Executando Código Periodicamente.

Mas e se estamos desenvolvendo o jogo e queremos invocar então
|W.reload_all_plugins| uma vez a cada segundo para podermos usar
programação interativa de uma forma mais automática e assim o nosso
jogo em execução se atualize automaticamente à medida que recompilamos
o código? Será interessante termos para isso uma função tal como
|W.periodic(W.reload_all_plugins, 1.0)|, que faz com que a função
passada como argumento seja executada uma vez a cada 1 segundo.

Cada subloop deve ter então uma lista de funções que são executadas
periodicamente. E podemos estipular em |W_MAX_PERIODIC_FUNCTIONS| o
número máximo de funções periódicas que cada subloop pode ter. Então
podemos usar uma estrutura como esta para armazenar unções periódicas:

@<Cabeçalhos Weaver@>=
struct{
  unsigned long last_execution; // Quando foi executada pela última vez
  unsigned long period; // De quanto em quanto tempo tem que executar
  void (*f)(void); // A função em si a ser executada
} _periodic_functions[W_LIMIT_SUBLOOP][W_MAX_PERIODIC_FUNCTIONS];
@

Isso precisa ser inicializado preenchendo os valores de cada |f| com
|NULL| para marcarmos cada posição como vazia:

@<API Weaver: Inicialização@>+=
{
  int i, j;
  for(i = 0; i < W_LIMIT_SUBLOOP; i ++)
    for(j = 0; j < W_MAX_PERIODIC_FUNCTIONS; j ++)
      _periodic_functions[i][j].f = NULL;
}
@

E imediatamente antes de entrarmos em um novo loop, devemos limpar
também todas as funções periódicas associadas ao loop em que
estávamos. Mas não faremos isso no caso de um subloop, pois depois que
o subloop termina, ainda podemos voltar ao loop atual e retomar a
execução de suas funções periódicas:

@<Código antes de Loop, mas não de Subloop@>=
{
  int i;
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++)
    _periodic_functions[_number_of_loops][i].f = NULL;
}
@

Além disso, quando encerramos um Subloop, também é necessário
limparmos as suas funções periódicas para que elas aabem não sendo
executadas novamente em outros subloops diferentes:

@<Código após sairmos de Subloop@>=
{
  int i;
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++)
    _periodic_functions[_number_of_loops][i].f = NULL;
}
@

E toda iteração de loop principal temos que atualizar os valores de
marcação de tempo de cada função e, se estiver na hora, devemos
executá-las:

@<Código a executar todo loop@>+=
{
  int i;
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++){
    if(_periodic_functions[_number_of_loops][i].f == NULL)
      break;
    if(_periodic_functions[_number_of_loops][i].period <
       W.t - _periodic_functions[_number_of_loops][i].last_execution){
      _periodic_functions[_number_of_loops][i].f();
      _periodic_functions[_number_of_loops][i].last_execution = W.t;
    }
  }
}
@

E finalmente funções para interagir com código executado periodicamente:

@<Cabeçalhos Weaver@>+=
void _periodic(void (*f)(void), float t); // Torna uma função periódica
void _nonperiodic(void (*f)(void));  // Faz uma função deixar de ser periódica
bool _is_periodic(void (*f)(void));  // Checa se uma função é periódica
@

Todas elas interagem sempre com as listas de funções periódicas do
loop atual.

A função que adiciona uma nova função periódica segue abaixo. É a
única que precisa se preocupar com o caso de não haver mais espaço
para novas funções periódicas, caso em que ela imprime um erro na
tela. Se estamos tornando periódica uma função que já é periódica,
tudo o que estamos fazendo é atualizar seu valor de freqüência para um
novo valor.

@<API Weaver: Definições@>+=
void _periodic(void (*f)(void), float t){
  int i;
  unsigned long period = (unsigned long) (t * 1000000);
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++){
    if(_periodic_functions[_number_of_loops][i].f == NULL ||
       _periodic_functions[_number_of_loops][i].f == f){
      _periodic_functions[_number_of_loops][i].f = f;
      _periodic_functions[_number_of_loops][i].period = period;
      _periodic_functions[_number_of_loops][i].last_execution = W.t;
      return;
    }
  }
  fprintf(stderr, "ERROR (1): Can't use more periodic functions.");
  fprintf(stderr,
          "Please, increase W_MAX_PERIODIC_FUNCTIONS in conf/conf.h\n");
}
@

Para fazer com que uma função deixe de ser periódica, o código é o
abaixo. Chamar esta função para funções que não são periódicas deve
ser inócuo.

@<API Weaver: Definições@>+=
void _nonperiodic(void (*f)(void)){
  int i;
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++){
    if(_periodic_functions[_number_of_loops][i].f == f){
      for(; i < W_MAX_PERIODIC_FUNCTIONS - 1; i ++){
        _periodic_functions[_number_of_loops][i].f =
                                  _periodic_functions[_number_of_loops][i+1].f;
        _periodic_functions[_number_of_loops][i].period =
                             _periodic_functions[_number_of_loops][i+1].period;
        _periodic_functions[_number_of_loops][i].last_execution =
                     _periodic_functions[_number_of_loops][i+1].last_execution;
      }
      _periodic_functions[_number_of_loops][i].f = NULL;
      return;
    }
  }
}
@

Por fim, pode ser importante chacar se uma função é periódica ou não:

@<API Weaver: Definições@>+=
bool _is_periodic(void (*f)(void)){
  int i;
  for(i = 0; i < W_MAX_PERIODIC_FUNCTIONS; i ++)
    if(_periodic_functions[_number_of_loops][i].f == f)
      return true;
  return false;
}
@

E finalmente colocamos tudo isso dentro da estrutura |W|:

@<Funções Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
void (*periodic)(void (*f)(void), float);
void (*nonperiodic)(void (*f)(void));
bool (*is_periodic)(void (*f)(void));
@

@<API Weaver: Inicialização@>=
W.periodic = &_periodic;
W.nonperiodic = &_nonperiodic;
W.is_periodic = &_is_periodic;
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
#if W_TARGET == W_ELF
bool _Wenable_plugin(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(_plugins[plugin_id] -> mutex));
#endif
  _plugins[plugin_id].enabled = true;
  if(_plugins[plugin_id]._enable_plugin != NULL)
    _plugins[plugin_id]._enable_plugin(&W);
#if W_DEBUG_LEVEL >=3
  fprintf(stderr, "WARNING (3): Plugin enabled: %s.\n",
          _plugins[plugin_id].plugin_name);
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(_plugins[plugin_id] -> mutex));
#endif
  return true;
}
bool _Wdisable_plugin(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(_plugins[plugin_id] -> mutex));
#endif
  _plugins[plugin_id].enabled = false;
  if(_plugins[plugin_id]._disable_plugin != NULL)
    _plugins[plugin_id]._disable_plugin(&W);
#if W_DEBUG_LEVEL >=3
  fprintf(stderr, "WARNING (3): Plugin disabled: %s.\n",
          _plugins[plugin_id].plugin_name);
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(_plugins[plugin_id] -> mutex));
#endif
  return true;
}
bool _Wis_enabled(int plugin_id){
  if(plugin_id >= _max_number_of_plugins ||
     !(_plugins[plugin_id].defined))
    return false;
  return _plugins[plugin_id].enabled;
}
#endif
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

