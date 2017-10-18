@* Criando uma Janela.

Para que tenhamos um jogo, precisamos de gráficos. E também precisamos
de um local onde desenharmos os gráficos. Em um jogo compilado para
Desktop, tipicamente criaremos uma janela na qual invocaremos funções
OpenGL. Em um jogo compilado para a Web, tudo será mais fácil, pois
não precisaremos de uma janela especial. Por padrão já teremos um
\italico{canvas} para manipular com WebGL. Portanto, o código para
estes dois cenários irá diferir bastante neste capítulo. De qualquer
forma, ambos usarão OpenGL:

@<Cabeçalhos Weaver@>+=
#include <GL/glew.h>
@

Outra coisa que sempre iremos precisar ter de informação é a resolução
 taxa de atualização. A resolução máxima ficará armazenada em
|max_resolution_x| e |max_resolution_y| e será a resolução do monitor
ou do navegador Web se compilado com Emscripten.

@<Variáveis Weaver@>+=
/* Isso fica dentro da estrutura W: */
int resolution_x, resolution_y, framerate;
@

Para criar uma janela, usaremos o Xlib ao invés de bibliotecas de mais
alto nível. Primeiro porque muitas bibliotecas de alto nível como SDL
parecem ter problemas em ambientes gráficos mais excêntricos como o
\italico{ratpoison} e \italico{xmonad}, as quais eu
uso. Particularmente recursos como tela cheia em alguns ambientes não
funcionam. Ao mesmo tempo, o Xlib é uma biblioteca bastante
universal. Se um sistema não tem o X, é porque ele não tem interface
gráfica e não iria rodar um jogo mesmo.

O nosso arquivo \monoespaco{conf/conf.h} precisará de duas macros novas
para estabelecermos o tamanho de nossa janela (ou do ``canvas'' para a
Web):

\macronome|W_DEFAULT_COLOR|: A cor padrão da janela, a ser exibida na
  ausência de qualquer outra coisa para desenhar. Representada como
  três números em ponto flutuante separados por vírgulas.

\macronome|W_HEIGHT|: A altura da janela ou do ``canvas''. Se for definido
  como zero, será o maior tamanho possível.

\macronome|W_WIDTH|: A largura da janela ou do ``canvas''. Se for definido
  como zero, será o maior tamanho possível.

Começaremos definindo os valores padrão para tais macros:

