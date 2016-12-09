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
    float x, y; // Posição em pixels
    float rotation; // Rotação
    float r, g, b, a; // Cor
    float height, width; // Tamanho em pixels
    bool visible; // A interface é visível?
    bool stretch_x, stretch_y; // A interface muda a largura e altura
                               // com a janela?
    // Matriz de transformação OpenGL:
    GLfloat _transform_matrix[16];
    // O modo com o qual a interface é desenhada ao invocar glDrawArrays:
    GLenum _mode;
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

Agora vamos nos preocupar com os vértices das interfaces. Mas para
podermos gerá-los e passá-los para a placa de vídeo, vamos executar o
seguinte código para ativar todas as funções do OpenGL:

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

No caso de interfaces, como todas elas serão retangulares, todas elas
podem ser representadas pelos mesmos 4 vértices abaixo, que serão
modificados para ficar do tamanho e jeito certo pelos valores passados
futuramente para o shader:

@<Interface: Declarações@>=
  GLfloat _interface_vertices[12];
  // Um VBO vai armazenar os vértices na placa de vídeo:
  GLuint _interface_VBO;
  // Um VAO armazena configurações de como interpretar os vértices de um VBO:
  GLuint _interface_VAO;
@
@<API Weaver: Inicialização@>+=
{
    _interface_vertices[0] = -0.5;
    _interface_vertices[1] = -0.5;
    _interface_vertices[2] = 0.0;
    _interface_vertices[3] = 0.5;
    _interface_vertices[4] = -0.5;
    _interface_vertices[5] = 0.0;
    _interface_vertices[6] = 0.5;
    _interface_vertices[7] = 0.5;
    _interface_vertices[8] = 0.0;
    _interface_vertices[9] = -0.5;
    _interface_vertices[10] = 0.5;
    _interface_vertices[11] = 0.0;
    // Criando o VBO:
    glGenBuffers(1, &_interface_VBO);
    // Criando o VAO:
    glGenVertexArrays(1, &_interface_VAO);
    // Ativando o VAO:
    glBindVertexArray(_interface_VAO);
    // Ativando o VBO:
    glBindBuffer(GL_ARRAY_BUFFER, _interface_VBO);
    // Enviando os vértices para o VBO:
    glBufferData(GL_ARRAY_BUFFER, sizeof(_interface_vertices),
                 _interface_vertices, GL_STATIC_DRAW);
    // Definindo uma forma padrão de tratar os atributos:
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, (GLvoid*)0);
    // Ativando o primeiro atributo:
    glEnableVertexAttribArray(0);
    // Pronto. Desativamos o VAO:
    glBindVertexArray(0);
}
@

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
struct interface *_new_interface(int type, int x, int y, ...);
@
@<Interface: Definições@>=
struct interface *_new_interface(int type, int x, int y, ...){
    int i;
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
    _interfaces[_number_of_loops][i].type = type;
    _interfaces[_number_of_loops][i].visible = true;
    _interfaces[_number_of_loops][i].stretch_x = false;
    _interfaces[_number_of_loops][i].stretch_y = false;
    // Posição:
    _interfaces[_number_of_loops][i].x = (float) x;
    _interfaces[_number_of_loops][i].y = (float) y;
    _interfaces[_number_of_loops][i].rotation = 0.0;

    // Modo padrão de desenho de interface:
    _interfaces[_number_of_loops][i]._mode = GL_TRIANGLE_FAN;
#ifdef W_MULTITHREAD
    if(pthread_mutex_init(&(_interfaces[_number_of_loops][i]._mutex),
                          NULL) != 0){
        perror("Initializing interface mutex:");
        Wexit();
    }
#endif
    switch(type){
    case W_INTERFACE_PERIMETER:
        _interfaces[_number_of_loops][i]._mode = GL_LINE_LOOP;
        // Realmente não precisa de um 'break' aqui.
    case W_INTERFACE_SQUARE: // Nestes dois casos só precisamos obter a cor
        va_start(valist, y);
        _interfaces[_number_of_loops][i].width = (float) va_arg(valist, int);
        _interfaces[_number_of_loops][i].height = (float) va_arg(valist, int);
        _interfaces[_number_of_loops][i].r = va_arg(valist, double);
        _interfaces[_number_of_loops][i].g = va_arg(valist, double);
        _interfaces[_number_of_loops][i].b = va_arg(valist, double);
        _interfaces[_number_of_loops][i].a = va_arg(valist, double);
        va_end(valist);
        //@<Interface: Leitura de Argumentos e Inicialização@>
        break;
    default:
        va_start(valist, y);
        _interfaces[_number_of_loops][i].width = (float) va_arg(valist, int);
        _interfaces[_number_of_loops][i].height = (float) va_arg(valist, int);
        va_end(valist);
    }
    @<Preenche Matriz de Transformação de Interface na Inicialização@>
    @<Código logo após criar nova interface@>
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&_interface_mutex);
#endif
    return &(_interfaces[_number_of_loops][i]);
}
@

Após a definirmos, atribuiremos esta função à estrutura |W|:

@<Funções Weaver@>+=
struct interface *(*new_interface)(int, int, int, ...);
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
    @<Código ao Remover Interface@>
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

@*2 Movendo, Redimencionando e Rotacionando Interfaces.

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
void _move_interface(struct interface *, float x, float y);
@

A questão de mover a interface é que precisamos passar para a placa de
vídeo uma matriz que representa todas as transformações de posição,
zoom e rotação que fizermos na nossa interface. Os shaders da placa de
vídeo tratarão toda coordenada de vértice de uma interface como um
vetor na forma $(x, y, 0, 1)$, pois para coisas bidimensionais o valor
de $z$ é nulo e todo vértice terá um valor de 1 na ``quarta
dimensão'', somente para que ele possa ser multiplicado por matrizes
quadradas $4 \times 4$, que são necessárias em algumas transformações.

Mover uma interface na posição $(x_0, y_0)$ para a posição $(x_1,
y_1)$ é o mesmo que multiplicar a sua posição, na forma do vetor $(x,
y, 0, 1)$ pela matriz:

