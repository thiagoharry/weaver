@* Shaders e Interface.

Quase todo jogo ou aplicação gráfica possui uma interface visual. Esta
interface são imagens que possuem um determinado tamanho e posição na
tela. Elas podem reagir de forma diferente quando um usuário coloca ou
remove o cursor do mouse sobre ela e quando é clicada com algum dos
botões do mouse. E ela pode ser ou não animada. Apesar da aparente
complexidade, é um dos elementos mais simples com os quais temos que
lidar. Uma interface não interaje com o mundo de nosso jogo, portanto
ignora a engine de física. O movimento da câmera não muda sua
posição. E elas também não interagem diretamente entre si. Geralmente
não precisamos verificar se uma interface colidiu com outra ou não.

Mas para que possamos mostrar interaces visualmente precisaremos enfim
preencher o código de nosso \italico{shader}. Mas além disso seria
interessante se os \italico{shaders} pudessem ser modificados tais
como \italico{plugins}: tanto em tempo de execução como de
compilação. E para isso precisaremos definir um formato no qual iremos
permitir nossos \italico{shaders}.

Além de \italico{shaders} sob medida criado por usuários, iremos
também, fornecer \italico{shaders} padronizados para a renderização
padrão dos objetos.

@*1 Interfaces.

Primeiro criaremos os arquivos básicos para lidarmos com interfaces:

@(project/src/weaver/interface.h@>=
#ifndef _interface_h_
#define _interface_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Interface: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/interface.c@>=
#include "interface.h"
#include <stdarg.h> // Função com argumentos variáveis
@<Interface: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "interface.h"
@

Cada interface deverá ter no mínimo uma posição e um tamanho. Para
isso, vamos usar a mesma convenção que já usamos para o cursor do
mouse. Seu tamanho e posição será dado por números inteiros que
representam valores em pixels. A posição de uma interface é a
localização de seu canto superior esquerdo (todas as interfaces são
retangulares). O canto superior direito da ela é a posição $(0,0)$.

Assim, nossa lista de interfaces é declarada da seguinte forma:

@<Interface: Declarações@>=
struct interface {
    int type; // Como renderizar
    int x, y; // Posição
    float rotation, zoom;
    float r, g, b, a; // Cor
    int height, width; // Tamanho
    void *_data; // Se é uma imagem, ela estará aqui
    /* Variáveis necessárias para o OpenGL: */
    GLuint _vao;
    GLfloat _vertices[12];
    float _offset_x, _offset_y;
    /* Funções a serem executadas em eventos: */
    void (*onmouseover)(struct interface *);
    void (*onmouseout)(struct interface *);
    void (*onleftclick)(struct interface *, int, int);
    void (*onrightclick)(struct interface *, int, int);
    void (*outleftclick)(struct interface *, int, int);
    void (*outrightclick)(struct interface *, int, int);
    /*
      Valores que dependem de alguns eventos:

       Quantos microssegundos o mouse está sobre a interface? Ou está
       durando o clique? O número 1 significa que o clique ocorreu
       neste frame. O número negativo indica que o botão acabou de ser
       solto ou o mouse acabou de sair de cima da interface e o
       inverso do valor contém por quantos microssegundos o mouse
       ficou sobre a interface ou o botão ficou pressionado:
     */
    long mouseover, leftclick, rightclick;
    /* Mutex: */
#ifdef W_MULTITHREAD
    pthread_mutex_t _mutex;
#endif
} _interfaces[W_LIMIT_SUBLOOP][W_MAX_INTERFACES];
#ifdef W_MULTITHREAD
  // Para impedir duas threads de iserirem ou removerem interfaces
  // desta matriz:
  pthread_mutex_t _interface_mutex;
#endif
@

Notar que cada subloop do jogo tem as suas interfaces. E o número
máximo para cada subloop deve ser dado por |W_MAX_INTERFACES|.

O atributo |type| conterá a regra de renderização sobre como o shader
deve tratar o elemento. Por hora definiremos dois tipos:

@<Interface: Declarações@>+=
#define W_NONE                 0
#define W_INTERFACE_SQUARE    -1
#define W_INTERFACE_PERIMETER -2
@

O primeiro valor indica que a interface ainda não foi definida. O
segundo deverá avisar o \italico{shader} para desenhar a interface
como um quadrado todo colorido com a cor indicada. O segundo é para
desenhar apenas o perímetro da superfície, também com as cores
indicadas. Caso uma interface não tenha sido definida, seu valor
deverá ser meramente |W_NONE|.

Na inicialização do programa preenchemos a nossa matriz de interfaces:

@<API Weaver: Inicialização@>+=
{
    int i, j;
    for(i = 0; i < W_LIMIT_SUBLOOP; i ++)
        for(j = 0; j < W_MAX_INTERFACES; j ++)
            _interfaces[i][j].type = W_NONE;
#ifdef W_MULTITHREAD
    if(pthread_mutex_init(&_interface_mutex, NULL) != 0){
        perror("Initializing interface mutex:");
        exit(1);
    }
#endif
}
@

Durante a finalização, a única preocupação que realmente precisamos
ter é destruir o mutex:

@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
if(pthread_mutex_destroy(&_interface_mutex) != 0)
    perror("Finalizing interface mutex:", NULL);
#endif
@

Também precisamos limpar as interfaces de um loop caso estejamos
descartando ele para começar um novo loop. Vamos definir como fazer
isso em uma função auxiliar que invocaremos quando necessário:

@<Interface: Declarações@>+=
void _flush_interfaces(void);
@
@<Interface: Definições@>=
void _flush_interfaces(void){
    int i;
    for(i = 0; i < W_MAX_INTERFACES; i ++){
        switch(_interfaces[_number_of_loops][i].type){
            // Dependendo do tipo da interface, podemos fazer desalocações
            // específicas aqui. Embora geralmente possamos simplesmente
            //confiar no coletor de lixo implementado
            //@<Desaloca Interfaces de Vários Tipos@>
        default:
            _interfaces[_number_of_loops][i].type = W_NONE;
        }
#ifdef W_MULTITHREAD
        if(pthread_mutex_destroy(&(_interfaces[_number_of_loops][i].mutex)) !=
           0)
            perror("Finalizing interface mutex:", NULL);
#endif
    }
}
@

Ao usarmos |Wloop|, estamos descartando o loop principal atual e
trocando por outro. Desta forma, queremos descartar também suas
interfaces:

@<Código antes de Loop, mas não de Subloop@>+=
_flush_interfaces();
@

E também precisamos fazer a mesma limpeza no caso de estarmos saindo
de um subloop:

@<Código após sairmos de Subloop@>+=
_flush_interfaces();
@

Desta forma garantimos que ao iniciar um novo loop principal, a lista
de interfaces que temos estará vazia.

@*2 Criação e Destruição de Interfaces.

Criar uma interface é só um processo mais complicado porque podem
haver muitos tipos de interfaces. A verdadeira diferença é como elas
são renderizadas. Algumas poderão ser imagens animadas, imagens
estáticas, outras serão coisas completamente customizadas, com seus
shaders criados pelo usuário e outras, as mais simples, poderão ser
apenas quadrados preenchidos ou não. São estas últimas que definiremos
mais explicitamente neste capítulo.

Para gerar uma nova interface, usaremos a função abaixo. O seu número
de parâmetros será algo dependente do tipo da interrface. Mas no
mínimo precisaremos informar a posição e o tamanho dela. Um espaço
vazio é então procurado na nossa matriz de interfaces e o processo
particular de criação dela dependendo de seu tipo tem início:

@<Interface: Declarações@>+=
struct interface *_new_interface(int type, int x, int y, int width,
                                 int height, ...);
@
@<Interface: Definições@>=
struct interface *_new_interface(int type, int x, int y,
                                 int width, int height, ...){
    int i, j;
    float gl_width, gl_height;
    va_list valist;
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&_interface_mutex);
#endif
    // Vamos encontrar no pool de interfaces um espaço vazio:
    for(i = 0; i < W_MAX_INTERFACES; i ++)
        if(_interfaces[_number_of_loops][i].type == W_NONE)
            break;
    if(i == W_MAX_INTERFACES){
        fprintf(stderr, "ERROR (0): Not enough space for interfaces. Please, "
                "increase the value of W_MAX_INTERFACES at conf/conf.h.\n");
#ifdef W_MULTITHREAD
        pthread_mutex_unlock(&_interface_mutex);
#endif
        Wexit();
    }
    _interfaces[_number_of_loops][i]._data = NULL;
    // Posição:
    _interfaces[_number_of_loops][i].x = x;
    _interfaces[_number_of_loops][i].y = y;
    _interfaces[_number_of_loops][i].rotation = 0.0;
    _interfaces[_number_of_loops][i].zoom = 1.0;
    _interfaces[_number_of_loops][i].mouseover = 0;
    _interfaces[_number_of_loops][i].leftclick = 0;
    _interfaces[_number_of_loops][i].rightclick = 0;
    // Posição OpenGL:
    _interfaces[_number_of_loops][i]._offset_x = ((float) (2 * x) /
                                                  (float) W.width) - 1.0;
    _interfaces[_number_of_loops][i]._offset_y = ((float) (2 * y) /
                                                  (float) W.height) - 1.0;
    // Tamanho:
    _interfaces[_number_of_loops][i].width = width;
    _interfaces[_number_of_loops][i].height = height;
    // Vértices OpenGL:
    gl_width = ((2.0 * width) / (float) W.width);
    gl_height = ((2.0 * height) / (float) W.height);
    for(j = 0; j < 12; j ++){
        /* inicializando:
           {0.0, 0.0, 0.0,
           gl_width, 0.0, 0.0,
           0.0, gl_height, 0.0,
           gl_width, gl_height, 0.0}
        */
        if(j == 3 || j == 9)
            _interfaces[_number_of_loops][i]._vertices[j] = gl_width;
        else if(j == 7 || j == 10)
            _interfaces[_number_of_loops][i]._vertices[j] = gl_height;
        else _interfaces[_number_of_loops][i]._vertices[j] = 0.0;
    }
    glGenVertexArrays(1, &_interfaces[_number_of_loops][i]._vao);
    // Ações:
    _interfaces[_number_of_loops][i].onmouseover = NULL;
    _interfaces[_number_of_loops][i].onmouseout = NULL;
    _interfaces[_number_of_loops][i].onleftclick = NULL;
    _interfaces[_number_of_loops][i].onrightclick = NULL;
    _interfaces[_number_of_loops][i].outleftclick = NULL;
    _interfaces[_number_of_loops][i].outrightclick = NULL;
#ifdef W_MULTITHREAD
    if(pthread_mutex_init(&(_interfaces[_number_of_loops][i]._mutex),
                          NULL) != 0){
        perror("Initializing interface mutex:");
        Wexit();
    }
#endif
    switch(type){
    case W_INTERFACE_SQUARE: // Nestes dois casos só precisamos obter a cor:
    case W_INTERFACE_PERIMETER:
        va_start(valist, height);
        _interfaces[_number_of_loops][i].r = va_arg(valist, double);
        _interfaces[_number_of_loops][i].g = va_arg(valist, double);
        _interfaces[_number_of_loops][i].b = va_arg(valist, double);
        _interfaces[_number_of_loops][i].a = va_arg(valist, double);
        va_end(valist);
        _interfaces[_number_of_loops][i].type = type;
        //@<Interface: Leitura de Argumentos e Inicialização@>
    default:
        _interfaces[_number_of_loops][i].type = type;
    }
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&_interface_mutex);
#endif
    return &(_interfaces[_number_of_loops][i]);
}
@