@(project/src/weaver/conf_end.h@>+=
#ifndef W_DEFAULT_COLOR
#define W_DEFAULT_COLOR 0.0, 0.0, 0.0
#endif
#ifndef W_HEIGHT
#define W_HEIGHT 0
#endif
#ifndef W_WIDTH
#define W_WIDTH 0
#endif
@

Definir por padrão a altura e largura como zero tem o efeito de deixar
o jogo em tela cheia.

Vamos precisar definir também variáveis globais que armazenarão o
tamanho da janela e sua posição. Se estivermos rodando o jogo em um
navegador, seus valores nunca mudarão, e serão os que forem indicados
por tais macros. Mas se o jogo estiver rodando em uma janela, um
usuário ou o próprio programa pode querer modificar seu tamanho.

Saber a altura e largura da janela em que estamos tem importância
central para podermos desenhar na tela uma interface. Saber a posição
da janela é muito menos útil. Entretanto, podemos pensar em conceitos
experimentais de jogos que podem levar em conta tal informação. Talvez
possa-se criar uma janela que tente evitar ser fechada movendo-se caso
o mouse aproxime-se dela para fechá-la. Ou um jogo que crie uma janela
que ao ser movida pela Área de trabalho possa revelar imagens
diferentes, como se funcionasse como um raio-x da tela.

As variáveis globais de que falamos estarão disponíveis dentro da
estrutura |W|:

@<Variáveis Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
int width, height, x, y;
@

Além destas variáveis globais, será importante também criarmos um
mutex a ser bloqueado sempre que elas forem modificadas em jogos com
mais de uma thread:

@<Cabeçalhos Weaver@>+=
#ifdef W_MULTITHREAD
extern pthread_mutex_t _window_mutex;
#endif
@

Estas variáveis precisarão ser atualizadas caso o tamanho da janela
mude e caso a janela seja movida. E não são variáveis que o
programador deva mudar. Não atribua nada à elas, são variáveis somente
para leitura.

@*1 Criar janelas.

O código de criar janelas só será usado se estivermos compilando um
programa nativo. Por isso, só iremos definir e declarar suas funções
se a macro |W_TARGET| for igual à |W_ELF|.

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_ELF
#include "window.h"
#endif
@

E o cabeçalho em si terá a forma:

@(project/src/weaver/window.h@>=
#ifndef _window_h_
#define _window_h_
#ifdef __cplusplus
  extern "C" {
#endif
@<Inclui Cabeçalho de Configuração@>
#include "weaver.h"
#include "memory.h"
#include <signal.h>
#include <stdio.h> // fprintf
#include <stdlib.h> // exit
#include <X11/Xlib.h> // XOpenDisplay, XCloseDisplay, DefaultScreen,
                      // DisplayPlanes, XFree, XCreateSimpleWindow,
                      // XDestroyWindow, XChangeWindowAttributes,
                      // XSelectInput, XMapWindow, XNextEvent,
                      // XSetInputFocus, XStoreName,
#include <GL/gl.h>
#include <GL/glx.h> // glXChooseVisual, glXCreateContext, glXMakeCurrent
#include <X11/extensions/Xrandr.h> // XRRSizes, XRRRates, XRRGetScreenInfo,
                                   // XRRConfigCurrentRate,
                                   // XRRConfigCurrentConfiguration,
                                   // XRRFreeScreenConfigInfo,
                                   // XRRSetScreenConfigAndRate
#include <X11/XKBlib.h> // XkbKeycodeToKeysym
void _initialize_window(void);
void _finalize_window(void);
@<Janela: Declaração@>
#ifdef __cplusplus
  }
#endif
#endif
@

Enquanto o próprio arquivo de definição de funções as definirá apenas
condicionalmente:

@(project/src/weaver/window.c@>=
@<Inclui Cabeçalho de Configuração@>
  // Se W_TARGET != W_ELF, então este arquivo não terá conteúdo nenhum
  // para o compilador, o que é proibido pelo padrão ISO. A variável a
  // seguir que nunca será usada e nem declarada propriamente previne
  // isso.
extern int make_iso_compilers_happy;
#if W_TARGET == W_ELF
#include "window.h"
#ifdef W_MULTITHREAD
  pthread_mutex_t _window_mutex;
#endif
@<Variáveis de Janela@>
void _initialize_window(void){
  @<Janela: Inicialização@>
}
void _finalize_window(void){
  @<Janela: Finalização@>
}
@<Janela: Definição@>
#endif
@

Desta forma, nada disso será incluído desnecessariamente quando
compilarmos para a Web. Mas caso seja incluso, precisamos invocar uma
função de inicialização e finalização na inicialização e finalização
da API:

@<API Weaver: Inicialização@>+=
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_window_mutex, NULL) != 0){ // Inicializa mutex
    perror(NULL);
    exit(1);
}
#endif
#if W_TARGET == W_ELF
_initialize_window();
#endif
@
@<API Weaver: Encerramento@>+=
#ifdef W_MULTITHREAD
  if(pthread_mutex_destroy(&_window_mutex) != 0){ // Finaliza mutex
    perror(NULL);
    exit(1);
}
#endif
#if W_TARGET == W_ELF
_finalize_window();
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
pessoa tenha duas ou mais, ela provavelmente ativa a extensão
Xinerama, que faz com que suas duas telas sejam tratadas como uma só
(tipicamente com uma largura bem grande). De qualquer forma, obter o
ID desta tela será importante para obtermos alguns dados como a
resolução máxima e quantidade de bits usado em cores.

@<Variáveis de Janela@>=
int _screen;
@

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_ELF
  extern int _screen;
#endif
@


Para inicializar o valor, usamos a seguinte macro, a qual nunca
falhará:

@<Janela: Inicialização@>=
  _screen = DefaultScreen(_dpy);
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
  depth = DisplayPlanes(_dpy, _screen);
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
  // Obtemos a resolução da tela
  W.resolution_x = DisplayWidth(_dpy, _screen);
  W.resolution_y = DisplayHeight(_dpy, _screen);
#if W_WIDTH > 0
  W.width = W_WIDTH; // Obtendo largura da janela
#else
  W.width = W.resolution_x;
#endif
#if W_HEIGHT > 0 // Obtendo altura da janela
  W.height = W_HEIGHT;
#else
  W.height = W.resolution_y;
#endif
  // Iremos criar nossa janela no canto superior esquerdo da tela:
  W.x = W.width / 2;
  W.y = W.resolution_y - W.height / 2;
  { /* Obtendo a taxa de atualização da tela: */
    XRRScreenConfiguration *conf = XRRGetScreenInfo(_dpy, RootWindow(_dpy, 0));
    W.framerate = XRRConfigCurrentRate(conf);
    XRRFreeScreenConfigInfo(conf);
  }
  _window = XCreateSimpleWindow(_dpy, //Conexão com o servidor X
                                DefaultRootWindow(_dpy), // A janela-mãe
                                // Coordenadas da janela nas coordenadas Xlib:
                                W.x - W.width / 2,
                                W.resolution_y - W.y - W.height / 2,
                                W.width, // Largura da janela
                                W.height, // Altura da janela
                                0, 0, // Borda (espessura e cor)
                                0); // Cor padrão
@

Isso cria a janela. Mas isso não quer dizer que a janela será
exibida. Ainda temos que fazer algumas coisas como mudar alguns
atributos da sua configuração. Só depois disso poderemos pedir para
que o servidor mostre a janela visualmente.

Vamos nos concentrar agora nos atributos da janela. Primeiro nós
queremos que nossas escolhas de configuração sejam as mais soberanas
possíveis. Devemos pedir que o gerenciador de janelas faça todo o
possível para cumpri-las. Por isso, começamos ajustando a flag
``Override Redirect'', o que propagandeia nossa janela como uma janela
de''pop-up''. Isso faz com que nossos pedidos de entrar em tela cheia
sejam atendidos, mesmo quando estamos em ambientes como o XMonad. Mas
só precisaremos de uma configuração tão agressiva se nos arquivos de
configuração for pedido para que entremos em tela cheia.

A próxima coisa que fazemos é informar quais eventos devem ser
notificados para nossa janela. No caso, queremos ser avisados quando
um botão é pressionado, liberado, bem como botões do mouse, quando a
janela é revelada ou tem o seu tamanho mudado e quando por algum
motivo nossa janela perder o foco estando em tela cheia (o usuário
talvez tenha pressionado um botão usado como tecla de atalho pelo
gerenciador de janela, mas como o jogo estará rodando em tela cheia,
não podemos deixar que isso ocorra).

E por fim, mudamos tais atributos na janela e fazemos o pedido para
começarmos a ser notificados de quando houverem eventos de entrada:

@<Variáveis de Janela@>+=
static XSetWindowAttributes at;
@

@<Janela: Inicialização@>+=
  {
#if W_WIDTH == 0 && W_HEIGHT == 0
    at.override_redirect = True;
#endif
    // Eventos que nos interessam: pressionar e soltar botão do
    // teclado, pressionar e soltar botão do mouse, movimento do mouse,
    // quando a janela é exposta e quando ela muda de tamanho.
    at.event_mask = ButtonPressMask | ButtonReleaseMask | KeyPressMask |
      KeyReleaseMask | PointerMotionMask | ExposureMask | StructureNotifyMask |
      FocusChangeMask;
    XChangeWindowAttributes(_dpy, _window, CWOverrideRedirect, &at);
    XSelectInput(_dpy, _window, StructureNotifyMask | KeyPressMask |
                 KeyReleaseMask | ButtonPressMask | ButtonReleaseMask |
                 PointerMotionMask | ExposureMask | StructureNotifyMask |
                 FocusChangeMask);
  }
@

Agora o que enfim podemos fazer é pedir para que a janela seja
desenhada na tela. Primeiro pedimos sua criação e depois aguardamos o
evento de sua criação. Quando formos notificados do evento, pedimos
para que a janela receba foco, mas que devolva o foco para a
janela-mãe quando terminar de executar. Ajustamos o nome que aparecerá
na barra de título do programa. E se nosso programa tiver várias
threads, avisamos o Xlib disso. por fim, podemos verificar com qual
tamanho a nossa janela foi criada (o gerenciador de janelas pode ter
desobedecido o nosso pedido de criar uma janela com um tamanho
específico).

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
  { // Obtendo características verdadeiras da janela, que podem ser
    // diferentes daquelas que pedimos para ela ter
    int x_return, y_return;
    unsigned int width_return, height_return, dummy_border, dummy_depth;
    Window dummy_window;
    XGetGeometry(_dpy, _window, &dummy_window, &x_return, &y_return, &width_return,
                 &height_return, &dummy_border, &dummy_depth);
    W.width = width_return;
    W.height = height_return;
    W.x = x_return + W.width / 2;
    W.y = W.resolution_y - y_return - W.height / 2;
  }
#ifdef W_PROGRAM_NAME
  XStoreName(_dpy, _window, W_PROGRAM_NAME);
#else
  XStoreName(_dpy, _window, W_PROG);
#endif
#ifdef W_MULTITHREAD
  XInitThreads();
#endif
@

Adicionamos também código para pedir para que o gerenciador de janelas
não permita o redimensionamento da janela. Devemos ter em mente,
porém, que haverão gerenciadores de janela que não obedecerão o
pedido:

@<Janela: Inicialização@>+=
{
  XSizeHints *hints = XAllocSizeHints();
  hints -> flags = PMinSize | PMaxSize;
  hints -> min_width = hints -> max_width = W.width;
  hints -> min_height = hints -> max_height = W.height;
  XSetWMNormalHints(_dpy, _window, hints);
  XFree(hints);
}
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
GLXContext _context;
@

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_ELF
#include <GL/glx.h>
  extern GLXContext _context;
#endif
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
    GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT, // Desenharemos na tela, não em 'pixmap'
    GLX_RENDER_TYPE,   GLX_RGBA_BIT, // Definimos as cores via RGBA, não paleta
    GLX_DOUBLEBUFFER,  True, // Usamos buffers duplos para evitar 'flickering'
    GLX_RED_SIZE,      1, // Devemos ter ao menso 1 bit de vermelho
    GLX_GREEN_SIZE,    1, // Ao menos 1 bit de verde
    GLX_BLUE_SIZE,     1, // Ao menos 1 bit de azul
    GLX_ALPHA_SIZE,    1, // Ao menos 1 bit para o canal alfa
    GLX_DEPTH_SIZE,    1, // E ao menos 1 bit de profundidade
    None
  };
  fbConfigs = glXChooseFBConfig(_dpy, _screen, doubleBufferAttributes,
                                &return_value);
  if (fbConfigs == NULL){
    fprintf(stderr,
          "ERROR: Not possible to choose our minimal OpenGL configuration.\n");
    exit(1);
  }
}
@