$$
\left[
  \matrix{
    1&0&0&x_1\cr
    0&1&0&y_1\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right]
$$

Afinal:

$$
\left[
  \matrix{
    1&0&0&x_1\cr
    0&1&0&y_1\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
  \matrix{
    x_0\cr
    y_0\cr
    0\cr
    1\cr
  }
\right] =
\left[
  \matrix{
    x_0+x_1\cr
    y_0+y_1\cr
    0\cr
    1\cr
  }
\right]
$$

Mas no caso, a posição inicial $(x_0, y_0)$ para toda interface é
sempre a mesma $(-0,5, -0,5)$, pois toda interface tem a mesma lista
de vértice que não muda. Então, em cada interface temos que manter uma
matriz de translação que ao ser multiplicada por esta posição, fique
com o valor adequado que corresponda à posição da interface na tela
dada em pixels.

@<Interface: Definições@>=
void _move_interface(struct interface *inter, float x, float y){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(inter -> _mutex);
#endif
    inter -> x = x;
    inter -> y = y;
    @<Ajusta Matriz de Interface após Mover@>
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(inter -> _mutex);
#endif
}
@

E adicionamos isso à estrutura |W|:

@<Funções Weaver@>+=
void (*move_interface)(struct interface *, float, float);
@

@<API Weaver: Inicialização@>+=
W.move_interface = &_move_interface;
@

Outra transformação importante é a mudança de tamanho que podemos
fazer em uma interface. Isso muda a altura e a largura de uma
interface.

@<Interface: Declarações@>+=
void _resize_interface(struct interface *inter, float size_x, float size_y);
@

Como os vértices de uma interface fazem com que todas elas sempre
estejam centralizadas na origem $(0, 0, 0)$ e o tamanho inicial de uma
interface é sempre 1, então para tornarmos a largura igual a $n_x$ e a
altura igual a $n_y$ devemos multiplicar cada vértice pela matriz:

$$
\left[
  \matrix{
    n_x&0&0&0\cr
    0&n_y&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right]
$$

Afinal:

$$
\left[
  \matrix{
    n_x&0&0&0\cr
    0&n_y&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
  \matrix{
    x_0\cr
    y_0\cr
    0\cr
    1\cr
  }
\right] =
\left[
  \matrix{
    x_0n_x\cr
    y_0n_y\cr
    0\cr
    1\cr
  }
\right]
$$

A definição da função que muda o tamanho das interfaces é então:

@<Interface: Definições@>=
void _resize_interface(struct interface *inter, float size_x, float size_y){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(inter -> _mutex);
#endif
    inter -> height = size_y;
    inter -> width = size_x;
    @<Ajusta Matriz de Interface após Redimensionar ou Rotacionar@>
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(inter -> _mutex);
#endif
}
@

E por fim, adicionamos tudo isso à estrutura |W|:

@<Funções Weaver@>+=
  void (*resize_interface)(struct interface *, float, float);
@

@<API Weaver: Inicialização@>+=
W.resize_interface = &_resize_interface;
@

Por fim, precisamos também rotacionar uma interface. Para isso,
mudamos o seu atributo interno de rotação, mas também modificamos a
sua matriz de rotação. A função que fará isso será:

@<Interface: Declarações@>+=
void _rotate_interface(struct interface *inter, float rotation);
@

Interfaces só podem ser rotacionadas em relação ao eixo $z$. E medimos
a sua rotação em radianos, com o sentido positivo da rotação sendo o
sentido anti-horário. Para obtermos a matriz de rotação, basta lembar
que para rotacionar $\theta$ radianos uma interface centralizada na
origem $(0,0)$ basta multiplicar sua origem por:

$$
\left[
  \matrix{
    \cos\theta&-\sin\theta&0&0\cr
    \sin\theta&\cos\theta&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right]
$$

Afinal:

$$
\left[
  \matrix{
    \cos\theta&-\sin\theta&0&0\cr
    \sin\theta&\cos\theta&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
  \matrix{
    x_0\cr
    y_0\cr
    0\cr
    1\cr
  }
\right] =
\left[
  \matrix{
    x_0\cos\theta-y_0\sin\theta\cr
    x_0\sin\theta+y_0\cos\theta\cr
    0\cr
    1\cr
  }
\right]
$$

E isso corresponde precisamente à rotação no eixo $z$ como
descrevemos. A definição da função de rotação é dada então por:

@<Interface: Definições@>+=
void _rotate_interface(struct interface *inter, float rotation){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(inter -> _mutex);
#endif
    inter -> rotation = rotation;
    @<Ajusta Matriz de Interface após Redimensionar ou Rotacionar@>
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(inter -> _mutex);
#endif
}
@

E adicionamos a função à estrutura |W|:

@<Funções Weaver@>+=
  void (*rotate_interface)(struct interface *, float);
@

@<API Weaver: Inicialização@>+=
W.rotate_interface = &_rotate_interface;
@


Podemos representar todas estas transformações juntas multiplicando as
matrizes e depois multiplicando o resultado pela coordenada do
vetor. É importante notar que a ordem na qual multiplicamos é
importante, pois tanto a rotação como a mudança de tamanho assumem que
a interface está centralizada na origem. Então, a translação deve ser
a operação mais distante da coordenada na multiplicação:

$$
\left[
  \matrix{
    1&0&0&x_1\cr
    0&1&0&y_1\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
  \matrix{
    \cos\theta&-\sin\theta&0&0\cr
    \sin\theta&\cos\theta&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
\matrix{
    n_x&0&0&0\cr
    0&n_y&0&0\cr
    0&0&1&0\cr
    0&0&0&1\cr
  }
\right] \times
\left[
  \matrix{
    x_0\cr
    y_0\cr
    0\cr
    1\cr
  }
\right] =
$$

$$
\left[
\matrix{
n_x\cos\theta&-n_y\sin\theta&0&x_1\cr
n_x\sin\theta&n_y\cos\theta&0&y_1\cr
0&0&1&0\cr
0&0&0&1\cr
}
\right]\times
\left[
  \matrix{
    x_0\cr
    y_0\cr
    0\cr
    1\cr
  }
\right]=
\left[
  \matrix{
    n_xx_0\cos\theta-n_yy_0\sin\theta+x_1\cr
    n_xx_0\sin\theta+n_yy_0\cos\theta+y_1\cr
    0\cr
    1\cr
  }
\right]
$$

Isso significa que nós não precisamos manter matrizes intermediárias
de rotação, de translação ou redimensionamento. Agora que sabemos qual
o formato da matriz $4\times 4$ final, obtida por meio da
multiplicação de todas as outras transformações, podemos apenas manter
a matriz final e editarmos as posições nela conforme for necessário.

Assim, na inicialização de uma nova interface, a matriz é preenchida:

@<Preenche Matriz de Transformação de Interface na Inicialização@>=
{
    float nx, ny, cosine, sine, x1, y1;
    nx = 2.0 * ((float) _interfaces[_number_of_loops][i].width);
    ny = 2.0 *((float) _interfaces[_number_of_loops][i].height);
    cosine = cosf(_interfaces[_number_of_loops][i].rotation);
    sine = sinf(_interfaces[_number_of_loops][i].rotation);
    x1 = (2.0 *((float) _interfaces[_number_of_loops][i].x /
                (float) W.width)) - 1.0;
    y1 = -((2.0 *((float) _interfaces[_number_of_loops][i].y /
                  (float) W.height)) - 1.0);
    _interfaces[_number_of_loops][i]._transform_matrix[0] = nx * cosine /
               (float) W.width;
    _interfaces[_number_of_loops][i]._transform_matrix[4] = -(ny * sine) /
               (float) W.width;
    _interfaces[_number_of_loops][i]._transform_matrix[8] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[12] = x1;
    _interfaces[_number_of_loops][i]._transform_matrix[1] = nx * sine /
               (float) W.height;
    _interfaces[_number_of_loops][i]._transform_matrix[5] = ny * cosine /
               (float) W.height;
    _interfaces[_number_of_loops][i]._transform_matrix[9] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[13] = y1;
    _interfaces[_number_of_loops][i]._transform_matrix[2] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[3] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[10] = 1.0;
    _interfaces[_number_of_loops][i]._transform_matrix[14] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[3] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[7] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[11] = 0.0;
    _interfaces[_number_of_loops][i]._transform_matrix[15] = 1.0;
}
@

Já após movermos uma interface para uma nova posição $(x1, y1)$ só
temos que mudar duas posições da matriz na última coluna:

@<Ajusta Matriz de Interface após Mover@>=
{
    float x1, y1;
    x1 = (2.0 *((float) inter -> x / (float) W.width)) - 1.0;
    y1 = -((2.0 *((float) inter -> y / (float) W.height)) - 1.0);
    inter -> _transform_matrix[12] = x1;
    inter -> _transform_matrix[13] = y1;
}
@

Já após redimensionarmos ou rotacionarmos interface, aí teremos 4
posições da matriz para mudarmos:

@<Ajusta Matriz de Interface após Redimensionar ou Rotacionar@>=
{
    float nx, ny, cosine, sine;
    nx = 2.0 *((float) inter -> width);
    ny = 2.0 *((float) inter -> height);
    cosine = cosf(inter -> rotation);
    sine = sinf(inter -> rotation);
    inter -> _transform_matrix[0] = (nx * cosine) / (float) W.width;
    inter -> _transform_matrix[4] = -(ny * sine) / (float) W.width;
    inter -> _transform_matrix[1] = (nx * sine) / (float) W.height;
    inter -> _transform_matrix[5] = (ny * cosine) / (float) W.height;
}
@

E um último caso em que precisamos realizar atualização da matriz para
todas as interfaces: caso a janela seja redimencionada. Para tais
casos, iremos usar a seguinte função:

@<Interface: Declarações@>+=
void _update_interface_screen_size(void);
@

@<Interface: Definições@>+=
void _update_interface_screen_size(void){
    int i, j;
    float nx, ny, cosine, sine;
    for(i = 0; i < _number_of_loops; i ++)
        for(j = 0; j < W_MAX_INTERFACES; j ++){
            if(_interfaces[i][j].type == W_NONE) continue;
#ifdef W_MULTITHREAD
            pthread_mutex_lock(_interfaces[i][j]._mutex);
#endif
            nx = 2.0 * _interfaces[i][j].width;
            ny = 2.0 *  _interfaces[i][j].height;
            cosine = cosf(_interfaces[i][j].rotation);
            sine = sinf(_interfaces[i][j].rotation);
            _interfaces[i][j]._transform_matrix[0] = (nx * cosine) / W.width;
            _interfaces[i][j]._transform_matrix[4] = -(ny * sine) / W.width;
            _interfaces[i][j]._transform_matrix[1] = (nx * sine) / W.height;
            _interfaces[i][j]._transform_matrix[5] = (ny * cosine) / W.height;
#ifdef W_MULTITHREAD
            pthread_mutex_unlock(_interfaces[i][j]._mutex);
#endif
        }
}
@

O primeiro local em que precisaremos da função é após redimencionarmos a janela:

@<Ações após Redimencionar Janela@>+=
_update_interface_screen_size();
@

@*1 Shaders.

@*2 introdução.

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
também são capazes de provocar distorções e mudanças nos vértices das
imagens. Em alguns casos, podem criar novos vértices, transformar a
geometria e deixá-la mais detalhada.

Basicamente dois tipos de shaders (um de vértice e um de fragmento)
podem se combinar e formar um programa de computador. Podem haver mais
tipos, mas Weaver se limita à estes por serem os suportados por
Emscripten. Programas gerados de shaders não são executado pela CPU,
mas pela GPU. Cada código do shader de vértice é executado para cada
vértice da imagem, podendo com isso modificar a posição do vértice na
imagem ou então gerar valores passados para o shader de fragmento para
cada vértice. E cada pixel da imagem antes de ser desenhado na tela é
passado para um shader de fragmento, o qual pode mudar sua cor,
adicionar texturas e outros efeitos. Os pixels que estão exatamente no
vértice de uma imagem recebeem valores diretamente do shader de
vértice (que valores ele escolhe passar pode variar). Os demais
recebem valores obtidos por meio de interpolação linear dos valores
passados pelos três vértices ao redor (todos os polígonos desenhados
devem ser triângulos).

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
#include <sys/types.h> // open
#include <sys/stat.h> // stat, open
#include <string.h> // strlen, strcpy
#include <dirent.h> // opendir
#include <ctype.h> // isdigit
#include <unistd.h> // access
#include <fcntl.h> // open
#include "shaders.h"
@<Shaders: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include <ctype.h> // isdigit
#include "shaders.h"
@

@*2 Shaders de interface padronizados.

Vamos começar definindo shaders de vértice e fragmento extremamente
simples capazes de renderizar as interfaces que definimos até agora:
todas são retângulos cheios ou são perímetros de retângulos.

Um exemplo simples de shader de vértice:

@(project/src/weaver/vertex_interface.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 100
// Declarando a precisão para ser compatível com GLSL 2.0 se possível
#if GL_FRAGMENT_PRECISION_HIGH == 1
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#endif
precision lowp sampler2D;
precision lowp samplerCube;
// Todos os atributos individuais de cada vértice
@<Shader: Atributos@>
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
@<Shader: Uniformes@>
void main(){
    // Apenas passamos adiante a posição que recebemos
    gl_Position = model_view_matrix * vec4(vertex_position, 1.0);
}
@

E de shader de fragmento:

@(project/src/weaver/fragment_interface.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 100
// Declarando a precisão para ser compatível com GLSL 2.0 se possível
#if GL_FRAGMENT_PRECISION_HIGH == 1
  precision highp float;
  precision highp int;
#else
  precision mediump float;
  precision mediump int;
#endif
  precision lowp sampler2D;
  precision lowp samplerCube;
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
@<Shader: Uniformes@>
void main(){
      gl_FragData[0] = object_color;
} // Fim do main
@

Dois atributos que eles terão (potencialmente únicos em cada execução
do shader) são:

@<Shader: Atributos@>=
attribute vec3 vertex_position;
@

Já um uniforme que eles tem (potencialmente único para cada objeto a
ser renderizado) são:

@<Shader: Uniformes@>=
uniform vec4 object_color; // A cor do objeto
uniform mat4 model_view_matrix; // Transformações de posição do objeto
uniform vec2 object_size; // Largura e altura do objeto
uniform float time; // Tempo de jogo em segundos
uniform sampler2D texture1; // Textura
@

Estes dois códigos fontes serão processados pelo Makefile de cada
projeto antes da compilação e convertidos para um arquivo de texto em
que cada caractere será apresentado em formato hexadecimal separado
por vírgulas, usando o comando \monoespaco{xxd}. Assim, podemos
inserir tal código estaticamente em tempo de compilação com:

@<Shaders: Declarações@>=
extern char _vertex_interface[];
extern char _fragment_interface[];
struct _shader _default_interface_shader;
@
@<Shaders: Definições@>=
char _vertex_interface[] = {
#include "vertex_interface.data"
        , 0x00};
char _fragment_interface[] = {
#include "fragment_interface.data"
    , 0x00};
@

Como compilar um shader de vértice e fragmento? Para isso usaremos a
função auxiliar e macros auxiliares:

@<Shaders: Declarações@>+=
GLuint _compile_shader(char *source, bool vertex);
#define _compile_vertex_shader(source) _compile_shader(source, true)
#define _compile_fragment_shader(source) _compile_shader(source, false)
@

@<Shaders: Definições@>+=
GLuint _compile_shader(char *source, bool vertex){
    GLuint shader;
    GLint success = 0, logSize = 0;
    // Criando shader de vértice
    if(vertex)
        shader = glCreateShader(GL_VERTEX_SHADER);
    else
        shader = glCreateShader(GL_FRAGMENT_SHADER);
    // Associando-o ao código-fonte do shader:
    glShaderSource(shader, 1, (const GLchar **) &source, NULL);
    // Compilando:
    glCompileShader(shader);
    // Checando por erros de compilação do shader de vértice:
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if(success == GL_FALSE){
        char *buffer;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logSize);
        buffer = (char *) _iWalloc(logSize);
        if(buffer == NULL){
            fprintf(stderr, "ERROR (0): Shader failed to compile. "
                    "It wasn't possible to discover why because there's no "
                    "enough internal memory. Please, increase "
                    "the value of W_INTERNAL_MEMORY at conf/conf.h and try "
                    "to run this program again.\n");
            exit(1);
        }
        glGetShaderInfoLog(shader, logSize, NULL, buffer);
        fprintf(stderr, "ERROR (0): Failed to compile shader: %s\n",
                buffer);
        Wfree(buffer);
        exit(1);
    }
    return shader;
}
@

E para ligar ambos os shaders usamos em seguida a seguinte função que
gera um novo programa de shader e também encerra os shaders
pré-compilação:

@<Shaders: Declarações@>+=
GLuint _link_and_clean_shaders(GLuint vertex, GLuint fragment);
@

@<Shaders: Definições@>+=
GLuint _link_and_clean_shaders(GLuint vertex, GLuint fragment){
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    // Ligar o shader pode falhar. Testando por erros:
    {
        int isLinked = 0;
        GLint logSize = 0;
        glGetProgramiv(program, GL_LINK_STATUS, &isLinked);
        if(isLinked == GL_FALSE){
            char *buffer;
            glGetShaderiv(program, GL_INFO_LOG_LENGTH, &logSize);
            buffer = (char *) _iWalloc(logSize);
            if(buffer == NULL){
                fprintf(stderr, "ERROR (0): Shaders failed to link. It wasn't "
                        "possible to discover why because there's no enough "
                        "internal memory. Please, increase "
                        "the value of W_INTERNAL_MEMORY at conf/conf.h and try "
                        "to run this program again.\n");
                exit(1);
            }
            glGetShaderInfoLog(program, logSize, NULL, buffer);
            fprintf(stderr, "ERROR (0): Failed to link shader: %s\n", buffer);
            Wfree(buffer);
            exit(1);
        }
    }
    glDetachShader(program, vertex);
    glDetachShader(program, fragment);
    return program;
}
@

Ambas as funções devem ser usadas em conjunto sempre. No caso dos
shaders padrão para interfaces, vamos usá-las para compilá-los:

@<API Weaver: Inicialização@>+=
{
    GLuint vertex, fragment;
    vertex = _compile_vertex_shader(_vertex_interface);
    fragment = _compile_fragment_shader(_fragment_interface);
    // Além de compilar, para deixar o shader padrão completo, nós
    // preenchemos seus uniformes e atributos abaixo:
    _default_interface_shader.program_shader =
        _link_and_clean_shaders(vertex, fragment);
    _default_interface_shader._uniform_object_color =
        glGetUniformLocation(_default_interface_shader.program_shader,
                             "object_color");
    _default_interface_shader._uniform_model_view =
        glGetUniformLocation(_default_interface_shader.program_shader,
                             "model_view_matrix");
    _default_interface_shader._uniform_object_size =
        glGetUniformLocation(_default_interface_shader.program_shader,
                             "object_size");
    _default_interface_shader._uniform_time =
        glGetUniformLocation(_default_interface_shader.program_shader,
                             "time");
    _default_interface_shader._attribute_vertex_position =
        glGetAttribLocation(_default_interface_shader.program_shader,
                            "vertex_position");
}
@

E na finalização do programa precisamos desalocar o shader compilado:

@<API Weaver: Finalização@>+=
glDeleteProgram(_default_interface_shader.program_shader);
@

@*2 Shaders personalizados.

Vamos agora entender as complexidades de escrever um código para os
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
    // Os uniformes do shader:
    GLint _uniform_object_color, _uniform_model_view, _uniform_object_size;
    GLint _uniform_time, _uniform_texture1;
    // Os atributos do shader:
    GLint _attribute_vertex_position;
    char *vertex_source, *fragment_source; // Arquivo do código-fonte
#if W_TARGET == W_ELF
    // Os inodes dos arquivos nos dizem se o código-fonte foi
    // modificado desde a última vez que o compilamos:
    ino_t vertex_inode, fragment_inode;
#endif
};

#if W_TARGET == W_ELF
  // Se estamos compilando nativamente para Linux, iremos allocar
  // dinamicamente a nossa lista de shaders
  struct _shader *_shader_list;
#else
  // Se não, usaremos uma lista estaticamente declarada gerada pelo
  // Makefile
#include "../../.hidden_code/shader.h"
#endif
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
    char shader_directory[256];
    DIR *d;
    shader_directory[0] = '\0';
#if W_DEBUG_LEVEL == 0
    strcat(shader_directory, W_INSTALL_DIR);
#endif
    strcat(shader_directory, "shaders/");
    // Pra começar, abrimos o diretório e percorremos os arquivos para
    // contar quantos diretórios tem ali:
    d = opendir(shader_directory);
    if(d){
        struct dirent *dir;
        // Lendo o nome para checar se é um diretório não-oculto cujo
        // nome segue a convenção necessária:
        while((dir = readdir(d)) != NULL){
            if(dir -> d_name[0] == '.') continue; // Ignore arquivos ocultos
            if(atoi(dir -> d_name) == 0){
                fprintf(stderr, "WARNING (0): Shader being ignored. "
                        "%s%s should start with number different than zero.\n",
                        shader_directory, dir -> d_name);
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
    //} //Coninua abaixo
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

E agora que alocamos, podemos começar a percorrer os shaders e checar
se todos eles podem ficar em uma posição de acordo com seu número no
vetor alocado, checar se dois deles não possuem o mesmo número (isso
garante que todos eles possuem números seqüenciais) e também compilar
o Shader.

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
    //{ //Continua do código acima
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
            {
                int shader_number = atoi(dir -> d_name);
                if(shader_number > number_of_shaders){
#if W_DEBUG_LEVEL >= 1
                    fprintf(stderr, "WARNING (1): Non-sequential shader "
                            "enumeration at %s.\n", shader_directory);
#endif
                    continue;
                }
                if(_shader_list[shader_number - 1].initialized == true){
#if W_DEBUG_LEVEL >= 1
                    fprintf(stderr, "WARNING (1): Two shaders enumerated "
                            "with number %d at %s.\n", shader_number,
                            shader_directory);
#endif
                    continue;
                }
                // Usando função auxiliar para o trabalho de compilar
                // e inicializar cada programa de shader. Ela ainda
                // precisa ser declarada e definida:
                {
                    char path[256];
                    strcpy(path, shader_directory);
                    strcat(path, dir -> d_name);
                    path[255] = '\0';
                    _compile_and_insert_new_shader(path, shader_number - 1);
                }
            }
        }
    }
}
#endif
@

Só precisamos lidar com isso quando compilamos o programa para Linux,,
caso em que a lista de shaders é preenchida dinamicamente de maneira
mais elegante. Mas no caso de um programa Emscripten, apenas inserimos
código gerado pelo Makefile:

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_WEB
#include "../../.hidden_code/initialize_shader.c"
#endif
@

A função |_compile_and_insert_new_shader(nome, posicao)| usada
acima ainda não foi definida. A função dela será abrir o diretório
cujo nome é passado como primeiro argumento e preencher em
|_shader_list[posicao]| as informações do shader. Isso envolve compilar e
gerar o shader, bem como adquirir outras informações referentes à ele
e que fazem parte de um |struct shader|.

Declaremos e definamos a função:

@<Shaders: Declarações@>+=
void _compile_and_insert_new_shader(char *dir, int position);
@

@<Shaders: Definições@>+=
void _compile_and_insert_new_shader(char *dir, int position){
    char *vertex_file = NULL, *fragment_file = NULL;
    char *vertex_source = NULL, *fragment_source = NULL;
    off_t vertex_size = 0, fragment_size = 0;
    GLuint vertex, fragment;
    char *p;
    int i;
    FILE *fp;
    // Marcamos o shader como inicializado:
    _shader_list[position].initialized = true;
    // Começamos obtendo o nome do shader, que é o nome do diretório
    // passado (mas sem o seu caminho completo)
    for(p = dir; *p != '\0'; p ++); // Vamos ao fim da string
    while(*(p - 1) == '/') p --; // Voltamos se ela termina em '/'
    while(*(p - 1) != '/' && p - 1 != dir) p --; // Vamos ao começo do nome
    for(i = 0; p[i] != '\0' && p[i] != '/' && i < 127; i ++)
        _shader_list[position].name[i] = p[i]; // Copiando
    _shader_list[position].name[i] = '\0'; // Encerrando
    // Checando existência do código-fonte de shader de vértice:
    vertex_file = (char *) _iWalloc(strlen(dir) + strlen("/vertex.glsl") + 1);
    vertex_file[0] = '\0';
    strcat(vertex_file, dir);
    strcat(vertex_file, "/vertex.glsl");
    // Vendo se arquivo existe e pode ser lido:
    if((fp = fopen(vertex_file, "r"))){
        _shader_list[position].vertex_source = vertex_file;
        fclose(fp);
    }
    else{
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): Vertex shader source code not found. "
                "File %s was expected. Using a default shader instead.\n",
                vertex_file);
#endif
        _shader_list[position].vertex_source = NULL;
        Wfree(vertex_file);
        vertex_file = NULL;
    }
    // Checando existência do código-fonte de shader de fragmento:
    fragment_file = (char *) _iWalloc(strlen(dir) + strlen("/fragment.glsl" +
                                                           1));
    fragment_file[0] = '\0';
    strcat(fragment_file, dir);
    strcat(fragment_file, "/fragment.glsl");
    if((fp = fopen(fragment_file, "r"))){
        _shader_list[position].fragment_source = fragment_file;
        fclose(fp);
    }
    else{
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): Fragment shader source code not found. "
                "File '%s' was expected. Using a default shader instead.\n",
                fragment_file);
#endif
        _shader_list[position].fragment_source = NULL;
        Wfree(fragment_file);
        fragment_file = NULL;
    }
    // Se o arquivo com código do shader de vértice existe, obter o
    // seu inode e tamanho. O inode é ignorado no Emscripten
    if(_shader_list[position].vertex_source != NULL){
        int fd;
        fd = open(_shader_list[position].vertex_source, O_RDONLY);
        if (fd < 0) {
            fprintf(stderr, "WARNING (0): Can't read vertex shader source"
                    " code at %s. Using a default shader instead.\n",
                    _shader_list[position].vertex_source);
            // Not freeing _shader_list[position].vertex_source. This
            // is an anomalous situation. In some cases we can't free
            // the memory at the correct order, so we will tolerate
            // this leak until the end of the program, when it finally
            // will be freed
            _shader_list[position].vertex_source = NULL;
        }
        else{
            int ret;
            struct stat attr;
            ret = fstat(fd, &attr);
            if(ret < 0){ // Can't get file stats
                fprintf(stderr, "WARNING (0): Can't read shader source file"
                        " stats: %s. Ignoring source code and using a default"
                        "shader code.\n",
                        _shader_list[position].vertex_source);
                _shader_list[position].vertex_source = NULL;
            }
            else{
#if W_TARGET == W_ELF
                _shader_list[position].vertex_inode = attr.st_ino;
#endif
                vertex_size = attr.st_size;
            }
            close(fd);
        }
    }
    // Fazer o mesmo para o arquivo com código do shader de fragmento:
    if(_shader_list[position].fragment_source != NULL){
        int fd;
        struct stat attr;
        fd = open(_shader_list[position].fragment_source, O_RDONLY);
        if (fd < 0) {
            fprintf(stderr, "WARNING (0): Can't read fragment shader source"
                    " code at %s. Using a default shader instead.\n",
                    _shader_list[position].fragment_source);
            _shader_list[position].fragment_source = NULL;
        }
        else{
            int ret;
            ret = fstat(fd, &attr);
            if(ret < 0){ // Can't get file stats
                fprintf(stderr, "WARNING (0): Can't read shader source file"
                        " stats: %s. Ignoring source code and using a default"
                        "shader code.\n",
                        _shader_list[position].fragment_source);
                _shader_list[position].fragment_source = NULL;
            }
            else{
#if W_TARGET == W_ELF
                _shader_list[position].fragment_inode = attr.st_ino;
#endif
                fragment_size = attr.st_size;
            }
            close(fd);
        }
    }
    // Alocando espaço para colocar na memória o código-fonte dos shaders:
    if(_shader_list[position].vertex_source != NULL){
        vertex_source = (char *) _iWalloc(vertex_size);
        if(vertex_source == NULL){
            fprintf(stderr, "WARNING (0): Can't read shader source code at %s."
                    " File too big.\n", vertex_file);
#if W_DEBUG_LEVEL >= 1
            fprintf(stderr, "WARNING (1): You should increase the value of "
                    "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
            _shader_list[position].vertex_source = NULL;
        }
    }
    if(_shader_list[position].fragment_source != NULL){
        fragment_source = (char *) _iWalloc(fragment_size);
        if(fragment_source == NULL){
            fprintf(stderr, "WARNING (0): Can't read shader source code at %s."
                    " File too big.\n", fragment_file);
#if W_DEBUG_LEVEL >= 1
            fprintf(stderr, "WARNING (1): You should increase the value of "
                    "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
            _shader_list[position].fragment_source = NULL;
        }
    }
    // Após alocar o espaço, lemos o conteúdo dos arquivos para a memória
    if(_shader_list[position].vertex_source != NULL) {
        FILE *fd = fopen(_shader_list[position].vertex_source, "r");
        if(fd == NULL){
            fprintf(stderr, "WARNING (0): Can't read shader source code at"
                    " %s.\n", vertex_file);
            perror(NULL);
            _shader_list[position].vertex_source = NULL;
        }
        else{
            fread(vertex_source, sizeof(char), vertex_size, fd);
            vertex_source[vertex_size - 1] = '\0';
            fclose(fd);
        }
    }
    if(_shader_list[position].fragment_source != NULL) {
        FILE *fd = fopen(_shader_list[position].fragment_source, "r");
        if(fd == NULL){
            fprintf(stderr, "WARNING (0): Can't read shader source code at"
                    " %s.\n", fragment_file);
            perror(NULL);
            _shader_list[position].fragment_source = NULL;
        }
        else{
            fread(fragment_source, sizeof(char), fragment_size, fd);
            fragment_source[fragment_size - 1] = '\0';
            fclose(fd);
        }
    }
    // Tendo feito isso, o que resta a fazer é enfim compilar e ligar
    // o programa.
    if(_shader_list[position].vertex_source != NULL)
        vertex = _compile_vertex_shader(vertex_source);
    else
        vertex = _compile_vertex_shader(_vertex_interface);
    if(_shader_list[position].fragment_source != NULL)
        fragment = _compile_fragment_shader(fragment_source);
    else
        fragment = _compile_fragment_shader(_fragment_interface);
    _shader_list[position].program_shader = _link_and_clean_shaders(vertex,
                                                                    fragment);
    // Inicializando os uniformes:
    _shader_list[position]._uniform_object_color =
        glGetUniformLocation(_shader_list[position].program_shader,
                             "object_color");
    _shader_list[position]._uniform_object_size =
        glGetUniformLocation(_shader_list[position].program_shader,
                             "object_size");
    _shader_list[position]._uniform_time =
        glGetUniformLocation(_shader_list[position].program_shader,
                             "time");
    _shader_list[position]._uniform_texture1 =
        glGetUniformLocation(_shader_list[position].program_shader,
                             "texture1");
    _shader_list[position]._uniform_model_view =
        glGetUniformLocation(_shader_list[position].program_shader,
                             "model_view_matrix");
    // Inicializando os atributos:
    _shader_list[position]._attribute_vertex_position =
        glGetAttribLocation(_shader_list[position].program_shader,
                            "vertex_position");
    // Desalocando se ainda não foram desalocados:
    if(fragment_source != NULL) Wfree(fragment_source);
    if(vertex_source != NULL) Wfree(vertex_source);
}
@

@*1 Renderizando.

Interfaces que tem o mesmo shader devem ser renderizadas em sequência
para evitarmos aso máximo a ação de termos que trocar de shaders. Por
isso, é importante que mantenhamos uma lista de ponteiros para shaders
e que seja ordenada de acordo com o seu shader. E cada loop também
deve possuir a sua própria lista de interfaces.

@<Interface: Declarações@>+=
struct interface *_interface_queue[W_LIMIT_SUBLOOP][W_MAX_INTERFACES];
@

A nossa lista de interfaces deve ser inicializada:

@<API Weaver: Inicialização@>+=
{
    int i, j;
    for(i = 0; i < W_LIMIT_SUBLOOP; i ++)
        for(j = 0; j < W_MAX_INTERFACES; j ++)
            _interface_queue[i][j] = NULL;
}
@

Temos agora que definir funções para inserir e remover elementos da
lista. E uma terceira função para limpar todo o seu conteúdo. Ao
manipular uma lista de ponteiros para interfaces, fazemos isso sempre
na lista do loop atual, nunca interferindo nos demais loops.

Para inserir elementos, como eles estarão todos ordenados, podemos
usar uma busca binária para achar a posição na qual inserir. Lembrando
que o loop atual é armazenado em |_number_of_loops| conforme definido
no Capítulo 2.

Assim, eis o nosso código de inserção:

@<Interface: Declarações@>+=
void _insert_interface_queue(struct interface *inter);
@

@<Interface: Definições@>+=
void _insert_interface_queue(struct interface *inter){
    int begin, end, middle, tmp;
    int type = inter -> type;
    if(_interface_queue[_number_of_loops][W_MAX_INTERFACES - 1] != NULL){
        fprintf(stderr, "WARNING (0): Couldn't create new interface. You should "
                "increase the value of W_MAX_INTERFACES at cont/conf.h or "
                "decrease the number of inerfaces created.\n");
        return;
    }
    begin = 0;
    end = W_MAX_INTERFACES - 1;
    middle = (begin + end) / 2;
    while((_interface_queue[_number_of_loops][middle] == NULL ||
           _interface_queue[_number_of_loops][middle] -> type != type) &&
          begin != end){
        if(_interface_queue[_number_of_loops][middle] == NULL ||
           _interface_queue[_number_of_loops][middle] -> type < type){
            tmp = (middle + end) / 2;
            if(tmp == end) end --;
            else end = tmp;
            middle = (begin + end) / 2;
        }
        else{
            tmp = (middle + begin) / 2;
            if(tmp == begin) begin ++;
            else begin = tmp;
            middle = (begin + end) / 2;
        }
    }
    // Agora a posição 'middle' contém o local em que iremos inserir
    // Vamos abrir espaço para ela
    for(tmp = W_MAX_INTERFACES - 1; tmp >= middle; tmp --)
        _interface_queue[_number_of_loops][tmp] =
            _interface_queue[_number_of_loops][tmp - 1] ;
    // E enfim inserimos:
    _interface_queue[_number_of_loops][middle] = inter;
}
@

Remover o conteúdo da lista funciona de forma análoga, usando uma
busca binária para achar o elemento buscado e, se for encontrado,
deslocamos todas as próximas interfaces para tomar o seu lugar:

@<Interface: Declarações@>+=
void _remove_interface_queue(struct interface *inter);
@

@<Interface: Definições@>+=
void _remove_interface_queue(struct interface *inter){
    int begin, end, middle, tmp;
    int type = inter -> type;
    begin = 0;
    end = W_MAX_INTERFACES - 1;
    middle = (begin + end) / 2;
    while((_interface_queue[_number_of_loops][middle] == NULL ||
           _interface_queue[_number_of_loops][middle] -> type != type)
          && begin != end){
        if(_interface_queue[_number_of_loops][middle] == NULL ||
           _interface_queue[_number_of_loops][middle] -> type < type){
            tmp = (middle + end) / 2;
            if(tmp == end) end --;
            else end = tmp;
            middle = (begin + end) / 2;
        }
        else{
            tmp = (middle + begin) / 2;
            if(tmp == begin) begin ++;
            else begin = tmp;
            middle = (begin + end) / 2;
        }
    }
    // Vamos ao primeiro elemento do tipo de interface na qual terminamos
    while(middle > 0 && _interface_queue[_number_of_loops][middle] != NULL &&
          _interface_queue[_number_of_loops][middle] -> type ==
          _interface_queue[_number_of_loops][middle - 1] -> type)
        middle --;
    if(_interface_queue[_number_of_loops][middle] -> type != type){
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr,
                "WARNING (1): Tried to erase a non-existent interface.\n");
#endif
        return;
    }
    // Agora tentando achar o ponteiro exato, já que achamos o começo
    // de seu tipo:
    while(_interface_queue[_number_of_loops][middle] != NULL &&
          _interface_queue[_number_of_loops][middle] -> type == type &&
          _interface_queue[_number_of_loops][middle] != inter)
        middle ++;
    // Se achamos, apagamos o elemento movendo os próximos da fila
    // para a sua posição:
    if(_interface_queue[_number_of_loops][middle] == inter){
        while(_interface_queue[_number_of_loops][middle] != NULL &&
              middle != W_MAX_INTERFACES - 1){
            _interface_queue[_number_of_loops][middle] =
                _interface_queue[_number_of_loops][middle + 1];
            middle ++;
        }
        _interface_queue[_number_of_loops][W_MAX_INTERFACES - 1] = NULL;
    }
    else{ // Se não achamos, avisamos com mensagem de erro:
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr,
                "WARNING (1): Tried to erase a non-existent interface.\n");
#endif
        return;
    }
}
@

E por fim o código para remover todas as interfaces do loop atual:

@<Interface: Declarações@>+=
void _clean_interface_queue(void);
@

@<Interface: Definições@>+=
void _clean_interface_queue(void){
    int i;
    for(i = 0; i < W_MAX_INTERFACES; i ++)
        _interface_queue[_number_of_loops][i] = NULL;
}
@

Devemos sempre limpar a fila de renderização de interfaces
imediatamente antes de entrar em um loop (mas não subloop) e quando
saímos de um subloop:

@<Código antes de Loop, mas não de Subloop@>+=
  _clean_interface_queue();
@

E também precisamos fazer a mesma limpeza no caso de estarmos saindo
de um subloop:

@<Código após sairmos de Subloop@>+=
  _clean_interface_queue();
@

Devemos inserir uma nova interface na lista de renderização toda vez
que uma nova interface for criada:

@<Código logo após criar nova interface@>=
  // O 'i' é a posição em que está a nova interface criada:
  _insert_interface_queue(&(_interfaces[_number_of_loops][i]));
@

E finalmente, quando removemos uma interface, nós também a removemos
da fila de renderização:

@<Código ao Remover Interface@>=
  // aqui 'i' também é o número da interface a ser removida
  _remove_interface_queue(&(_interfaces[_number_of_loops][i]));
@

Agora que mantemos a fila de renderização coerente com a nossa lista
de interfaces, podemos então escrever o código para efetivamente
renderizarmos as interfaces. Isso deve ser feito todo loop, na etapa
de renderização, separada da engine de física e controle do jogo.

@<Renderizar Interface@>=
{
    // Lembrando que '_number_of_loops' contém em qual subloop nós
    // estamos no momento.
    int last_type;
    int i;
    bool first_element = true;
    struct _shader *current_shader;
    // Primeiro limpamos o buffer de profundidade para que a interface
    // sempre apareça
    glClear(GL_DEPTH_BUFFER_BIT);
    // Ativamos os vértices das interfaces:
    glBindVertexArray(_interface_VAO);
    // Agora iteramos sobre as interfaes renderizando-as. Como elas
    // estão ordenadas de acordo com seu programa de shader, trocamos
    // de programa o mínimo possível.
    for(i = 0; i < W_MAX_INTERFACES; i ++){
        // Se chegamos ao im da fila, podemos sair:
        if(_interface_queue[_number_of_loops][i] == NULL) break;
        if(!(_interface_queue[_number_of_loops][i] -> visible)) continue;
        if(first_element ||
           _interface_queue[_number_of_loops][i] -> type != last_type){
            last_type = _interface_queue[_number_of_loops][i] -> type;
            if(_interface_queue[_number_of_loops][i] -> type > 0){
                current_shader =
                    &(_shader_list[_interface_queue[_number_of_loops][i] ->
                                   type - 1]);
            }
            else{
                current_shader = &_default_interface_shader;
            }
            glUseProgram(current_shader -> program_shader);
            first_element = false;
        }
        // Agora temos que passar os uniformes relevantes da
        // interface para o shader:
        glUniform4f(current_shader -> _uniform_object_color,
                    _interface_queue[_number_of_loops][i] -> r,
                    _interface_queue[_number_of_loops][i] -> g,
                    _interface_queue[_number_of_loops][i] -> b,
                    _interface_queue[_number_of_loops][i] -> a);
        glUniform2f(current_shader -> _uniform_object_size,
                    _interface_queue[_number_of_loops][i] -> width,
                    _interface_queue[_number_of_loops][i] -> height);
        glUniform1f(current_shader -> _uniform_time,
                    (float) W.t / (float) 1000000);
        glUniformMatrix4fv(current_shader -> _uniform_model_view, 1, false,
                           _interface_queue[_number_of_loops][i] ->
                           _transform_matrix);
        // Ajustando as configurações de como os vértices são armazenados:
        glEnableVertexAttribArray(current_shader -> _attribute_vertex_position);
        glVertexAttribPointer(current_shader -> _attribute_vertex_position,
                              3, GL_FLOAT, GL_FALSE, 0, (void*)0);
        glDrawArrays(_interface_queue[_number_of_loops][i] -> _mode, 0, 4);
        glDisableVertexAttribArray(current_shader ->
                                   _attribute_vertex_position);
    }
    // Parando de usar o VAO com as configurações de renderização de
    // interface:
    glBindVertexArray(0);
}
@

@*1 Lidando com Redimensionamento da Janela.

Toda vez que uma janela tem o seu tamanho modificado, precisamos mover
todas as interfaces para atualizar a sua posição e assim manter a
proporção da tela que fica acima, abaixo e em cada uma de suas
laterais. Assim, se uma janela ocupa a metade de cima da tela e existe
uma interface cuja posição é a parte de baixo da tela, após mudarmos
para tela-cheia, a interface deve permanecer na parte de baixo da
tela, e não no centro.

Além disso, uma interface pode ou não esticar ou encolher de acordo
com a mudança de tamanho da janela. Para isso, são os seus atributos
|stretch_X| e |stretch_y| que definem isso.

@<Ações após Redimencionar Janela@>=
{
    // old_width, old_height: Tamanho antigo
    // width, height: Tamanho atual
    int i, j;
    int change_x = width - old_width;
    int change_y = height - old_height;
    float new_width, new_height;
    for(i = 0; i < W_LIMIT_SUBLOOP; i ++)
        for(j = 0; j < W_MAX_INTERFACES; j ++){
            if(_interfaces[i][j].type == W_NONE) continue;
            W.move_interface(&_interfaces[i][j],
                             _interfaces[i][j].x + ((float) change_x) / 2,
                             _interfaces[i][j].y + ((float) change_y) / 2);
            if(_interfaces[i][j].stretch_x)
                new_width = _interfaces[i][j].width *
                    ((float) width  / (float) old_width);
            else new_width = _interfaces[i][j].width;
            if(_interfaces[i][j].stretch_y)
                new_height = _interfaces[i][j].height *
                    ((float) height  / (float) old_height);
            else new_height = _interfaces[i][j].height;
            W.resize_interface(&_interfaces[i][j], new_width, new_height);
        }
}
@

@*1 A Resolução da Tela.

Agora que estamos suportando shaders, é o momento no qual podemos
enfim suportar diferentes tiopos de resolução. A melhor forma de fazer
isso é checando se estamos renderizando na resolução nativa de noss
monitor e sistema ou não. Se estivermos, devemos renderizar todas as
imagens para uma texura cujo tamanho é a resolução que desejamos. Em
seguida, renderizamos tal textura para que ocupe a tela toda.

Esta não é a uúnica forma de mudar a resolução. Existem outras formas
mais invasivas que envolvem mudar nas configuraões do próprio X no
Linux. Mas é uma péssima ideia fazer isso da maneira mais invasiva
como faziam jogos mais antigos. Se o nosso programa encerrar de
maneira anormal, como uma falha de segmentação, é bastante complicado
escrever código robusto para que ele consiga restaurar com segurança a
nossa resolução e encerrar de maneira elegante. E se o nosso programa
for encerrado à força pelo próprio Sistema Operacional
(\monoespaco{kill -9}), então não há nada que possamos fazer e a
resolução não voltará ao valor padrão ao encerrar o programa.

Atualmente as GPUs e computadores estão rápidos o bastante para que
possamos usar o método menos invasivo sem tanta penalidade de
performance. E a ideia de diminuir a resolução é justamente obter o
ganho de desempenho para que hajam menos pixels individuais a serem
processados pelo nosso shader de fragmento.

A resolução da tela é armazenada em |W.resolution_x| e
|W.resolution_y|.  A resolução nativa da janela é armazenada nas
variáveis |W.window_resolution_x| e |W.window_resolution_y|. A
resolução do jogo em si até agora era sempre igual à resolução da
janela e era armazenada em |W.width| e |W.height|. Mas agora isso vai
mudar e esta resolução pode ser diferente da janela:

@<Cabeçalhos Weaver@>+=
bool _changed_resolution;
// Usaremos os elementos abaixos para renderizar a tela se não
// estivermos na resolução nativa:
  GLuint _framebuffer, _texture_screen, _depth_texture;
@

Tipicamente tais valores são inicializados como sendo iguais ao
|W.width| e |W.height|:

@<API Weaver: Inicialização@>+=
{
    _changed_resolution = false;
}
@

Se a resolução foi modificada, não mantemos mais a igualdade entre a
resolução da janela e do jogo. Mas se ela não foi modificada, então a
resolução do jogo deve ser mantida consistente caso a janela seja
redimencionada:

@<Ações após Redimencionar Janela@>+=
{
    // width e height são o novo tamanho após a janela ser
    // redimencionada:
    if(!_changed_resolution){
        W.width = width;
        W.height = height;
    }
}
@

Vamos agora mudar a resolução do jogo (mas não da tela ou da
janela). Definiremos uma função para isso:

@<Cabeçalhos Weaver@>=
bool _set_resolution(int width, int height);
@

@<API Weaver: Definições@>+=
bool _set_resolution(int width, int height){
    GLenum DrawBuffers[1] = {GL_COLOR_ATTACHMENT0};
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&_window_mutex);
#endif
// Se estávamos na resolução nativa, temos que criar o novo
// framebuffer e textura:
    if(!_changed_resolution){
        // Criando um novo framebuffer
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        // Criando o buffer de profundidade:
        glGenRenderbuffers(1, &_depth_texture);
        glBindRenderbuffer(GL_RENDERBUFFER, _depth_texture);
        // Criando a textura:
        glGenTextures(1, &_texture_screen);
        glBindTexture(GL_TEXTURE_2D, _texture_screen);
        // Começamos passando uma imagem vazia para ela:
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
                     GL_UNSIGNED_BYTE, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        // Criando o buffer de profundidade:
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT,
                              width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                  GL_RENDERBUFFER, _texture_screen);
        // Ligamos a textura ao framebuffer
        glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                             _texture_screen, 0);
        glDrawBuffers(1, DrawBuffers);
        // Checagem de erros:
        if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE){
#ifdef W_MULTITHREAD
            pthread_mutex_unlock(&_window_mutex);
#endif
            return false;
        }
        _changed_resolution = true;
    }
    else{
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glBindTexture(GL_TEXTURE_2D, _texture_screen);
        // Começamos passando uma imagem vazia para ela:
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
                     GL_UNSIGNED_BYTE, 0);
    }
    W.width = width;
    W.height = height;
    // Atualiza a matriz da interfaces em relação à mudança de
    // resolução da janela:
    _update_interface_screen_size();
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&_window_mutex);
#endif
    return true;
}
@

