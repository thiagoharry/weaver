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
    int _type; // Como renderizar
    int x, y; // Posição
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

O atributo |_type| conterá a regra de renderização sobre como o shader
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
            _interfaces[i][j]._type = W_NONE;
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
        switch(_interfaces[_number_of_loops][i]._type){
            // Dependendo do tipo da interface, podemos fazer desalocações
            // específicas aqui. Embora geralmente possamos simplesmente
            //confiar no coletor de lixo implementado
            //@<Desaloca Interfaces de Vários Tipos@>
        default:
            _interfaces[_number_of_loops][i]._type = W_NONE;
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
        if(_interfaces[_number_of_loops][i]._type == W_NONE)
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
        _interfaces[_number_of_loops][i]._type = type;
    //@<Interface: Leitura de Argumentos e Inicialização@>
    default:
        _interfaces[_number_of_loops][i]._type = type;
    }
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&_interface_mutex);
#endif
    return &(_interfaces[_number_of_loops][i]);
}
@

@*2 Movendo Interfaces.

Para mudarmos a cor de uma interface, nós podemos sempre mudar
manualmente seus valores dentro da estrutura. Para mudar seu
comportamento em relação ao mouse, podemos também atribuir manualmente
as funções na estrutura. Mas para mudar a posição, não basta meramente
mudar os seus valores $(x, y)$, pois precisamos também modificar
variáveis internas que serão usadas pelo OpenGL durante a
renderização. Então teremos que fornecer funções específicas para
mover as interfaces.

Para mudar a posição de uma interface usaremos a função:

@<Interface: Declarações@>+=
  //void _move_interface(struct interface *);
@
@<Interface: Definições@>=
  /*void _move_interface(struct interface *inter, int x, int y){
    inter -> x = x;
    inter -> y = y;
    // TODO
    }*/
@
