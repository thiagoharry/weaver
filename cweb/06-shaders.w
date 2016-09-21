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
    void (*onleftclick)(struct interface *);
    void (*onrightclick)(struct interface *);
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
        @<Inicialização de Interface@>
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

@*2 Funções de Interação com Interfaces.

Podemos atribuir às interfaces algumas funções especiais. Elas serão
invocadas quando o mouse passar por cima delas, quando sair de cima
delas e quando elas forem clicadas com o botão esquerdo ou direito.

Mas para isso precisamos inserir algumas modificações no nosso código
do controle do \italico{mouse}, pois para fazer isso de forma mais
eficiente é importante que o próprio \italico{mouse} memorize se o
cursor está ou não sobre um elemento de interface e verifique se
durante o movimento ele ainda está ou não sobre tal elemento:

@<Atributos Adicionais do Mouse@>=
struct interface *_interface_under_mouse;
@

Durante a inicialização e antes de entrar em qualquer loop
ou subloop, precisamos deixar o valor nulo:

@<API Weaver: Inicialização@>+=
  W.mouse._interface_under_mouse = NULL;
@

@<Código antes de um loop novo@>=
// Este código executa antes de um loop e subloop interiramente
// novos. Mas não quando saímos de um subloop para retornar em um loop
// em que já estávamos:
W.mouse._interface_under_mouse = NULL;
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
        W.mouse._interface_under_mouse ->
            onmouseover(W.mouse._interface_under_mouse);
    }
}
@

Após voltarmos de um subloop precisamos então executar esta função:

@<Código Logo Após voltar de Subloop@>=
_mouse_seek_interface(void);
@

Nos demais casos, nós estaremos em um loop, mas não haverão
interfaces. Elas ainda estarão para ser inicializadas. Nestes casos,
são as próprias interfaces que verificarão se estão ou não sob o
cursor do mouse:

@<Inicialização de Interface@>=
// Aqui a nova interface que foi gerada é apontada pelo ponteiro 'inter':
{
    if(W.mouse.x >= inter -> x &&
       W.mouse.y >= inter -> y &&
       W.mouse.x - inter -> x <= inter -> width &&
       W.mouse.y - inter -> y <= inter -> height){
        W.mouse._interface_under_mouse = inter;
        if(inter -> onmouseover != NULL)
            inter -> onmouseover(inter);
    }
}
@

Mas o mouse irá se mover. E a cada movimento, se estamos sobre uma
interface, precisamos verificar se não saímos dela. E se não estamos,
temos que verificar se não entramos. Além disso, no caso em que
saímos, podemos sair de cima de uma para ir pra cima de outra:

@<Código a executar todo loop@>+=
{
    if(W.mouse.dx != 0 || W.mouse.dy != 0){
        struct interface *inter = W.mouse._interface_under_mouse;
        if(inter != NULL){
            if(W.mouse.x < inter -> x ||
               W.mouse.y < inter -> y ||
               W.mouse.x - inter -> x > inter -> width ||
               W.mouse.y - inter -> y > inter -> height){
                if(inter -> onmouseout != NULL)
                    inter -> onmouseout(inter);
                _mouse_seek_interface();
        }
        else{
            _mouse_seek_interface();
        }
    }
}
@