Instalando a nova função na estrutura |W|:

@<Funções Weaver@>+=
bool (*set_resolution)(int, int);
@


@<API Weaver: Inicialização@>+=
W.set_resolution = &_set_resolution;
@

Então, se modificamos a resolução precisamos avisar que toda a
renderização que faremos será primeiro em uma textura com a resolução
correta---o nosso framebuffer:

@<Antes da Renderização@>=
if(_changed_resolution){
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindTexture(GL_TEXTURE_2D, _texture_screen);
    glViewport(0, 0, W.width, W.height);
}
@

Mas uma vez que tudo seja renderizado no framebuffer, nós precisamos
então ter um quadrado para o renderizarmos na tela usando o nosso
framebuffer como textura. E vamos precisar também de um shader. Para
isso, podemos usar as mesmas coordenadas de vértice das interfaces.

Mas vamos precisar de nosso próprio shader para lidar com isso. Pois o
shader padrão para interfaces não lida com texturas.

@<Shaders: Declarações@>=
extern char _vertex_interface_texture[];
extern char _fragment_interface_texture[];
struct _shader _framebuffer_shader;
@

@<Shaders: Definições@>=
char _vertex_interface_texture[] = {
#include "vertex_interface_texture.data"
        , 0x00};
char _fragment_interface_texture[] = {
#include "fragment_interface_texture.data"
    , 0x00};