Agora iremos precisar usar uma função chamada
|glXCreateContextAttribsARB| para criar um contexto OpenGL 3.0. O
problema é que nem todas as placas de vídeo possuem ela. Algumas podem
não ter suporte à versões mais novas do openGL. Por causa disso, a API
não sabe se esta função existe ou não e ela não está sequer
declarada. Nós mesmos precisamos declará-la e obter o seu valor
dinamicamente verificando se ela existe:

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
    { //  Iremos usar e exigir OpenGL 3.3
      GLX_CONTEXT_MAJOR_VERSION_ARB, 3,
      GLX_CONTEXT_MINOR_VERSION_ARB, 3,
      None
    };
  glXCreateContextAttribsARBProc glXCreateContextAttribsARB = 0;
  { // Verificando se a 'glXCreateContextAttribsARB' existe:
    // Usamox 'glXQueryExtensionsString' para obter lista de extensões
    const char *glxExts = glXQueryExtensionsString(_dpy, _screen);
    if(strstr(glxExts, "GLX_ARB_create_context") == NULL){
      fprintf(stderr, "ERROR: Can't create an OpenGL 3.0 context.\n");
      exit(1);
    }
  }
  // Se estamos aqui, a função existe. Obtemos seu endereço e a usamos
  // para criar o contexto OpenGL.
  glXCreateContextAttribsARB = (glXCreateContextAttribsARBProc)
    glXGetProcAddressARB( (const GLubyte *) "glXCreateContextAttribsARB" );
  _context = glXCreateContextAttribsARB(_dpy, *fbConfigs, NULL, GL_TRUE,
                                       context_attribs);
  if(_context == NULL){
    fprintf(stderr, "ERROR: Couldn't create an OpenGL 3.0 context.\n");
    exit(1);
  }
  // Aqui pode ocorrer um erro aparentemente não-detectável, quando o
  // kernel é recompilado e o driver não o reconhece mis como
  // compatível. para mim ele imprime dentro desta função: "Gen6+
  // requires Kernel 3.6 or later." e uma falha de segmentação ocorre
  // aqui.
  glXMakeCurrent(_dpy, _window, _context);
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
  glXDestroyContext(_dpy, _context);
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
@<Inclui Cabeçalho de Configuração@>
#include "weaver.h"
#include <stdio.h> // |fprintf|
#include <stdlib.h> // |exit|
#include <SDL/SDL.h> // |SDL_Init|, |SDL_CreateWindow|, |SDL_DestroyWindow|,
                      // |SDL_Quit|