Após a definirmos, atribuiremos esta função à estrutura |W|:

@<Funções Weaver@>+=
struct interface *(*new_interface)(int, int, int, int, int, ...);
@

@<API Weaver: Inicialização@>+=
W.new_interface = &_new_interface;
@


Uma vez que criamos a função que cria interface para nós, precisamos
de uma que a remova. Todas as interfaces de qualquer forma são
descartadas pelo coletor de lixo ao abandonarmos o loop em que elas
são geradas, mas pode ser necessário descartá-las antes para liberar
espaço. É quando usamos a seguinte função:

@<Interface: Declarações@>+=
bool _destroy_interface(struct interface *inter);
@
@<Interface: Definições@>=
bool _destroy_interface(struct interface *inter){
    int i;
    // Só iremos remover uma dada interface se ela pertence ao loop atual:
    for(i = 0; i < W_MAX_INTERFACES; i ++)
        if(&(_interfaces[_number_of_loops][i]) == inter)
            break;
    if(i == W_MAX_INTERFACES)
        return false; // Não encontrada
    switch(_interfaces[_number_of_loops][i].type){
    //@<Desaloca Interfaces de Vários Tipos@>
    case W_INTERFACE_SQUARE:
    case W_INTERFACE_PERIMETER:
    case W_NONE:
    default: // Nos casos mais simples é só remover o tipo
        _interfaces[_number_of_loops][i].type = W_NONE;
    }
#ifdef W_MULTITHREAD
    if(pthread_mutex_destroy(&(_interfaces[_number_of_loops][i]._mutex),
                          NULL) != 0){
        perror("Error destroying mutex from interface:");
        Wexit();
    }
#endif
    return true;
}
@

E adicionamos à estrutura |W|:

@<Funções Weaver@>+=
  bool (*destroy_interface)(struct interface *);
@
@<API Weaver: Inicialização@>+=
  W.destroy_interface = &_destroy_interface;
@

@*2 Movendo e usando Zoom em Interfaces.

Para mudarmos a cor de uma interface, nós podemos sempre mudar
manualmente seus valores dentro da estrutura. Para mudar seu
comportamento em relação ao mouse, podemos também atribuir manualmente
as funções na estrutura. Mas para mudar a posição, não basta meramente
mudar os seus valores $(x, y)$, pois precisamos também modificar
variáveis internas que serão usadas pelo OpenGL durante a
renderização. Então teremos que fornecer funções específicas para
podermos movê-las.

Para mudar a posição de uma interface usaremos a função:

@<Interface: Declarações@>+=
void _move_interface(struct interface *, int x, int y, float rotation);
@

Esta mesma função permite que movamos o canto superior esquerdo da
interface para a posição passada como argumento e em seguida
rotacionemos a interface em relação à um eixo perpendicular à tela que
passa pelo seu centro. A rotação é dada em radianos e assumimos que o
sentido anti-horário é o seu sentido positivo.

@<Interface: Definições@>=
void _move_interface(struct interface *inter, int x, int y, float rotation){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(inter -> _mutex);
#endif
    inter -> x = x;
    inter -> y = y;
    inter -> _offset_x = ((float) (2 * x) / (float) W.width) - 1.0;
    inter -> _offset_y = ((float) (2 * y) / (float) W.height) - 1.0;
    inter -> rotation = rotation;
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(inter -> _mutex);
#endif
}
@