@

Nosso novo shader de vértice:

@(project/src/weaver/vertex_interface_texture.glsl@>=
#version 100

attribute mediump vec3 vertex_position;

varying mediump vec2 coordinate;

void main(){
    // Apenas esticamos o quadrado com este vetor para ampliar seu
    // tamanho e ele cobrir toda a tela:
     highp mat4 m = mat4(vec4(2, 0, 0, 0), vec4(0, 2, 0, 0),
                        vec4(0, 0, 2, 0), vec4(0, 0, 0, 1));
     gl_Position = m * vec4(vertex_position, 1.0);
     // Coordenada da textura:
     // XXX: É assim que se obtém a coordenada?
     coordinate = vec2(((vertex_position[0] + 1.0) / 2.0),
                       1.0-((vertex_position[1] + 1.0) / 2.0));
}
@

E nosso shader de fragmento, que efetivamente usa a textura:

@(project/src/weaver/fragment_interface_texture.glsl@>=
#version 100

uniform sampler2D texture1;

varying mediump vec2 coordinate;

void main(){
    //gl_FragData[0] = vec4(1, 0, 0, 1);
    //gl_FragData[0] = vec4(coordinate.x, coordinate.y, 0, 1);
    gl_FragData[0] = texture2D(texture1, coordinate);
}
@

Pra começar então, vamos precisar compilar este programa GLSL e vamos
ter que armazenar a posição de seu atributo de coordenada e de seu
valor uniforme de textura. Faremos isso durante o começo do programa,
para estarmos prontos mesmo que o usuário opte por não mudar a
resolução de sua tela:

@<API Weaver: Inicialização@>+=
{
    GLuint vertex, fragment;
    vertex = _compile_vertex_shader(_vertex_interface_texture);
    fragment = _compile_fragment_shader(_fragment_interface_texture);
    // Preenchendo variáeis uniformes e atributos:
    _framebuffer_shader.program_shader =
        _link_and_clean_shaders(vertex, fragment);
    _framebuffer_shader._uniform_texture1 =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "texture1");
    _framebuffer_shader._attribute_vertex_position =
        glGetAttribLocation(_framebuffer_shader.program_shader,
                            "vertex_position");
}
@

Tendo todos os shaders prontos, podemos então usá-lo para renderizar o
nosso framebuffer depois que acabamos de renderizar tudo nele:

@<Depois da Renderização@>=
if(_changed_resolution){
    GLfloat cl[]={1.0, 0.0, 0.0, 1.0};
    glClearBufferfv(GL_FRAMEBUFFER, 0, cl);
    // Deixamos de usar o framebuffer para renderização:
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, W.window_resolution_x, W.window_resolution_y);
    // E renderizamos o framebuffer na tela:
    //glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glUseProgram(_framebuffer_shader.program_shader);
    glBindVertexArray(_interface_VAO);
    glEnableVertexAttribArray(0);
    glUniform1i(_framebuffer_shader._uniform_texture1, _texture_screen);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDisableVertexAttribArray(0);
    glBindVertexArray(0);
}
@