void _initialize_canvas(void);
void _finalize_canvas(void);
@<Canvas: Declaração@>
#ifdef __cplusplus
  }
#endif
#endif
@

E por fim, o nosso \monoespaco{canvas.c} que definirá as funções que
criarão nosso espaço de desenho pode ser definido. Como ele é bem mais
simples, será inteiramente definido abaixo:

@(project/src/weaver/canvas.c@>=
@<Inclui Cabeçalho de Configuração@>@/
extern int make_iso_compilers_happy;
#if W_TARGET == W_WEB
#include <emscripten.h> // emscripten_run_script_init
#include "canvas.h"
static SDL_Surface *window;
#ifdef W_MULTITHREAD
pthread_mutex_t _window_mutex;
#endif

void _initialize_canvas(void){
  SDL_Init(SDL_INIT_VIDEO); // Inicializando SDL com OpenGL 3.3
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
  W.resolution_x = emscripten_run_script_int("window.innerWidth");
  W.resolution_y = emscripten_run_script_int("window.innerHeight");
  if(W.resolution_x < 800)
    W.resolution_x = 800;
  if(W.resolution_y < 600)
    W.resolution_y = 600;
  /* A taxa de atualização da tela não pode ser obtida no ambiente
     Emscripten. Vamos usar um valor fictício. Um valor igualmente
     fictício é usado para W.x e W.y. */
  W.framerate = 60;
  W.x = W.resolution_x / 2;
  W.y = W.resolution_y / 2;
  window = SDL_SetVideoMode(// Definindo informações de tamanho do canvas
#if W_WIDTH > 0
                     W.width = W_WIDTH, // Largura da janela
#else
                     W.width = W.resolution_x,
#endif
#if W_HEIGHT > 0
                     W.height = W_HEIGHT, // Altura da janela
#else
                     W.height = W.resolution_y,
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
  // Ajustando a aparência no navegador:
  EM_ASM(
         var el = document.getElementById("canvas");
         el.style.position = "absolute";
         el.style.top =  "0px";
         el.style.left =  "0px";
         el = document.getElementById("output");
         el.style.display = "none";
         el = document.getElementsByTagName("BODY")[0];
         el.style.overflow = "hidden";
         );
}
void _finalize_canvas(void){// Desalocando a nossa superfície de canvas
  SDL_FreeSurface(window);
}
@<Canvas: Definição@>
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

@<API Weaver: Encerramento@>+=
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

@<Código a executar todo loop@>=
@<API Weaver: Imediatamente antes de tratar eventos@>
#if W_TARGET == W_ELF
  {
    XEvent event;
    while(XPending(_dpy)){
      XNextEvent(_dpy, &event);
      // A variável 'event' terá todas as informações do evento
      @<API Weaver: Trata Evento Xlib@>
    }
  }
#endif
#if W_TARGET == W_WEB
  {
    SDL_Event event;
    while(SDL_PollEvent(&event)){
      // A variável 'event' terá todas as informações do evento
      @<API Weaver: Trata Evento SDL@>
    }
  }
#endif
  @<API Weaver: Imediatamente após tratar eventos@>
@

Por hora definiremos só o tratamento do evento de mudança de tamanho e
posição da janela em Xlib. Outros eventos terão seus tratamentos
definidos mais tarde, assim como os eventos SDL caso estejamos rodando
em um navegador web.

Tudo o que temos que fazer no caso deste evento é atualizar as
variáveis globais |W.width|, |W.height|, |W.x| e |W.y|. Nem sempre o
evento |ConfigureNotify| significa que a janela mudou de tamanho ou
foi movida. Talvez ela apenas tenha se movido para frente ou para trás
em relação à outras janelas empilhadas sobre ela. Ou algo mudou o
tamanho de sua borda. Mas mesmo assim, não custa quase nada
atualizarmos tais dados. Se eles não mudaram, de qualquer forma o
código será inócuo:

@<API Weaver: Trata Evento Xlib@>=
if(event.type == ConfigureNotify){
  XConfigureEvent config = event.xconfigure;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_window_mutex);
#endif
  W.width = config.width;
  W.height = config.height;
  W.x = config.x + W.width / 2;
  W.y = W.resolution_y - config.y - W.height / 2;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_window_mutex);
#endif
  continue;
}
@