E adicionamos isso à estrutura |W|:

@<Funções Weaver@>+=
void (*move_interface)(struct interface *, int, int, float);
@

@<API Weaver: Inicialização@>+=
W.move_interface = &_move_interface;
@

Outra transformação importante é o ``zoom'' que podemos dar em uma
interface. Basta definirmos um valor e o tamanho original da interface
é multiplicado por ele. se usarmos o valor 0, a função não tem efeito.

@<Interface: Declarações@>+=
void _zoom_interface(struct interface *inter, float zoom);
@

@<Interface: Definições@>=
void _zoom_interface(struct interface *inter, float zoom){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(inter -> _mutex);
#endif
    if(zoom != 0.0){ // Ignoramos zoom de 0x.
        // A interface pode já ter sofrido um zoom antes. Então temos que
        // obter seus valores iniciais de (x, y) altura e largura.
        float width = ((float) inter -> width) / inter -> zoom;
        float height = ((float) inter -> height) / inter -> zoom;
        float x = ((float) inter -> x) -
            (((float) inter -> width) - width) / 2;
        float y = ((float) inter -> y) -
            (((float) inter -> height) - width) / 2;
        // Para dar o zoom, nós ampliamos a altura e a largura
        // multiplicando-as pelo valor. Além disso a posição (x, y) também
        // precisa ser multiplicada.
        x -= (width * zoom - width) / 2;
        y -= (height * zoom - height) / 2;
        width *= zoom;
        height *= zoom;
        inter -> x = (int) x;
        inter -> y = (int) y;
        inter -> width = (int) width;
        inter -> height = (int) height;
        inter -> zoom = zoom;
        @<Interface: Inicialização@>
    }
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(inter -> _mutex);
#endif
}
@

E por fim, adicionamos tudo isso à estrutura |W|:

@<Funções Weaver@>+=
void (*zoom_interface)(struct interface *, float);
@

@<API Weaver: Inicialização@>+=
W.zoom_interface = &_zoom_interface;
@

@*2 Funções de Interação entre Mouse e Interfaces.

Podemos atribuir às interfaces algumas funções especiais. Elas serão
invocadas quando o mouse passar por cima delas, quando sair de cima
delas e quando elas forem clicadas com o botão esquerdo ou
direito. Além disso, assim como fazemos com o mouse e teclas do
teclado, queremos manter armazenado algumas informações maiores sobre
tais eventos. Se um mouse está sobre uma interface, a quanto tempo ele
está lá? Se estamos clicando nela, por quanto tempo estamos fazendo
isso?

Mas para isso precisamos inserir algumas modificações no nosso código
do controle do \italico{mouse}, pois para fazer isso de forma mais
eficiente é importante que o próprio \italico{mouse} memorize se o
cursor está ou não sobre um elemento de interface e verifique se
durante o movimento ele ainda está ou não sobre tal elemento:

@<Atributos Adicionais do Mouse@>=
struct interface *_interface_under_mouse;
struct interface *_previous_interface_under_mouse;
@

Durante a inicialização e antes de entrar em qualquer loop
ou subloop, precisamos deixar o valor nulo:

@<API Weaver: Inicialização@>+=
  W.mouse._interface_under_mouse = NULL;
  W.mouse._previous_interface_under_mouse = NULL;
@

@<Código antes de um loop novo@>=
// Este código executa antes de um loop e subloop interiramente
// novos. Mas não quando saímos de um subloop para retornar em um loop
// em que já estávamos:
W.mouse._interface_under_mouse = NULL;
W.mouse._previous_interface_under_mouse = NULL;
@

As coisas são um pouco diferentes quando saímos de um subloop e
voltamos para um loop em que já estávamos antes. Potencialmente podem
haver interfaces já existentes ali. Não chegamos em um local
vazio. Sendo assim, cabe ao \italico{mouse} verificar se ele está no
presente momento em cima de uma interface ou não. Isso será
representado pela função:

@<Interface: Declarações@>+=
void _mouse_seek_interface(void);
@
@<Interface: Definições@>=
void _mouse_seek_interface(void){
    int i;
    W.mouse._interface_under_mouse = NULL;
    for(i = 0; i < W_MAX_INTERFACES; i ++){
        if(W.mouse.x >= _interfaces[_number_of_loops][i].x &&
           W.mouse.y >= _interfaces[_number_of_loops][i].y &&
           W.mouse.x - _interfaces[_number_of_loops][i].x <=
           _interfaces[_number_of_loops][i].width &&
           W.mouse.y - _interfaces[_number_of_loops][i].y <=
           _interfaces[_number_of_loops][i].height){
            W.mouse._interface_under_mouse = &_interfaces[_number_of_loops][i];
            break;
        }
    }
    if(W.mouse._interface_under_mouse != NULL &&
       W.mouse._interface_under_mouse -> onmouseover != NULL){
        W.mouse._interface_under_mouse -> mouseover = 1;
        W.mouse._interface_under_mouse ->
            onmouseover(W.mouse._interface_under_mouse);
    }
}
@

Após voltarmos de um subloop precisamos então executar esta função:

@<Código Logo Após voltar de Subloop@>=
_mouse_seek_interface();
@

Nos demais casos, nós estaremos em um loop, mas não haverão
interfaces. Elas ainda estarão para ser inicializadas. Nestes casos,
são as próprias interfaces que verificarão se estão ou não sob o
cursor do mouse:

@<Interface: Inicialização@>=
// Aqui a nova interface que foi gerada é apontada pelo ponteiro 'inter':
{
    if(W.mouse.x >= inter -> x &&
       W.mouse.y >= inter -> y &&
       W.mouse.x - inter -> x <= inter -> width &&
       W.mouse.y - inter -> y <= inter -> height){
        // Testa se a nova interface surgiu sob o mouse e sobre outra
        // interface:
        if(W.mouse._interface_under_mouse != NULL){
            W.mouse._interface_under_mouse -> mouseover *= -1;
            if(W.mouse._interface_under_mouse -> onmouseover != NULL)
                W.mouse._interface_under_mouse ->
                    onmouseover(W.mouse._interface_under_mouse);
            W.mouse._previous_interface_under_mouse =
                W.mouse._interface_under_mouse;
        }
        W.mouse._interface_under_mouse = inter;
        inter -> mouseover = 1;
        if(inter -> onmouseover != NULL)
            inter -> onmouseover (inter);
    }
}
@

Mas o mouse irá se mover. E a cada movimento, se estamos sobre uma
interface, precisamos verificar se não saímos dela. E se não estamos,
temos que verificar se não entramos. Além disso, no caso em que
saímos, podemos sair de cima de uma para ir pra cima de outra:

@<API Weaver: Imediatamente após tratar eventos@>+=
{
    if(W.mouse.dx != 0 || W.mouse.dy != 0){
        struct interface *inter = W.mouse._interface_under_mouse;
        if(inter != NULL){
            if(W.mouse.x < inter -> x ||
               W.mouse.y < inter -> y ||
               W.mouse.x - inter -> x > inter -> width ||
               W.mouse.y - inter -> y > inter -> height){
                W.mouse._interface_under_mouse -> mouseover *= -1;
                if(inter -> onmouseout != NULL)
                    inter -> onmouseout(inter);
                W.mouse._previous_interface_under_mouse =
                    W.mouse._interface_under_mouse;
                _mouse_seek_interface();
            }
            else{
                _mouse_seek_interface();
            }
        }
    }
}
@