@*1 Sumário das Variáveis e Funções de Shaders e Interfaces.

\macronome A seguinte nova estrutura foi definida:

\noindent|struct interface {
    int type;
    float x, y, height, width, rotation, r, g, b, a;
    bool visible;
    bool stretch_x, stretch_y;
}|

\macrovalor|type|: representa o seu tipo, que pode ser
\monoespaco{W\-\_\-INTERFACE\-\_\-SQUARE},
|W_INTERFACE_PERIMETER| ou algum valor inteiro positivo que representa
 um shader personalizado definido pelo usuário. Outros tipos ainda
 serão definidos nos próximos capítulos. Valor para somnte leitura,
 não o modifique.

\macrovalor|float x, y|: representa a coordenada em que está a interface. Ela é
definida pela posição do seu centro dada em pixels. Valor para somente
leitura, não o modifique.

\macrovalor|float height, width|: representa a altura e largura da interface, em
pixels. Valor para somente leitura, não o modifique.

\macrovalor|float rotation|: representa a rotação da interface medida em
radianos, com a rotação no sentido anti-horário sendo considerada
positiva. Valor para somente leitura, não o modifique.

\macrovalor\monoespaco|float r, g, b, a|: A cor representada pelos canais
vermelho, verde, azul e o canal alfa para medir a transparência. Pode
ser modificado.