Não é necessário criar um código análogo para a Web pra nada disso,
pois lá será impossível mover a nossa ``janela''. Afinal, ela não será
uma janela verdadeira, mas um ``\italico{canvas}''.

Mas e se nós quisermos mudar o tamanho ou a posição de uma janela
diretamente? Para mudar o tamanho, precisamos definir separadamente o
código tanto para o caso de termos uma janela como para o caso de
termos um \italico{canvas} web para o jogo. No caso da janela, usamos
uma função XLib para isso:

@<Janela: Declaração@>=
void _Wresize_window(int width, int height);
@

@<Janela: Definição@>=
void _Wresize_window(int width, int height){
  int old_width, old_height;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_window_mutex);
#endif
  XResizeWindow(_dpy, _window, width, height);
  old_width = W.width;
  old_height = W.height;
  W.width = width;
  W.height = height;
  glViewport(0, 0, W.width, W.height);
  @<Ações após Redimencionar Janela@>
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_window_mutex);
#endif
}
@

No caso de termos um ``canvas'' web, então usamos SDL para obtermos o
mesmo efeito. Basta pedirmos para criar uma nova janela e isso
funciona como se mudássemos o tamanho da anterior:

@<Canvas: Declaração@>=
  void _Wresize_window(int width, int height);
@

