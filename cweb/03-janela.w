@* Criando uma janela ou espaço de desenho.

Para que tenhamos um jogo, precisamos de gráficos. E também precisamos
de um local onde desenharmos os gráficos. Em um jogo compilado para
Desktop, tipicamente criaremos uma janela na qual invocaremos funções
OpenGL. Em um jogo compilado para a Web, tudo será mais fácil, pois
não precisaremos de uma janela especial. Por padrão já teremos um
``\textit{canvas}'' para manipular com WebGL. Portanto, o código para
estes dois cenários irá diferir bastante neste capítulo. De qualquer
forma, ambos usarão OpenGL:

@<Cabeçalhos Weaver@>+=
#include <GL/glew.h>
@

Para criar uma janela, usaremos o Xlib ao invés de bibliotecas de mais
alto nível. Primeiro porque muitas bibliotecas de alto nível como SDL
parecem não funcionar bem em ambientes gráficos mais excêntricos como
o \textit{ratpoison}, o qual eu uso. Em especial quando tentam usar a
tela-cheia. Durante um tempo usei também o Xmonad, no qual algumas
bibliotecas não conseguiam deixar suas janelas em tela-cheia. Além
disso, o Xlib é uma biblioteca bastante universal. Geralmente se um
sistema não tem o X, é porque ele não tem interface gráfica e não iria
rodar um jogo mesmo.

O nosso arquivo \texttt{conf/conf.h} precisará de duas macros novas
para estabelecermos o tamanho de nossa janela (ou do ``canvas'' para a
Web):

\begin{itemize}
\item|W_DEFAULT_COLOR|: A cor padrão da janela, a ser exibida na
  ausência de qualquer outra coisa para desenhar. Representada como
  três números em ponto flutuante separados por vírgulas.
\item|W_HEIGHT|: A altura da janela ou do ``canvas''. Se for definido
  como zero, será o maior tamanho possível.
\item|W_WIDTH|: A largura da janela ou do ``canvas''. Se for definido
  como zero, será o maior tamanho possível.
\end{itemize}

Por padrão, ambos serão definidos como zero, o que tem o efeito de
deixar o programa em tela-cheia.

Vamos precisar definir também duas variáveis globais que armazenarão o
tamanho da janela em que estamos e duas outras para saber em que
posição da tela está nossa janela. Se estivermos rodando o jogo em um
navegador, seus valores nunca mudarão, e serão os que forem indicados
por tais macros. Mas se o jogo estiver rodando em uma janela, um
usuário pode querer modificar seu tamanho. Ou alternativamente, o
próprio jogo pode pedir para ter o tamanho de sua janela modificado.

Saber a altura e largura da janela em que estamos tem importância
central para podermos desenhar na tela uma interface. Saber a posição
da janela é muito menos útil. Entretanto, podemos pensar em conceitos
experimentais de jogos que podem levar em conta tal informação. Talvez
possa-se criar uma janela que tente evitar ser fechada movendo-se caso
o mouse aproxime-se dela para fechá-la. Ou um jogo que crie uma janela
que ao ser movida pela Área de trabalho possa revelar imagens
diferentes, como se funcionasse como um raio-x da tela.

@<Cabeçalhos Weaver@>+=
extern int W_width, W_height, W_x, W_y;
@

Estas variáveis precisarão ser atualizadas caso o tamanho da janela
mude e caso a janela seja movida.

@*1 Criar janelas.

O código de criar janelas só será usado se estivermos compilando um
programa nativo. Por isso, só iremos definir e declarar suas funções
se a macro |W_TARGET| for igual à |W_ELF|. Por isso, realizamos a
importação do cabeçalho condicionalmente:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_ELF
#include "window.h"
#endif

@ E o cabeçalho em si terá a forma:

@(project/src/weaver/window.h@>=
#ifndef _window_H_
#define _window_h_
#ifdef __cplusplus
  extern "C" {
#endif
@<Inclui Cabeçalho de Configuração@>@/

#include "weaver.h"
#include <signal.h>
#include <stdio.h> // |fprintf|
#include <stdlib.h> // |exit|
#include <X11/Xlib.h> // |XOpenDisplay|, |XCloseDisplay|, |DefaultScreen|,
                      // |DisplayPlanes|, |XFree|, |XCreateSimpleWindow|,
                      // |XDestroyWindow|, |XChangeWindowAttributes|,
                      // |XSelectInput|, |XMapWindow|, |XNextEvent|,
                      // |XSetInputFocus|, |XStoreName|,
#include <GL/gl.h>
#include <GL/glx.h> // |glXChooseVisual|, |glXCreateContext|, |glXMakeCurrent|
#include <X11/extensions/Xrandr.h> // |XRRSizes|, |XRRRates|, |XRRGetScreenInfo|,
                                  // |XRRConfigCurrentRate|,
                                  // |XRRConfigCurrentConfiguration|,
                                  // |XRRFreeScreenConfigInfo|,
                                  // |XRRSetScreenConfigAndRate|
#include <X11/XKBlib.h> // |XkbKeycodeToKeysym|

void _initialize_window(void);
void _finalize_window(void);

@<Janela: Declaração@>@/

#ifdef __cplusplus
  }
#endif
#endif

@ Enquanto o próprio arquivo de definição de funções as definirá
apenas condicionalmente:

@(project/src/weaver/window.c@>=
@<Inclui Cabeçalho de Configuração@>@/
#if W_TARGET == W_ELF
#include "window.h"

  int W_width, W_height, W_x, W_y;

@<Variáveis de Janela@>@/

void _initialize_window(void){
  @<Janela: Inicialização@>@/
}

void _finalize_window(void){
  @<Janela: Pré-Finalização@>@/
  @<Janela: Finalização@>@/
}

@<Janela: Definição@>@/

#endif

@ Desta forma, nada disso será incluído desnecessariamente quando
compilarmos para a Web. Mas caso seja incluso, precisamos invocar uma
função de inicialização e finalização na inicialização e finalização
da API:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
_initialize_window();
#endif
@
@<API Weaver: Finalização@>+=
#if W_TARGET == W_ELF
_finalize_window();
@<Restaura os Sinais do Programa (SIGINT, SIGTERM, etc)@>@/
#endif
@

Para que possamos criar uma janela, como o Xlib funciona segundo um
modelo cliente-servidor, precisaremos de uma conexão com tal
servidor. Tipicamente, tal conexão é chamada de ``Display''. Na
verdade, além de ser uma conexão, um Display também armazena
informações sobre o servidor com o qual nos conectamos. Como ter
acesso à conexão é necessário para fazer muitas coisas diferentes,
tais como obter entrada e saída, teremos que definir o nosso display
como variável global para que esteja acessível para outros módulos.

@<Variáveis de Janela@>=
Display *_dpy;
@

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_ELF
#include <X11/Xlib.h>
  extern Display *_dpy;
#endif
@

Ao inicializar uma conexão, o que pode dar errado é que podemos
fracassar, talvez por o servidor não estar ativo. Como iremos abrir
uma conexão com o servidor na própria máquina em que estamos
executando, então não é necessário passar qualquer argumento para a
função |XOpenDisplay|:

@<Janela: Inicialização@>=
  _dpy = XOpenDisplay(NULL);
  if(_dpy == NULL){
    fprintf(stderr,
	    "ERROR: Couldn't connect with the X Server. Are you running a "
	    "graphical interface?\n");
    exit(1);
  }
@

Nosso próximo passo será obter o número da tela na qual a janela
estará. Teoricamente um dispositivo pode ter várias telas
diferentes. Na prática provavelmente só encontraremos uma. Caso uma
pessoa tenha duas, ela provavelmente ativa a extensão Xinerama, que
faz com que suas duas telas sejam tratadas como uma só (tipicamente
com uma largura bem grande). De qualquer forma, obter o ID desta tela
será importante para obtermos alguns dados como a resolução máxima e
quantidade de bits usado em cores.

@<Variáveis de Janela@>+=
static int screen;
@

Para inicializar o valor, usamos a seguinte macro, a qual nunca
falhará:

@<Janela: Inicialização@>=
  screen = DefaultScreen(_dpy);
@

Como a tela é um inteiro, não há nada que precisemos desalocar
depois. E de posse do ID da tela, podemos obter algumas informações à
mais como a profundidade dela. Ou seja, quantos bits são usados para
representar as cores.

@<Variáveis de Janela@>+=
static int depth;
@

No momento da escrita deste texto, o valor típico da profundidade de
bits é de 24. Assim, as cores vermelho, verde e azul ficam cada uma
com 8 bits (totalizando 24) e 8 bits restantes ficam representando um
valor alpha que armazena informação de transparência.

@<Janela: Inicialização@>+=
  depth = DisplayPlanes(_dpy, screen);
  #if W_DEBUG_LEVEL >= 3
  printf("WARNING (3): Color depth: %d\n", depth);
  #endif
@

De posse destas informaões, já podemos criar a nossa janela. Ela é
declarada assim:

@<Variáveis de Janela@>=
Window _window;
@

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_ELF
#include <X11/Xlib.h>
  extern Window _window;
#endif
@

E é inicializada com os seguintes dados:

@<Janela: Inicialização@>+=
  W_x = 0;
  W_y = 0;
#if W_WIDTH > 0
  W_width = W_WIDTH;
#else
  W_width = DisplayWidth(_dpy, screen);
#endif
#if W_HEIGHT > 0
  W_height = W_HEIGHT;
#else
  W_height = DisplayHeight(_dpy, screen);
#endif
  _window = XCreateSimpleWindow(_dpy, //Conexão com o servidor X
			       DefaultRootWindow(_dpy), // A janeela-mãe
			       W_x, W_y, // Coordenadas da janela
			       W_width, // Largura da janela
			       W_height, // Altura da janela
			       0, 0, // Borda (espessura e cor)
			       0); // Cor padrão
@


Agora já podemos criar uma janela. Mas isso não quer dizer que a
janela será exibida depois de criada. Ainda temos que fazer algumas
coisas como mudar alguns atributos de configuração da janela. E só
depois disso poderemos pedir para que o servidor mostre a janela
visualmente.

Vamos nos concentrar agora nos atributos da janela. Primeiro nós
queremos que nossas escolhas de configuração sejam as mais soberanas
possíveis. Devemos pedir que o gerenciador de janelas faça todo o
possível para cumpri-las. Por isso, começamos ajustando a flag
``Override Redirect'', o que propagandeia nossa janela como uma janela
de''pop-up''. Isso faz com que nossos pedidos de entrar em tela cheia
sejam atendidos, mesmo quando estamos em ambientes como o XMonad.

A próxima coisa que fazemos é informar quais eventos devem ser
notificados para nossa janela. No caso, queremos ser avisados quando
um botão é pressionado, liberado, bem como botões do mouse e quando a
janela é revelada ou tem o seu tamanho mudado.

E por fim, mudamos tais atributos na janela e fazemos o pedido para
começarmos a ser notificados de quando houverem eventos de entrada:

@<Variáveis de Janela@>+=
static XSetWindowAttributes at; 
@

@<Janela: Inicialização@>+=
  {    
    at.override_redirect = True;
    at.event_mask = ButtonPressMask | ButtonReleaseMask | KeyPressMask |
      KeyReleaseMask | PointerMotionMask | ExposureMask | StructureNotifyMask;
    XChangeWindowAttributes(_dpy, _window, CWOverrideRedirect, &at);
    XSelectInput(_dpy, _window, StructureNotifyMask | KeyPressMask |
		 KeyReleaseMask | ButtonPressMask | ButtonReleaseMask |
		 PointerMotionMask | ExposureMask | StructureNotifyMask);
  }
@

Agora o que enfim podemos fazer é pedir para que a janela seja
desenhada na tela. Primeiro pedimos sua criação e depois aguardamos o
evento de sua criação. Quando formos notificados do evento, pedimos
para que a janela receba foco, mas que devolva o foco para a
janela-mãe quando terminar de executar. Ajustamos o nome que aparecerá
na barra de título do programa. E se nosso programa tiver várias
threads, avisamos o Xlib disso:

@<Janela: Inicialização@>+=
  XMapWindow(_dpy, _window);
  {
    XEvent e;
    XNextEvent(_dpy, &e);
    while(e.type != MapNotify){
      XNextEvent(_dpy, &e);
    }
  }
  XSetInputFocus(_dpy, _window, RevertToParent, CurrentTime);
#ifdef W_PROGRAM_NAME
  XStoreName(_dpy, _window, W_PROGRAM_NAME);
#else
  XStoreName(_dpy, _window, W_PROG);
#endif
#ifdef W_MULTITHREAD
  XInitThreads();
#endif
@

Antes de inicializarmos o código para OpenGL, precisamos garantir que
tenhamos uma versão do GLX de pelo menos 1.3. Antes disso, não
poderíamos ajustar as configurações do contexto OpenGL como
queremos. Sendo assim, primeiro precisamos checar se estamos com uma
versão compatível:

@<Janela: Inicialização@>+=
{
  int glx_major, glx_minor;
  Bool ret;
  ret = glXQueryVersion(_dpy, &glx_major, &glx_minor);
  if(!ret || (( glx_major == 1 ) && ( glx_minor < 3 )) || glx_major < 1){
    fprintf(stderr,
	    "ERROR: GLX is version %d.%d, but should be at least 1.3.\n", 
	    glx_major, glx_minor);
    exit(1);
  }
}
@

A última coisa que precisamos fazer agora na inicialização é criar um
contexto OpenGL e associá-lo à nossa recém-criada janela para que possamos
usar OpenGL nela:

@<Variáveis de Janela@>=
  static GLXContext context;
@

Também vamos precisar de configurações válidas para o nosso contexto:

@<Variáveis de Janela@>=
  static GLXFBConfig *fbConfigs;
@

Estas são as configurações que queremos para termos uma janela colorida
que pode ser desenhada e com buffer duplo.

@<Janela: Inicialização@>+=
{
  int return_value;
  int doubleBufferAttributes[] = {
    GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
    GLX_RENDER_TYPE,   GLX_RGBA_BIT,
    GLX_DOUBLEBUFFER,  True,
    GLX_RED_SIZE,      1,
    GLX_GREEN_SIZE,    1, 
    GLX_BLUE_SIZE,     1,
    GLX_DEPTH_SIZE,    1,
    None
  };
  fbConfigs = glXChooseFBConfig(_dpy, screen, doubleBufferAttributes,
				&return_value);
  if (fbConfigs == NULL){
    fprintf(stderr,
	    "ERROR: Not possible to create a double-buffered window.\n");
    exit(1);
  }
}
@

Agora iremos precisar usar uma função chamada
|glXCreateContextAttribsARB| para criar um contexto OpenGL 3.0. O
problema é que nem todas as placas de vídeo possuem ela. Algumas podem
não ter suporte à versões mais novas do openGL. Por causa disso, esta
função não está delarada em nenhum cabeçalho. Nós mesmos precisamos
declará-la e obter o seu valor dinamicamente se ela existir:

@<Janela: Declaração@>+=
typedef GLXContext
  (*glXCreateContextAttribsARBProc)(Display*, GLXFBConfig, GLXContext, Bool,
				    const int*);
@

Tendo declarado o novo tipo, tentamos obter a função e usá-la para
criar o contexto:.

@<Janela: Inicialização@>+=
{
  int context_attribs[] =
    {
      GLX_CONTEXT_MAJOR_VERSION_ARB, 3,
      GLX_CONTEXT_MINOR_VERSION_ARB, 3,
      None
    };
  glXCreateContextAttribsARBProc glXCreateContextAttribsARB = 0;

  @<Checa suporte à glXGetProcAddressARB@>@/

  glXCreateContextAttribsARB = (glXCreateContextAttribsARBProc)
    glXGetProcAddressARB( (const GLubyte *) "glXCreateContextAttribsARB" );
  context = glXCreateContextAttribsARB(_dpy, *fbConfigs, NULL, GL_TRUE,
				       context_attribs);
  glXMakeCurrent(_dpy, _window, context);
}
@

Isso criará o contexto se tivermos suporte à função. Mas e se não
tivermos? Neste caso, um ponteiro inválido será passado para
|glXCreateContextAttribsARB| e obteremos uma falha de segmentação
quando tentarmos executá-lo. A API não tem como sabercom certeza se a
função existe ou não durante a invocação de
|glXGetProcAddressARB|. Neste caso, a função não pode nos avisar se
algo der errado fazendo algo como retornar |NULL|. Portanto, para
evitarmos a mensagem antipática de falha de segmentação, teremos que
checar antes se temos suporte à esta função ou não. Se não tivermos,
temos que cancelar o programa:

@<Checa suporte à glXGetProcAddressARB@>=
{
  // Primeiro obtemos lista de extensões OpenGL:
  const char *glxExts = glXQueryExtensionsString(_dpy, screen);
  if(strstr(glxExts, "GLX_ARB_create_context") == NULL){
    fprintf(stderr, "ERROR: Can't create an OpenGL 3.0 context.\n");
    exit(1);
  }
}
@

À partir de agora, se tudo deu certo e suportamos todos os
pré-requisitos, já criamos a nossa janela e ela está pronta para
receber comandos OpenGL. Agora é só na finalização destruirmos o
contexto que criamos. Colocamos logo em seguida o código para destruir
a janela e encerrar a conexão, já que estas coisas precisam ser feitas
nesta ordem:

@<Janela: Finalização@>+=
  glXMakeCurrent(_dpy, None, NULL);
  glXDestroyContext(_dpy, context);
  XDestroyWindow(_dpy, _window);
  XCloseDisplay(_dpy);
@

@*1 Definir tamanho do canvas.

Agora é hora de definirmos também o espaço na qual poderemos desenhar
na tela quando compilamos o programa para a Web. Felizmente, isso é
mais fácil que criar uma janela no Xlib. Basta usarmos o suporte que
Emscripten tem para as funções SDL. Então adicionamos como cabeçalho
da API:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_WEB
#include "canvas.h"
#endif
@

Agora definimos o nosso cabeçalho do módulo de ``canvas'':

@(project/src/weaver/canvas.h@>=
#ifndef _canvas_H_
#define _canvas_h_
#ifdef __cplusplus
  extern "C" {
#endif

@<Inclui Cabeçalho de Configuração@>@/

#include "weaver.h"
#include <stdio.h> // |fprintf|
#include <stdlib.h> // |exit|
#include <SDL/SDL.h> // |SDL_Init|, |SDL_CreateWindow|, |SDL_DestroyWindow|,
                      // |SDL_Quit|
void _initialize_canvas(void);
void _finalize_canvas(void);

@<Canvas: Declaração@>@/

#ifdef __cplusplus
  }
#endif
#endif
@

E por fim, o nosso \texttt{canvas.c} que definirá as funções que
criarão nosso espaço de desenho pode ser definido. Como ele é bem mais
simples, será inteiramente definido abaixo:

@(project/src/weaver/canvas.c@>=
@<Inclui Cabeçalho de Configuração@>@/
#if W_TARGET == W_WEB
#include "canvas.h"

static SDL_Surface *window;

int W_width, W_height, W_x = 0, W_y = 0;

@<Canvas: Variáveis@>@/

void _initialize_canvas(void){
  SDL_Init(SDL_INIT_VIDEO);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
  window = SDL_SetVideoMode(
#if W_WIDTH > 0
			    W_width = W_WIDTH, // Largura da janela
#else
			    W_width = 800, // Largura da janela
#endif
#if W_HEIGHT > 0
			    W_height = W_HEIGHT, // Altura da janela
#else
			    W_height = 600, // Altura da janela
#endif
			    0, // Bits por pixel, usar o padrão
			    SDL_OPENGL // Inicializar o contexto OpenGL
#if W_WIDTH == 0 && W_HEIGHT == 0
			    | SDL_WINDOW_FULLSCREEN
#endif
			    );
  if (window == NULL) {
    fprintf(stderr, "ERROR: Could not create window: %s\n", SDL_GetError());
    exit(1);
  }

  @<Canvas: Inicialização@>@/
}

void _finalize_canvas(void){
  SDL_FreeSurface(window);

}

@<Canvas: Definição@>@/

#endif
@

Note que o que estamos chamando de "janela" na verdade é uma
superfície SDL. E que não é necessário chamar |SDL_Quit|, tal função
seria ignorada se usada.

Por fim, basta agora apenas invocarmos tais funções na inicialização e
finalização da API:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_WEB
_initialize_canvas();
#endif
@

@<API Weaver: Finalização@>+=
#if W_TARGET == W_WEB
  _finalize_canvas();
#endif
@

@*1 Mudanças no Tamanho e Posição da Janela.

Em Xlib, quando uma janela tem o seu tamanho mudado, ela recebe um
evento do tipo |ConfigureNotify|. Além dele, também existirão novos
eventos se o usuário apertar uma tecla, mover o mouse e assim por
diante. Por isso, precisamos adicionar código para tratarmos de
eventos no loop principal:

@<API Weaver: Loop Principal@>=
@<API Weaver: Imediatamente antes de tratar eventos@>@/
#if W_TARGET == W_ELF
  {
    XEvent event;
    
    while(XPending(_dpy)){
      XNextEvent(_dpy, &event);

      // A variável 'event' terá todas as informações do evento
      @<API Weaver: Trata Evento Xlib@>@/
    }
  }
#endif
#if W_TARGET == W_WEB
  {
    SDL_Event event;
    
    while(SDL_PollEvent(&event)){
      // A variável 'event' terá todas as informações do evento
      @<API Weaver: Trata Evento SDL@>@/
    }
  }
#endif

@

Por hora definiremos só o tratamento do evento de mudança de tamanho e
posição da janela em Xlib. Outros eventos terão seus tratamentos
definidos mais tarde, assim como os eventos SDL caso estejamos rodando
em um navegador web.

Tudo o que temos que fazer no caso deste evento é atualizar as
variáveis globais |W_width|, |W_height|, |W_x| e |W_y|. Nem sempre o
evento |ConfigureNotify| significa que a janela mudou de tamanho ou
foi movida. Mas mesmo assim, não custa quase nada atualizarmos tais
dados. Se eles não mudaram, de qualquer forma este código será inócuo:

@<API Weaver: Trata Evento Xlib@>=
if(event.type == ConfigureNotify){
  XConfigureEvent config = event.xconfigure;
  
  W_x = config.x;
  W_y = config.y;
  W_width = config.width;
  W_height = config.height;
  continue;
}
@

Mas e se nós quisermos mudar o tamanho ou a posição de uma janela
diretamente? Para mudar o tamanho, definiremos separadamente o código
tanto para o caso de termos uma janela como para o caso de termos um
``canvas'' web para o jogo. No caso da janela, usamos uma função XLib
para isso:

@<Janela: Declaração@>=
  void Wresize_window(int width, int height);
@

@<Janela: Definição@>=
void Wresize_window(int width, int height){
  XResizeWindow(_dpy, _window, width, height);
  W_width = width;
  W_height = height;
  @<Ações após Redimencionar Janela@>@/
}
@

No caso de termos um ``canvas'' web, então usamos SDL para obtermos o
mesmo efeito:

@<Canvas: Declaração@>=
  void Wresize_window(int width, int height);
@

@<Canvas: Definição@>=
void Wresize_window(int width, int height){
  window = SDL_SetVideoMode(width, height,
			    0, // Bits por pixel, usar o padrão
			    SDL_OPENGL // Inicializar o contexto OpenGL
			    );
  W_width = width;
  W_height = height;
  @<Ações após Redimencionar Janela@>@/
}
@

Mudar a posição da janela é algo diferente. Isso só faz sentido se
realmente tivermos uma janela Xlib, e não um ``canvas'' web. De
qualquer forma, precisaremos definir esta função em ambos os
casos. Mas caso estejamos diante de um ``canvas'', a função de mudar
posição deve ser simplesmente ignorada.

@<Janela: Declaração@>=
  void Wmove_window(int x, int y);
@

@<Janela: Definição@>=
void Wmove_window(int x, int y){
  XMoveWindow(_dpy, _window, x, y);
  W_x = x;
  W_y = y;
}
@

@<Canvas: Declaração@>=
  void Wmove_window(int x, int y);
@

@<Canvas: Definição@>=
void Wmove_window(int width, int height){
  return;
}
@

@*1 Mudando a resolução da tela.

Inicialmente o Servidor X não possuía qualquer recurso para que fosse
possível mudar a sua resolução enquanto ele executa, ou coisas como
rotacionar a janela raiz. A única forma de obter isso era encerrando o
servidor e iniciando-o novamente com nova configuração. Mas programas
como jogos podem ter a necessidade de rodar em resolução menor para
melhorar o desempenho, mas ao mesmo tempo podem precisar ocupar a tela
toda para obter imersão.

Note que isso só faz sentido quando lidamos com uma janela rodando em
um gerenciador de janelas. Não no ``canvas'' de um navegador.

O primeiro problema que temos é que não dá pra mudar a resolução
arbitrariamente. Existe apenas um conjunto limitado de resoluções que
são realmente possíveis em um dado monitor. Então a primeira coisa que
precisamos fazer é descobrir quantos modos são realmente possíveis na
tela em que estamos.

Cada modo de funcionamento suportado por uma tela possui três valores
distintos: a resolução horizontal, vertical, e a frequência de
atualização da tela. A ideia é que nós usemos uma variável
|Wnumber_of_modes| para armazenar quantos modos diferentes temos,
|Wcurrent_mode| para sabermos qual o modo atual e aloquemos uma
estrutura formada por um \textit{array} de triplas de números contendo
os dados de cada modo, a qual pode ser acessada por meio de
|Wmodes|. Cada um dos modos possíveis terá um número sequencial. E se
quisermos passar para outro modo, usaremos uma função que recebe como
argumento tal número e facilmente pode checar se está diante de um
valor inválido.

@<Variáveis de Janela@>+=
  unsigned Wnumber_of_modes, Wcurrent_mode;
  struct _wmodes{
    int width, height, rate, id;
  } *Wmodes;
@

@<Canvas: Variáveis@>=
  unsigned Wnumber_of_modes, Wcurrent_mode;
  struct _wmodes{
    int width, height, rate, id;
  } *Wmodes;
@

@<Cabeçalhos Weaver@>+=
  extern unsigned Wnumber_of_modes, Wcurrent_mode;
  extern struct _wmodes *Wmodes;
@

Agora cabe à nós inicializarmos isso tudo. Se estamos programando para
a Web, nós não podemos mesmo mudar a resolução. Então, o número de
modos que temos é sempre um só. E a informação de resolução de tela
pode ser obtida armazenando o retorno de |SDL_GetVideoInfo| em uma
estrutura de informação. A taxa de atualização de tela é setada como
zero, significando um valor indefinido.

@<Canvas: Inicialização@>=
  {
    const SDL_VideoInfo *info = SDL_GetVideoInfo();
    Wnumber_of_modes = 1;
    Wcurrent_mode = 0;
    Wmodes = (struct _wmodes *) _iWalloc(sizeof(struct _wmodes));
    Wmodes[0].width = info->current_w;
    Wmodes[0].height = info->current_h;
    Wmodes[0].rate = 0;
    Wmodes[0].id = 0;
  }
#if W_DEBUG_LEVEL >=3
  fprintf(stderr, "WARNING (3): Screen resolution: %dx%d.\n",
	  Wmodes[0].width, Wmodes[0].height);
#endif
@

Se não estamos programando para a Web, inicializar tais dados é mais
complicado. Nós vamos precisar usar a extensão XRandr. E além disso,
como podemos mudar a resolução da nossa tela, é importante
memorizarmos os valores iniciais. Usaremos duas variáveis abaixo para
fazer isso. A primeira é um ID que representa a resolução e a segunta
é a taxa de atualização a tela. Mais abaixo, uma terceira variável
armazena a rotação atual da tela. Weaver não permite que rotacionemos
a tela, mas mesmo assim tal informação deve ser obtida para quando
depois tivermos que restaurar as configurações iniciais.

Por fim, a quarta variável que definimos é uma que irá armazenar as
informações das configurações relacionadas à resolução e taxa de
atualização da tela.

@<Variáveis de Janela@>+=
  static int _orig_size_id, _orig_rate;
  static Rotation _orig_rotation;
  static XRRScreenConfiguration *conf;
@

@<Janela: Inicialização@>+=
{
  Window root = RootWindow(_dpy, 0); // Janela raíz da tela padrão
  int num_modes, num_rates, i, j, k;
  XRRScreenSize *modes = XRRSizes(_dpy, 0, &num_modes);
  short *rates;

  // Obtendo o número de modos
  Wnumber_of_modes = 0;
  for(i = 0; i < num_modes; i ++){
    rates = XRRRates(_dpy, 0, i, &num_rates);
    Wnumber_of_modes += num_rates;
  }
  Wmodes = (struct _wmodes *) _iWalloc(sizeof(struct _wmodes) *
				       Wnumber_of_modes);

  // obtendo o valor original de resolução e taxa de atualização:
  conf = XRRGetScreenInfo(_dpy, root);
  _orig_rate = XRRConfigCurrentRate(conf);
  _orig_size_id = XRRConfigCurrentConfiguration(conf, &_orig_rotation);

  // Preenchendo as informações dos modos e descobrindo o ID do atual
  k = 0;
  for(i = 0; i < num_modes; i ++){
    rates = XRRRates(_dpy, 0, i, &num_rates);
    for(j = 0; j < num_rates; j++){
      Wmodes[k].width = modes[i].width;
      Wmodes[k].height = modes[i].height;
      Wmodes[k].rate = rates[j];
      Wmodes[k].id = i;
      if(i == _orig_size_id && rates[j] == _orig_rate)
	Wcurrent_mode = k;
      k ++;
    }
  }
#if W_DEBUG_LEVEL >=3
  fprintf(stderr, "WARNING (3): Screen resolution: %dx%d (%dHz).\n",
	  Wmodes[Wcurrent_mode].width, Wmodes[Wcurrent_mode].height, 
	  Wmodes[Wcurrent_mode].rate);
#endif
}
@

Caso modifiquemos a resolução da tela, antes de fechar o programa,
precisamos fazer tudo voltar ao que era antes. E o mesmo se o programa
for encerrado devido à uma falha de segmentação, divisão por zero, ou
algo assim. Independente do que causar o fim do programa, precisamos
chamar a função que definiremos:

@<Janela: Declaração@>=
  void _restore_resolution(void);
@

@<Janela: Definição@>=
void _restore_resolution(void){
  Window root = RootWindow(_dpy, 0);
  XRRSetScreenConfigAndRate(_dpy, conf, root, _orig_size_id, _orig_rotation,
			    _orig_rate, CurrentTime);
  XRRFreeScreenConfigInfo(conf);
}
@

O primeiro caso no qual chamamos esta função é quando encerramos o
programa normalmente. Mas precisamos chamar ela antes de termos
fechado a conexão com o servidor X. Por isso colocamos este código de
finalização imediatamente antes:

@<Janela: Pré-Finalização@>=
  _restore_resolution();
@

Criamos também uma função |restore_and_quit|, que será a que será
chamada caso recebamos um sinal fatal que encerre abruptamente nosso
programa:

@<Janela: Declaração@>=
  void _restore_and_quit(int signal, siginfo_t *si, void *arg);
@

@<Janela: Definição@>=
void _restore_and_quit(int signal, siginfo_t *si, void *arg){
  fprintf(stderr, "ERROR: Received signal %d.\n", signal);
  Wexit();
  exit(1);
}
@

E por fim, trataremos agora dos sinais. Primeiro precisamos salvar as
funções responsáveis por tratar os sinais fatais ao mesmo tempo em que
as redefinimos. Para isso, precisaremos de um vetor:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_ELF
#include <signal.h>
#endif
@

@<API Weaver: Definições@>+=
#if W_TARGET == W_ELF
static struct sigaction *actions[12];
#endif
@

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
{
  struct sigaction sa;
  memset(&sa, 0, sizeof(struct sigaction));
  sigemptyset(&sa.sa_mask);
  sa.sa_sigaction = _restore_and_quit;
  sa.sa_flags   = SA_SIGINFO;

  sigaction(SIGHUP, &sa, actions[0]);
  sigaction(SIGINT, &sa, actions[1]);
  sigaction(SIGQUIT, &sa, actions[2]);
  sigaction(SIGILL, &sa, actions[3]);
  sigaction(SIGABRT, &sa, actions[4]);
  sigaction(SIGFPE, &sa, actions[5]);
  sigaction(SIGSEGV, &sa, actions[6]);
  sigaction(SIGPIPE, &sa, actions[7]);
  sigaction(SIGALRM, &sa, actions[8]);
  sigaction(SIGTERM, &sa, actions[9]);
  sigaction(SIGUSR1, &sa, actions[10]);
  sigaction(SIGUSR2, &sa, actions[11]);
}
#endif
@

O único caso no qual não seremos capazes de restaurar a resolução é
quando recebermos um |SIGKILL|. Não há muito a fazer com relação à
isso. Entretanto, um sinal desta magnitude só pode ser gerado por um
usuário, nunca será a reação do Sistema Operacional à uma ação do
programa. Então, teremos que assumir que caso isso aconteça, o usuário
sabe o que está fazendo e saberá retornar a resolução ao seu estado
atual.

Precisamos agora durante a finalização da API restaurar os tratamentos
originais dos sinais. Para isso, usamos o seguinte código:

@<Restaura os Sinais do Programa (SIGINT, SIGTERM, etc)@>=
  sigaction(SIGHUP, actions[0], NULL);
  sigaction(SIGINT, actions[1], NULL);
  sigaction(SIGQUIT, actions[2], NULL);
  sigaction(SIGILL, actions[3], NULL);
  sigaction(SIGABRT, actions[4], NULL);
  sigaction(SIGFPE, actions[5], NULL);
  sigaction(SIGSEGV, actions[6], NULL);
  sigaction(SIGPIPE, actions[7], NULL);
  sigaction(SIGALRM, actions[8], NULL);
  sigaction(SIGTERM, actions[9], NULL);
  sigaction(SIGUSR1, actions[10], NULL);
  sigaction(SIGUSR2, actions[11], NULL);
@

Uma vez que tenhamos garantido que a resolução voltará ao normal após
o programa se encerrar, podemos fornecer então uma função responsável
por mudar a resolução e modo da tela. Esta função deverá receber como
argumento um número inteiro. Se este número for menor que zero ou
maior ou igual ao número total de modos que temos em nossa tela, a
função não fará nada e retornará zero. Caso contrário, ela mudará o
modo da tela para o representado pelo índice passado como argumento em
|Wmodes|. Além disso, ela mudará o tamanho da janela para o da nova
resolução, deixando o jogo em tela cheia, e retornará 1:

@<Janela: Declaração@>=
  int Wfullscreen_mode(int mode);
@

@<Janela: Definição@>=
int Wfullscreen_mode(int mode){
  if(mode < 0 || mode >= Wnumber_of_modes)
    return 0;
  else{
    Window root = RootWindow(_dpy, 0);
    Wmove_window(0, 0);
    Wresize_window(Wmodes[mode].width, Wmodes[mode].height);
    XRRSetScreenConfigAndRate(_dpy, conf, root, Wmodes[mode].id, _orig_rotation,
			      Wmodes[mode].rate, CurrentTime);
    return 1;
  }
}
@

Também teremos que definir a mesma função caso estejamos fazendo um
jogo para a Web. Mas neste caso, a função não fará sentido e sempre
retornará 0:

@<Canvas: Declaração@>=
  int Wfullscreen_mode(int mode);
@

@<Canvas: Definição@>=
int Wfullscreen_mode(int mode){
  return 0;
}
@

@*1 Configurações Básicas OpenGL.

A única configuração que temos no momento é a cor de fundo de nossa
janela, a qual será exibida na ausência de qualquer coisa a ser
mostrada:

@<API Weaver: Inicialização@>+=
// COm que cor limpamos a tela:
glClearColor(W_DEFAULT_COLOR, 1.0f);
// Ativamos o buffer de profundidade:
glEnable(GL_DEPTH_TEST);
@

@<API Weaver: Loop Principal@>+=
glClear(GL_COLOR_BUFFER_BIT);
@