\macrovalor|bool visible|: Se a interface deve ser renderizada na tela ou não.

\macrovalor|bool stretch_x, stretch_y|: Se a interface deve ser esticada ou
encolhida quando a janela em que está muda de tamanho.

\macronome As seguintes 5 novas funções foram definidas:

\macrovalor|struct interface *W.new_interface(int type, int x, int y, ...)|:
Cria uma nova interface. O número e detalhes dos argumentos depende do
tipo. Para todos os tipos vistos neste capítulo e para tipos de
shaders sob medida, após as coordenadas $x, y$ da interface vem a sua
largura e altura. Embora sejam passados como inteiros, tanto a posição
como a altura e largura são depois convertidos para |float|. No caso
de interfaces que são meros quadrados ou perímetros, os próximos 4
argumentos são a cor. A nova interface gerada é retornada.

\macrovalor|void W.destroy_interface(struct interface *i)|: Destrói uma
interface, liberando seu espaço para ser usada por outra.

\macrovalor|void W.move_interface(struct interface *i, float x, float y)|:
Move uma interface para uma nova posição $(x, y)$

\macrovalor|void W.resize_interface(struct interface *i, float width, float height)|:
Muda a largura e altura de uma interface.

\macrovalor|void W.rotate_interface(struct interface *i, float rotation)|:
Muda a rotação de uma interface.