@<Canvas: Definição@>=
void _Wresize_window(int width, int height){
  int old_width, old_height;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_window_mutex);
#endif
  window = SDL_SetVideoMode(width, height,
                            0, // Bits por pixel, usar o padrão
                            SDL_OPENGL // Inicializar o contexto OpenGL
                            );
  old_width = W.width;
  old_height = W.height;
  W.width = width;
  W.height = height;
  glViewport(0, 0, W.width, W.height);
  @<Ações após Redimencionar Janela@>
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_window_mutex);
#endif
}
@

Independente de como foi definida a opção de mudar tamanho da janela,
vamos atribuí-la à estrutura |W|:

@<Funções Weaver@>+=
void (*resize_window)(int, int);
@

@<API Weaver: Inicialização@>=
W.resize_window = &_Wresize_window;
@

Mudar a posição da janela é algo diferente. Isso só faz sentido se
realmente tivermos uma janela Xlib, e não um ``canvas'' web. De
qualquer forma, precisaremos definir esta função em ambos os
casos.

@<Janela: Declaração@>=
  void _Wmove_window(int x, int y);
@

@<Janela: Definição@>=
void _Wmove_window(int x, int y){
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_window_mutex);
#endif
  XMoveWindow(_dpy, _window, x - W.width / 2, W.resolution_y - y - W.height / 2);
  W.x = x;
  W.y = y;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_window_mutex);