Toda vez que uma interface deixa de estar sob o mouse, naquele frame
ela terá o seu valor de |mouseover| negativo. Então no começo do
próximo este valor precisa ser zerado. Assim como a interface que
possuir valor positivo precisa ter o valor incrementado. Por causa
disso, antes de tratarmos os eventos, temos que fazer tais
modificações:

@<API Weaver: Imediatamente antes de tratar eventos@>+=
{
    if(W.mouse._previous_interface_under_mouse != NULL) {
        W.mouse._previous_interface_under_mouse -> mouseover = 0;
        W.mouse._previous_interface_under_mouse = NULL;
    }
    if(W.mouse._interface_under_mouse != NULL) {
        W.mouse._interface_under_mouse -> mouseover += W.dt;
    }
}
@

A próxima coisa é começarmos a verificar quando clicamos com os botões
esquerdo e direito sobre uma interface. E quando deixamos de clicar
sobre uma interface.

Para checar se neste frame estamos clicando, masta checarmos os
valores dos botões do mouse junto com a informação que diz se o mouse
está sobre uma interface ou não:

@<API Weaver: Imediatamente após tratar eventos@>+=
{
    struct interface *inter = W.mouse._interface_under_mouse;
    if(inter != NULL){
        if(W.mouse.buttons[W_MOUSE_LEFT] == 1){
            inter -> leftclick = 1;
            if(inter -> onleftclick != NULL)
                inter -> onleftclick(inter, W.mouse.x - inter -> x,
                                     W.mouse.y - inter -> y);
        }
        else if(W.mouse.buttons[W_MOUSE_LEFT] > 1 &&
                inter -> leftclick > 0)
            inter -> leftclick += W.t;
        else if(W.mouse.buttons[W_MOUSE_LEFT] < 0){
            inter -> leftclick *= -1;
            if(inter -> outleftclick != NULL)
                inter -> outleftclick(inter, W.mouse.x - inter -> x,
                                      W.mouse.y - inter -> y);
        }
        if(W.mouse.buttons[W_MOUSE_RIGHT] == 1){
            inter -> rightclick = 1;
            if(inter -> onrightclick != NULL)
                inter -> onrightclick(inter, W.mouse.x - inter -> x,
                                      W.mouse.y - inter -> y);
        }
        else if(W.mouse.buttons[W_MOUSE_RIGHT] > 1 &&
                inter -> rightclick > 0)
            inter -> rightclick += W.t;
        else if(W.mouse.buttons[W_MOUSE_RIGHT] < 0){
            inter -> rightclick *= -1;
            if(inter -> outrightclick != NULL)
                inter -> outrightclick(inter, W.mouse.x - inter -> x,
                                      W.mouse.y - inter -> y);
        }
    }
}
@

Notar que tomamos nota da quantidade de tempo na qual o mouse é
pressionado sobre uma interface. Mas existem alguns detalhes. Só
levamos em conta o tempo no qual o cursor do mouse realmente está
sobre a interface. E o mouse pode clicar sobre uma interface, sair de
cima dela e então soltar o clique. Neste caso, a interface irá ser
considerada como clicada mesmo que o mouse não esteja mais tendo o seu
botão pressionado. O modo corretos de tratar tais casos irá variar de
acordo com o jogo (e talvez tais casos nem sejam relevantes). Por ausa
disso é responsabilidade do programador ficar com este modelo de
funcionamento e ajustá-lo por meio das funções |onrightclick|,
|onleftclick|, |onmousein|, |onmouseout|, |outrightclick| e
|outleftclick|.

De qualquer forma, precisamos também colocar o seguinte código para
que a nossa contagem de tempo do quanto está durando um clique volte à
zero no frame seguinte:

@<API Weaver: Imediatamente antes de tratar eventos@>+=
{
    if(W.mouse._previous_interface_under_mouse != NULL){
        if(W.mouse._previous_interface_under_mouse -> leftclick < 0)
            W.mouse._previous_interface_under_mouse -> leftclick = 0;
        if(W.mouse._previous_interface_under_mouse -> rightclick < 0)
            W.mouse._previous_interface_under_mouse -> rightclick = 0;
    }
    if(W.mouse._interface_under_mouse != NULL){
        if(W.mouse._interface_under_mouse -> leftclick < 0)
            W.mouse._interface_under_mouse -> leftclick = 0;
        if(W.mouse._interface_under_mouse -> rightclick < 0)
            W.mouse._interface_under_mouse -> rightclick = 0;
    }
}
@

@*1 Shaders.

E agora temos que lidar com a questão de que não podemos renderizar
nada usando a GPU e OpenGL sem recorrermos aos Shaders. Estes são
programas de computador que são executados paralelamente dentro da
placa de vídeo ao invés da CPU. Alguns são executados para cada
vértice individual da imagem (shaders de vértice) e outros chegam a
ser executados para cada pixel (shaders de fragmento).

Os programas de GPU, ou seja, os shaders são compilados durante a
execução do nosso projeto Weaver. E pode ser modificado e recompilado
durante a execução quantas vezes quisermos. É responsabilidade da
implementação OpenGL de fornecer a função para compilar tais
programas.

Tipicamente os Shaders são usados para, além de botar as coisas na
tela, calcular efeitos de luz e sombra. Embora o nome ``shader'' possa
indicar que o que ele faz tem relação com cores, na verdade eles
tambémsão capazes de provocar distorções e mudanças nos vértices das
imagens e muito mais coisas que se relacionam com a geometria além das
cores.

Basicamente dois tipos de shaders (um de vértice e um de fragmento)
podem se combinar e formar um programa de computador. Mas este
programa não é executado pela CPU, mas pela GPU. Cada código do shader
de vértice é executado para cada vértice da imagem, podendo com isso
modificar a posição do vértice na imagem ou então gerar valores
passados para o shader de fragmento para cada vértice. E cada pixel da
imagem anes de ser desenhado na tela é passado para um shader de
fragmento, o qual pode mudar sua cor, adicionar texturas e outros
efeitos. Os pixels que estão exatamente no vértice de uma imagem
recebeem valores diretamente do shader de vértice (que valores ele
escolhe passar pode vasriar). Os demais recebem os mesmos valores, mas
que são obtidos por meio da interpolação linear dos valores passados
pelos três vértices ao redor (todos os polígonos desenhados devem ser
triângulos).

Como isto tudo é uma tarefa relativamente complexa, vamos colocar o
código para lidar com shaders todo na mesma unidade de compilação:

@(project/src/weaver/shaders.h@>=
#ifndef _shaders_h_
#define _shaders_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Shaders: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/shaders.c@>=
#include <sys/stat.h> // stat
#include <string.h> // strlen, strcpy
#include <dirent.h> // opendir
#include <ctype.h> // isdigit
#include "shaders.h"
@<Shaders: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "shaders.h"
@

Agora além disso, para usarmos Shaders, precisamos inicializar antes a
biblioeca GLEW que gerará um conexo de renderização para nós:

@<API Weaver: Inicialização@>+=
{
  GLenum dummy;
  glewExperimental = GL_TRUE;
  GLenum err = glewInit();
  if (err != GLEW_OK){
    fprintf(stderr, "ERROR: GLW not supported.\n");
    exit(1);
  }
  /*
    Dependendo da versão, glewInit gera um erro completamente inócuo
    acusando valor inválido passado para alguma função. A linha
    seguinte serve apenas para ignorarmos o erro, impedindo-o de se
    propagar.
   */
  dummy = glGetError();
  glewExperimental += dummy;
  glewExperimental -= dummy;
}
@

Vamos agora entender as complexidades de escreer um código para os
shaders.

Os shaders são escritos em um código bastante similar ao C (só que com
ainda mais armadilhas), o qual é chamado de GLSL. Tais códigos
precisam estar no nosso programa na forma de strings. Então eles podem
ser codificados diretamente no programa ou podem ser lidos de um
arquivo em tempo de execução. Isso é uma grande força e uma grande
fraqueza.

Primeiro torna chato o desenvolvimento do código GLSL. Faz com que
tais códigos sempre precisem ser compilados na execução do
programa. Mas por outro lado, dá uma grande flexibilidade que temos
que abraçar. Tal como no caso dos plugins, podemos modificar os
shaders durante a execução para termos um desenvolvimento
interativo. Um programa pode até mesmo ser um ambiente de
desenvolvimento de shaders capaz de mostrar praticamente em tempo real
as modificações que são feitas no código.

Não é de se surpreender que escolhamos então tratar shaders de forma
semelhante aos plugins. Seus códigos precisarão estar sempre dentro de
diretórios específicos para isso e é lá que podemos verificar se eles
foram modificados e se precisam ser recarregados.

Tal como no caso de plugins, é algo que no ambiente Emscripten, não
suportaremos modificações de código em tempo de execução. Esta é uma
restrição mais devido ao excesso de dificuldades que deido à
impossibilidade como no caso dos plugins. E por causa disso, tal como
para plugins, o código dos shaders será injetado dinamicamente no
programa caso estejamos compilando para Emscripten.

Como iremos armazenar internamente os shaders? Recorreremos à seguinte
estrutura:

@<Shaders: Declarações@>=
struct _shader{
    bool initialized;
    GLuint program_shader; // Referência ao programa compilado em si
    char name[128];        // Nome do shader
    bool have_vertex, have_fragment; // If he has code for the shaders
#if W_TARGET == W_ELF
    char *vertex_source, *fragment_source; // Arquivo do código-fonte
    // Os inodes dos arquivos nos dizem se o código-fonte foi
    // modificado desde a última vez que o compilamos:
    ino_t vertex_inode, fragment_inode;
#endif
} *_shader_list;
@

Comparados aos plugins, uma grande vantagem que temos é que ao
executarmos o programa, podemos descobrir o número exato de shaders
que temos. Basta checar o número de arquivos adequados dentro dos
diretórios relevantes.

Mas antes temos mais uma decisão a ser tomada. Para um programa de
shader, precisamos de pelo menos dois códigos-fonte: um de vértice e
outro de fragmento. Faremos então com que ambos precisem estar em um
mesmo diretório. A ideia é que no desenvolvimento de um projeto haja
um diretório \monoespaco{shaders/}. Dentro dele haverá um diretório
para cada shader personalizado que ocê está fazendo para ele. Além
disso, cada diretório deve ter seu nome iniciado por um dígito
diferente de zero sucedido por um ``-''. Tais dígitos devem
representar números únicos e sequenciais para cada shader. Desta
forma, podemos identificar os shaders pelos seus números sempre que
precisarmos, o que é melhor que usarmos nomes.

Dentro do diretório de cada shader, pode ou não existir os
arquivos \monoespaco{vertex.glsl} e \monoespaco{fragment.glsl}. Se
eles existirem, eles irão conter o código-fonte do shader. Se não
existirem, o programa assumirá que eles deverão usar um código padrão
de shader.

Caso não sejamos um programa em desenvolvimento, mas um instalado,
iremos procurar o diretório de shaders no mesmo diretório em que fomos
instalados.

Isso nos diz que a primeira coisa que temos que fazer na
inicialização, para podermos inicializar a nossa lista de shaders é
verificar o al diretório que armazena shaders:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
{
    int number_of_shaders = 0;
    char directory[256];
    DIR *d;
    directory[0] = '\0';
#if W_DEBUG_LEVEL == 0
    strcat(directory, W_INSTALL_DIR);
#endif
    strcat(directory, "shaders/");
    // Pra começar, abrimos o diretório e percorremos os arquivos para
    // contar quantos diretórios tem ali:
    d = opendir(shader_directory);
    if(d){
        struct dirent *dir;
        // Lendo o nome para checar se é um diretório não-oculto cujo
        // nome segue a convenção necessária:
        while((dir = readdir(d)) != NULL){
            if(dir -> d_name[0] == '.') continue; // Ignore arquivos ocultos
            if(!isdigit(dir -> d_name[0]) || dir -> d_name[0] == '0'){
                fprintf(stderr, "WARNING (0): Shader being ignored. "
                        "%s/%s deve começar com dígito diferente de zero.\n",
                        directory, dir -> d_name);
                continue;
            }
#if (defined(__linux__) || defined(_BSD_SOURCE)) && defined(DT_DIR)@/
            if(dir -> d_type != DT_DIR) continue; // Ignora não-diretórios
#else
            { // Ignorando não-diretórios se não pudermos checar o
              // dirent por esta informação:
                struct stat s;
                int err;
                err = stat(file, &s);
                if(err == -1) continue;
                if(!S_ISDIR(s.st_mode)) continue;
            }
#endif
            number_of_shaders ++; // Contando shaders
        }
    }
#endif
// } Coninua abaixo
@

Após sabermos quantos shaders nosso programa vai usar, é hora de
alocarmos o espaço para eles na lista de shaders:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
//{ Continua do código acima
    _shader_list = (struct _shader *) _iWalloc(sizeof(struct _shader) *
                                               number_of_shaders);
    if(_shader_list == NULL){
        fprintf(stderr, "ERROR (0): Not enough memory to compile shaders. "
                "Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.");
        exit(1);
    }
    {
        int i; // Marcando os programas de shader como não-inicializados
        for(i = 0; i < number_of_shaders; i ++)
            _shader_list[i].initialized = false;
    }
//} E continua abaixo
#endif
@

E agora que alocamos, podemos começar a percorrer os shaders e: chegar
se todos eles podem ficar em uma posição de acordo com seu número no
vetor alocado, checar se dois deles não possuem o mesmo número (isso
garante que todos eles possuem números seqüenciais) e também compilar
o Shader.

    @<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
{ //Continua do código acima
    if(d) closedir(d);
    d = opendir(shader_directory);
    if(d){
        struct dirent *dir;
        // Lendo o nome para checar se é um diretório não-oculto cujo
        // nome segue a convenção necessária:
        while((dir = readdir(d)) != NULL){
            if(dir -> d_name[0] == '.') continue; // Ignore arquivos ocultos
            if(!isdigit(dir -> d_name[0]) || dir -> d_name[0] == '0')
                continue;
#if (defined(__linux__) || defined(_BSD_SOURCE)) && defined(DT_DIR)
            if(dir -> d_type != DT_DIR) continue; // Ignora não-diretórios
#else
            { // Ignorando não-diretórios se não pudermos checar o
              // dirent por esta informação:
                struct stat s;
                int err;
                err = stat(file, &s);
                if(err == -1) continue;
                if(!S_ISDIR(s.st_mode)) continue;
            }
#endif
            // Código quase idêntico ao anterior. Mas ao invés de
            // contar os shaders, vamos percorrê-los e compilá-los.
            // TODO: ...
            {
                int shader_number = atoi(dir -> d_name);
                if(shader_number >= number_of_shaders){
#if W_DEBUG_LEVEL >= 1
                    fprintf(stderr, "WARNING (1): Non-sequential shader "
                            "enumeration at %s.\n", directory);
#endif
                    continue;
                }
                if(_shader_list[shader_number - 1].initialized == true){
#if W_DEBUG_LEVEL >= 1
                    fprintf(stderr, "WARNING (1): Two shaders enumerated "
                            "with number %d at %s.\n", shader_number,
                            directory);
#endif
                    continue;
                }
                // Usando função auxiliar para o trabalho de compilar
                // e inicializar cada programa de shader:
                _compile_and_insert_new_shader(dir -> d_name, _shader_list,
                                               sheder_number - 1);
            }
        }
    }
}
#endif
@

% XXX: A PARTE ABAIXO PRECISA SER REESCRITA

Vamos começar criando o nosso shader de vértice e de fragmento:

@<Shaders: Declarações@>=
GLuint _vertex_shader, _fragment_shader;
// Depois de compilarmos os shaders, os ligaresmos a este programa:
GLuint _program_shader;
@

Durante a inicialização devemos informar OpenGL que queremos criar
tais shaders:

@<API Weaver: Inicialização@>+=
{
    _vertex_shader = glCreateShader(GL_VERTEX_SHADER);
    _fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
    _program_shader = glCreateProgram();
}
@

E na finalização precisamos encerrar tais shaders:

@<API Weaver: Finalização@>+=
{
    glDeleteProgram(_program_shader);
    glDeleteShader(_vertex_shader);
    glDeleteShader(_fragment_shader);
}
@

@*2 Montando os Shaders.

Mas agora precisamos de um código-fonte para o Shader. No caso do
shader de vértice, o formato dele será do tipo:

@(/tmp/vertex.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 100
// Todos os atributos individuais de cada vértice
attribute vec3 vertex_position;
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
uniform int type;
uniform vec4 color; // A cor do objeto
void main(){
    switch(type){
        /*
          Nesta parte código definido pelo usuário deve ser injetado e
          ele pode fazer o que quiser com os valores recebidos. Apenas
          deve atribuir um gl_Position no final.
         */
    case -1: // Uma interface quadrada
        /*
          Aqui vai o código para quando a interface que queremos
          desenhar é do tipo W_INTERFACE_SQUARE (vulgo -1).
        */
    case -2:
        /*
          Aqui vai o código para quando a interface que queremos
          desenhar é do tipo W_INTERFACE_PERIMETER (vulgo -2).
        */
    default:
        gl_Position = vec4(vertex_position, 1.0);
    }
}
@

O Shader de fragmento é bastante semelhante:

@(/tmp/fragment.glsl@>=
#version 100
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
uniform int type;
uniform vec4 color; // A cor do objeto
void main(){
    switch(type){
        /*
          Nesta parte código definido pelo usuário deve ser injetado e
          ele pode fazer o que quiser com os valores recebidos. Apenas
          deve atribuir um gl_Position no final.
         */
    case -1: // Uma interface quadrada
        /*
          Aqui vai o código para quando a interface que queremos
          desenhar é do tipo W_INTERFACE_SQUARE (vulgo -1).
        */
    case -2:
        /*
          Aqui vai o código para quando a interface que queremos
          desenhar é do tipo W_INTERFACE_PERIMETER (vulgo -2).
        */
    default:
        gl_Position = vec4(vertex_position, 1.0);
    }
}
@
@

Na verdade o código verdadeiro deve possuir muitoi mais atributos de
vértice e mais variáveis uniformes que serão enviadas para a GPU em
cada objeto a ser desenhado. Mas este é um modelo simplificado que nos
mostra o que temos que fazer. Cada tipo de objeto que definimos na API
Weaver (por enquanto |W_INTERFACE_SQUARE| e |W_INTERFACE_PERIMETER|)
será representado por um número negativo. Os números positivos serão
reservados para código shader fornecido pelo usuário.

A ideia é que o usuário sempre escreva seus shaders e os coloque em um
diretório adequado. O nome de tais arquivos com código shader sempre
deverá começar com dígitos seguidos de um traço ``-''. Os dígitos
devem sempre representar um número único para cada shader de um mesmo
tipo. Supondo que um shader de vértice esteja dentro de um arquivo
chamado \monoespaco{shader/vertex/5-meu\_shader.glsl} que pode ter
também um \monoespaco{shader/fragment/5-meu\_shader.glsl}. Neste caso,
iremos injetar no código que vemos acima o seguinte trecho, dentro do
|switch|:

@(/tmp/vertex.glsl@>=
case 5:
  // Cópia verbatim do que tem dentro do arquivo 5-meu_shader.glsl
break;
@

Desta forma seremos capazes de dar aos usuários liberdade de escrever
seus próprios shaders e modificar como as coisas serão renderizadas na
tela.

O código de ambos os shaders é formado por uma parte antes e uma parte
depois do código gerado dinamicamente após lermos o código de sdhader
personalizado do usuário:

@<Shaders: Declarações@>=
// Código antes:
extern char _vertex_begin[];
extern char _fragment_begin[];
// Código injetado em si:
char *_vertex_user, *_fragment_user;
// Código após o shader de usuário:
extern char _vertex_end[];
extern char _fragment_end[];
@
@<Shaders: Definições@>=
char _vertex_begin[] = {
#include "vertex_begin.data"
        , 0x00};
char _fragment_begin[] = {
#include "fragment_begin.data"
    , 0x00};
char _vertex_end[] = {
#include "vertex_end.data"
    , 0x00};
char _fragment_end[] = {
#include "fragment_end.data"
    , 0x00};
@

Cada um destes arquivos com extensão \monoespaco{.data} é gerado
durante a compilação através de arquivos \monoespaco{.glsl} que
conterão o código-fonte dos shaders. O arquivo de dados contém toda a
string presente no arquivo fonte após ser convertida para uma
representação hexadecimal e separada por vírgulas. A conversão é feita
pelo próprio \monoespaco{Makefile} com o comando \monoespaco{xxd}.

Fazendo desta forma, podemos escrever e representar neste livro e
projeto CWEB o código dos shaders exatamente da mesma forma como
fazemos com o código C da engine em si. Representamos as partes do
shader de vértice da seguinte forma:

@(project/src/weaver/vertex_begin.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 130
// Todos os atributos individuais de cada vértice
attribute vec3 vertex_position;
//@<Shader de Vértice: Atributos@>
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
uniform int type;
uniform vec4 color; // A cor do objeto
//@<Shader de Vértice: Uniformes@>
void main(){
    switch(type){
    // Aqui termina o vertex_begin.glsl e em seguida segue o código
    // injetado pelo usuário
@

E após o código injetado pelo usuário temos:

@(project/src/weaver/vertex_end.glsl@>=
        case -1: // W_INTERFACE_SQUARE
        case -2: // W_INTERFACE_PERIMETER
        default:
            gl_Position = vec4(vertex_position, 1.0);
  } // Fim do switch
} // Fim do main
@

Já no código do shader de fragmento, temos:

@(project/src/weaver/fragment_begin.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 130
// Todos os atributos individuais de cada vértice
//@<Shader de Vértice: Atributos@>
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
uniform int type;
uniform vec4 color; // A cor do objeto
//@<Shader de Vértice: Uniformes@>
void main(){
    switch(type){
    // Aqui termina o vertex_begin.glsl e em seguida segue o código
    // injetado pelo usuário
@

@(project/src/weaver/fragment_end.glsl@>=
case -1: // W_INTERFACE_SQUARE
case -2: // W_INTERFACE_PERIMETER
default:
        gl_FragColor = color;
    } // Fim do switch
} // Fim do main
@


Agora temos que lidar com o código injetado pelo usuário. Iremos
alocar espaço na memória para armazená-lo. Mas o quanto devemos
alocar? Ao contrário de programas comuns, Weaver não tem à sua
disposição memória infinita, mas somente a memória configurada para a
engine. Em outras pelavras, o limite é mais explícito. Mas uma vez que
lemos e compilamos o shader, podemos querer recompilá-lo após
modificações. Iremos suportar isso apenas caso o programa seja nativo
para Linux. O caso mais típico de uso desta função é o desenvolvimento
interativo, quando o usuário está testando modificações no shader e
deseja vê-las imediatamente sem precisar recompilar e re-executar o
programa. Alternativamente, o usuário pode estar criando um editor
inteerativo de shaders.

De qualquer forma, lidaremos com o código de recompilação recorrendo
ao |malloc| para gerar novos espaços de memória, já que entre uma
recompilação e outra o código pode crescer arbitrariamente. Como só
suportamos isso em programas nativos e em casos bastante especiais,
não será um problema o uso de |malloc|.

A inicialização de código de shader de vértice criado pelo
usuário funciona contando quantos arquios que são código de shader de
vértice nós temos. Se não formos a versão final do jogo, consultaremos
o diretório \monoespaco{shaders/vertex/}. Se formos, consultaremos
este mesmo diretório, mas no local em que o jogo foi instalado.

O código de cada arquivo precisa de 7 bytes para conter o
``\monoespaco{case XXX:}'' (sem o ``XXX''), o número de bytes
correspondente ao número e o número de bytes que representa o próprio
conteúdo do arquivo. Vamos precisar contar o valor, mas vamos precisar
também de um mutex para bloquear toda vez que formos modificar o
código de shader. Além do mutex, é útil saber se o código injetado foi
ou não alocado por um malloc:

@<Shaders: Declarações@>+=
#ifdef W_MULTITHREAD
pthread_mutex_t _shader_mutex;
#endif
bool _malloc_vertex_shader, _malloc_fragment_shader;
@

Vamos inicializar estas duas variáveis:

@<API Weaver: Inicialização@>+=
{
#ifdef W_MULTITHREAD
    if(pthread_mutex_init(&_shader_mutex, NULL) != 0){
        perror("Initializing shader mutex:");
        exit(1);
    }
#endif
    _malloc_vertex_shader = false;
    _malloc_fragment_shader = false;
}
@

Na finalização encerramos o mutex, mas também veridficamos se vamos
precisar usar um |free|:

@<API Weaver: Finalização@>+=
{
    if(_malloc_vertex_shader){
        free(_vertex_user);
    }
    if(_malloc_fragment_shader){
        free(_fragment_user);
    }
#ifdef W_MULTITHREAD
    if(pthread_mutex_destroy(&_shader_mutex) != 0)
        perror("Finalizing shader mutex:", NULL);
#endif
}
@

Já para lermos e gerarmos o código de usuário para o shader de vértice
que será injetado, faremos uso da seguinte função:

@<Shaders: Declarações@>+=
bool _get_shader_source(bool use_malloc, bool vertex);
@

O primeiro argumento diz se devemos ou não usar um |malloc|. O segundo
argumento diz se estamos querendo gerar o código do shader de vértice
(se não, só pode ser o shader de fragmento):

@<Shaders: Definições@>=
bool _get_shader_source(bool use_malloc, bool vertex){
    char *shader_directory, **dst;
    DIR  *d;
    int i, pos = 0;
    if(vertex) dst = &_vertex_user;
    else dst = &_fragment_user;
    // Obtendo em qual diretório devemos procurar por shaders:
#if W_DEBUG_LEVEL == 0 // Se esta é uma versão final:
    if(vertex)
        shader_directory = (char *) _iWalloc(strlen(W_INSTALL_DIR) +
                                             strlen("/shaders/vertex/") + 1);
    else
        shader_directory = (char *) _iWalloc(strlen(W_INSTALL_DIR) +
                                             strlen("/shaders/fragment/") + 1);
    if(shader_directory == NULL){
        fprintf(stderr, "WARNING (0): No enough internal memory for shader "
                "source code. Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.");
        return false;
    }
    strcpy(shader_directory, W_INSTALL_DIR);
    if(vertex) strcpy(shader_directory, "/shaders/vertex/");
    else strcpy(shader_directory, "/shaders/fragment/");
#else // Se ese é um programa em desenvolvimento:
    if(vertex)
        shader_directory = (char *) _iWalloc(strlen("shaders/vertex/") + 1);
    else
        shader_directory = (char *) _iWalloc(strlen("shaders/fragment/") + 1);
    if(shader_directory == NULL){
        fprintf(stderr, "WARNING (0): Not enough internal memory for shader "
                "source code. Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.");
        return false;
    }
    if(vertex) strcpy(shader_directory, "shaders/vertex/");
    else strcpy(shader_directory, "shaders/fragment/");
#endif
    // Abrindo o diretório e contando o tamanho necessário para
    // armazenar o código:
    d = opendir(shader_directory);
    if(d){
        struct dirent *dir;
        int size = 1;
        // Lendo todos os arquivos do diretório atual e vendo o
        // tamanho necessário para eles:
        while((dir = readdir(d)) != NULL){
            // Lendo o nome em dir -> dname para ver o tamanho do dígito:
            if(dir -> d_name[0] == '.') continue; // Arquivo oculto.
            if(!isdigit(dir -> d_name[0]) || dir -> d_name[0] == '0'){
                fprintf(stderr, "WARNING (0): Vertex shader being ignored. "
                        "%s%s deve começar com dígito diferente de zero.\n",
                        shader_directory, dir -> d_name);
                continue;
            }
            else{
                struct stat st;
                char *filename;
                filename = (char *) _iWalloc(strlen(shader_directory) +
                                            strlen(dir -> d_name) + 1);
                if(filename == NULL){
                    fprintf(stderr,
                            "ERROR (0): No enough internal memory. Please, "
                            "increase the value of W_INTERNAL_MEMORY at "
                            "conf/conf.h.");
                    Wexit();
                }
                strcpy(filename, shader_directory);
                strcpy(filename, dir -> d_name);
                // Caso em que o shader tem nome correto. Contando o dígito.
                for(i = 0; !isdigit(dir -> d_name[i]); i ++) size ++;
                // Contando o "\ncase X:\n" (sem o X) da mais 8 bytes:
                size += 8;
                // Adicionando o conteúdo dos arquivos:
                if(stat(filename, &st) == 0)
                    size += (int) st.st_size;
                // Adicionando o "\nbreak;\n" no fim da mais 8 bytes:
                size += 8;
                Wfree(filename);
            }
        }
        closedir(d);
        // Temos o tamanho em 'size'. Agora vamos alocar:
        if(use_malloc){
            *dst = (char *) malloc(sizeof(size + 1));
            *dst[0] = '\0';
            if(vertex) _malloc_vertex_shader = true;
            else _malloc_fragment_shader = true;
        }
        else{
            *dst = (char *) Walloc(sizeof(size + 1));
            *dst[0] = '\0';
        }
        // E recomeçamos a percorrer os arquivos de novo, apenas sem
        // imprimir mensagens de erro:
        d = opendir(shader_directory);
        while((dir = readdir(d)) != NULL){
            int number, ret;
            char *filename;
            FILE *fp;
            if(dir -> d_name[0] == '.' || !isdigit(dir -> d_name[0]) ||
               dir -> d_name[0] == '0') continue;
            number = atoi(dir -> d_name);
            filename = (char *) _iWalloc(strlen(shader_directory) +
                                         strlen(dir -> d_name) + 1);
            fp = fopen(filename, "r");
            if(fp == NULL){
#if W_DEBUG_LEVEL > 0
                fprintf(stderr, "WARNING (1): Couldn't read shader file %s.\n",
                        filename);
#endif
                continue; // Em caso de erro, ignore o arquivo
            }
            sprintf(&(*dst[pos]), "\ncase %d:\n", number);
            pos += strlen(&(*dst[pos]));
            do{
                ret = (fread(&(*dst[pos]), sizeof(char), 1024, fp));
                pos += ret;
            } while(ret == 1024);
            sprintf(&(*dst[pos]), "\nbreak;\n");
            pos += strlen(&(*dst[pos]));
            fclose(fp);
            Wfree(filename);
        }
    }
    *dst[pos] = '\0';
    Wfree(shader_directory);
    return true;
}
@

Esta função é chamada com parâmetros diferentes toda vez que formos
compilar ou recompilar os shaders, pois precisamos montar o
código-fonte personalizado dependendo do código que foi deixado ou
modificado pelo usuário. Durante a inicialização, nós geramos o código
personalizado pela primeira vez:

@<API Weaver: Inicialização@>+=
{
    // Gera shader de vértice e fragmento sem usar o malloc:
    if(!_get_shader_source(false, true))
        exit(1);
    if(!_get_shader_source(false, false))
        exit(1);
}
@

E uma vez que nós tenhamos o nósso código de shader pronto, precisamos
compilá-lo, ligá-lo e passá-lo para o OpenGL. Primeiro compilamos o
shader de vértice:

@<API Weaver: Inicialização@>+=
{
    GLint success = 0, logSize = 0;
    // Agrupando o código do shader de vértice
    char **code = _iWalloc(3 * sizeof(char *));
    if(code == NULL){
        fprintf(stderr, "ERROR (0): Not enough internal memory for shader "
                "compilation. Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.");
        exit(1);
    }
    code[0] = _vertex_begin; code[1] = _vertex_user; code[2] = _vertex_end;
    // GLuint _vertex_shader, _fragment_shader; já declarados acima
    // Precisamos associá-los ao código-fonte de shader que produzimos:
    glShaderSource(_vertex_shader, 3, (const GLchar **) code, NULL);
    glCompileShader(_vertex_shader);
    // Checando por erros de compilação do shader de vértice:
    glGetShaderiv(_vertex_shader, GL_COMPILE_STATUS, &success);
    if(success == GL_FALSE){
        char *buffer;
        glGetShaderiv(_vertex_shader, GL_INFO_LOG_LENGTH, &logSize);
        buffer = (char *) _iWalloc(logSize);
        if(buffer == NULL){
            fprintf(stderr, "ERROR (0): Vertex Shader failed to compile. "
                    "It wasn't possible to discover why because there's no "
                    "enough internal memory to make queries. Please, increase "
                    "the value of W_INTERNAL_MEMORY at conf/conf.h and try "
                    "to run this program again.\n");
            exit(1);
        }
        glGetShaderInfoLog(_vertex_shader, logSize, NULL, buffer);
        fprintf(stderr, "ERROR (0): Failed to compile vertex shader: %s\n",
                buffer);
        Wfree(buffer);
        Wexit();
    }
    Wfree(code);
}
@

Agora fazemos o mesmo com o shader de fragmento:

@<API Weaver: Inicialização@>+=
{
    GLint success = 0, logSize = 0;
    // Agrupando o código do shader de vértice
    char **code = _iWalloc(3 * sizeof(char *));
    if(code == NULL){
        fprintf(stderr, "ERROR (0): Not enough internal memory for shader "
                "compilation. Please, increase the value of W_INTERNAL_MEMORY "
                "at conf/conf.h.");
        exit(1);
    }
    code[0] = _fragment_begin; code[1] = _fragment_user;
    code[2] = _fragment_end;
    glShaderSource(_fragment_shader, 3, (const GLchar **) code, NULL);
    glCompileShader(_fragment_shader);
    // Checando por erros de compilação do shader de vértice:
    glGetShaderiv(_fragment_shader, GL_COMPILE_STATUS, &success);
    if(success == GL_FALSE){
        char *buffer;
        glGetShaderiv(_fragment_shader, GL_INFO_LOG_LENGTH, &logSize);
        buffer = (char *) _iWalloc(logSize);
        if(buffer == NULL){
            fprintf(stderr, "ERROR (0): Fragment Shader failed to compile. "
                    "It wasn't possible to discover why because there's no "
                    "enough internal memory to make queries. Please, increase "
                    "the value of W_INTERNAL_MEMORY at conf/conf.h and try "
                    "to run this program again.\n");
            exit(1);
        }
        glGetShaderInfoLog(_fragment_shader, logSize, NULL, buffer);
        fprintf(stderr, "ERROR (0): Failed to compile fragment shader: %s\n",
                buffer);
        Wfree(buffer);
        Wexit();
    }
    Wfree(code);
}
@

Ambos os Shaders já foram compilados por sucesso. Podemos agora
inclusive desalocarmos a memória que usamos para construir o
código-fonte deles e em seguida ligamos os shaders à nosso programa de
shader:

@<API Weaver: Inicialização@>+=
{
    Wfree(_fragment_user);
    Wfree(_vertex_user);
    glAttachShader(_program_shader, _vertex_shader);
    glAttachShader(_program_shader, _fragment_shader);
    glLinkProgram(_program_shader);
    // Ligar o shader pode falhar. Testando por erros:
    {
        int isLinked = 0;
        GLint logSize = 0;
        glGetProgramiv(_program_shader, GL_LINK_STATUS, &isLinked);
        if(isLinked == GL_FALSE){
            char *buffer;
            glGetShaderiv(_program_shader, GL_INFO_LOG_LENGTH, &logSize);
            buffer = (char *) _iWalloc(logSize);
            if(buffer == NULL){
                fprintf(stderr, "ERROR (0): Shaders failed to link. It wasn't "
                        "possible to discover why because there's no enough "
                        "internal memory to make queries. Please, increase "
                        "the value of W_INTERNAL_MEMORY at conf/conf.h and try "
                        "to run this program again.\n");
                exit(1);
            }
            glGetShaderInfoLog(_program_shader, logSize, NULL, buffer);
            fprintf(stderr, "ERROR (0): Failed to link shader: %s\n", buffer);
            Wfree(buffer);
            Wexit();
        }
    }
    glDetachShader(_program_shader, _vertex_shader);
    glDetachShader(_program_shader, _fragment_shader);
    glUseProgram(_program_shader);
}
@