#endif
}
@

Esta mesma função será definida, mas será ignorada se um usuário a
invocar em um programa compilado para a Web:

@<Canvas: Declaração@>=
  void _Wmove_window(int x, int y);
@

@<Canvas: Definição@>=
void _Wmove_window(int width, int height){
  return;
}
@

E precisamos depois colocar a função em |W|:

@<Funções Weaver@>+=
void (*move_window)(int, int);
@

@<API Weaver: Inicialização@>=
W.move_window = &_Wmove_window;
@

@*1 Lidando com perda de foco.

Agora vamos lidar com um problema específico do Xlib.

E se a nossa janela perder o foco quando estivermos em tela cheia? Um
gerenciador de janelas pode ter umaoperação associada com algumas
sequencias de tecla tais como Alt+Tab ou com alguma tecla específica
como a tecla Super (vulgo Tecla do Windows). Se o usuário aperta
alguma destas combinações ou teclas especiais, o controle passa a ser
do gerenciador de janelas. Mas se a nossa janela está em tela-cheia,
ela continua neste estado, mas sem receber mais qualquer resposta do
\italico{mouse} e teclado. Então o usuário fica preso, vendo a tela do
jogo, mas sem poder interagir de modo a continuar o jogo ou
encerrá-lo.

Eta linha de código irá prevenir este problema no caso de estarmos em
tala cheia:

@<API Weaver: Trata Evento Xlib@>=
#if W_WIDTH == 0 && W_HEIGHT == 0
if(event.type == FocusOut){
  XSetInputFocus(_dpy, _window, RevertToParent, CurrentTime);
  continue;
}
#endif
@

@*1 Configurações Básicas OpenGL.

A única configuração que temos no momento é a cor de fundo de nossa
janela, a qual será exibida na ausência de qualquer coisa a ser
mostrada. Também ativamos o buffer de profundidade para que OpenGL
leve em conta a distância de cada pixel de um polígono para saber se
ele deve ser desenhado ou não (não deve ser desenhado se tiver algo na
sua frente). E por fim, também impedimos que as faces internas de um
polígono precisem ser desenhadas. É uma otimização extremamente
necessária para garantirmos um bom desempenho. Por fim, ativamos
suporte à transparência.

@<API Weaver: Inicialização@>+=
// Com que cor limpamos a tela:
glClearColor(W_DEFAULT_COLOR, 1.0f);
// Ativamos o buffer de profundidade:
glEnable(GL_DEPTH_TEST);
// Descartamos a face interna de qualquer triângulo (otimização necessária)
glEnable(GL_CULL_FACE);
// Ativamos transparência
glEnable (GL_BLEND);
glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); 
@

@<Código a executar todo loop@>+=
glClear(GL_COLOR_BUFFER_BIT);
@

@*1 Sumário das Variáveis e Funções Janela.

\macronome As seguintes 7 novas variáveis foram definidas:

\macrovalor|int W.x|: Armazena a posição $x$ da janela. Somente para
leitura, não mude o valor.

\macrovalor|int W.y|: Armazena a posição $y$ da janela. Somente para a
leitura, não mude o valor.

\macrovalor|int W.width|: Armazena a nossa resolução vertical.
Somente para leitura, não mude o valor.

\macrovalor|int W.height|: Armazena a resolução horizontal em
pixels. Somente para leitura, não mude o valor.

\macrovalor|int W.resolution_x|: A resolução horizontal da tela.

\macrovalor|int W.resolution_y|: A resolução vertical da tela.

\macrovalor|int W.framerate|: A taxa de atualização do monitor.

\macronome As seguintes 2 novas funções foram definidas:

\macrovalor|void W.resize_window(int width, int height)|: Muda o
tamanho da janela para os valores passados como argumento.

\macrovalor|void W.move_window(int x, int y)|: Move a janela para a
posição indicada como argumento.

