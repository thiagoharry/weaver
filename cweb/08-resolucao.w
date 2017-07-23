@* Renderização em Duas Etapas.

% TODO: Ver porque o DEBUG_MODE 0 nãoo está funcionando com shaders finais
% TODO: Fazer os shaders finais serem locais a loop principal
% TODO: Fazer a mudança de resolução funcionar

Toda vez que renderizamos algo, renderizamos para um framebuffer.

Todo framebuffer é composto por um ou mais buffer. Pode haver um para
representar a cor de cada pixel (buffer de cor), outro para armazenar
a profundidade do que foi desenhado para impedir que objetos mais
distantes apareçam na frente de objetos mais próximos (buffer de
profundidade), um buffer que serve com uma máscara para delimitar onde
iremos ou não iremos de fato desenhar (buffer de stencil).

Até agora nós estivemos desenhando apenas no framebuffer padrão, o
qual é habilitado quando criamos o contexto OpenGL na
inicialização. Tal framebuffer simplesmente representa a janela de
nosso programa. Mas podemos renderizar as coisas também em outros
framebuffers. A ideia é que assim podemos renderizar texturas ou
aplicar efeitos especiais na imagem antes de passá-la para a tela. Um
dos tais efeitos especiais seria fazer com que o jogo tenha uma
resolução menor que a tela. Assim podemos reduzir a resolução caso ele
seja muito pesado, tentando assim economizar o desempenho gasto para
desenhar cada pixel na tela por meio do shader de fragmento. Em muitos
monitores com resolução muito alta, é bastante necessário que os jogos
forneçam a opção de escolha de resolução.

A primeira coisa que precisamos é de um novo framebuffer não-padrão, o
qual iremos declarar e gerar na inicialização. Além disso, precisamos
armazenar para cada loop que estivermos, se estamos usando um shader
fora do padrão para renderizar ou não. Se nós não mudamos a resolução,
iremos representar o shader final como |W_NONE|, o que significa que
não usaremos esse framebuffer alternativo e tudo que formos renderizar
vai direto para a tela. Se nós apenas mudamos a resolução, então vamos
representar essa opção pelo número -1, ou pelo seu equivalente que
estamos definindo, o |W_DEFAULT_SHADER|:

@<Cabeçalhos Weaver@>+=
#define W_NONE            0
#define W_DEFAULT_SHADER -1
@

@<Cabeçalhos Weaver@>+=
// Informa qual o shader final que deve ser usado em cada loop. Ou
// seja, qual shader deverá ser usado para renderizar a imagem final
// da tela depois de termos renderizado ela para uma imagem. O W_NONE
// indica que não usamos a renderização em dois passos, e sim
// renderizaremos direto para a tela. O W_DEFAULT_SHADER indica que
// nós mudamos a resolução, mas não pretendemos fazer qualquer mudança
// adicional na nossa imagem final além de restringir a resolução. Um
// inteiro positivo representa qual shader será usado para renderizar
// a imagem final.
int _final_shader[W_MAX_SUBLOOP];
// Apenas armazena se nós mudamos a resolução para fins de consulta
// interna:
bool _changed_resolution;
// E este é o framebuffer de renderização não-padrão que será usado em
// todos os casos, exceto quando nosso shader final for W_NONE:
GLuint _framebuffer;
@

@<API Weaver: Inicialização@>+=
{
  _changed_resolution = false;
  // Por padrão nós começamos não mudando a resolução e nem usando
  // qualquer shader adicional:
  int i;
  for(i = 0; i < W_MAX_SUBLOOP; i ++)
    _final_shader[i] = W_NONE;
  // Na inicialização geramos o nosso framebuffer de renderização
  // não-padrão:
  glGenFramebuffers(1, &_framebuffer);
  // A função acima só gera erro se passarmos um número negativo
  // como primeiro argumento.
  glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
}
@

@<API Weaver: Finalização@>+=
glDeleteFramebuffers(1, &_framebuffer);
@

Mas o framebuffer gerado não possui nenhum buffer ligado à ele.  Então
ele não está completo e não pode ser usado. Primeiramente nós
precisamos de um buffer de cor. E usaremos uma textura para isso. A
ideia é que iremos renderizar tudo na textura e em seguida aplicamos a
textura em um quadrado que renderizaremos ocupando toda a tela.

@<Cabeçalhos Weaver@>+=
// A textura na qual renderizaremos se estivermos fazendo uma
// renderização não-padrão.
GLuint _texture;
@

@<API Weaver: Inicialização@>+=
{
  // Gerando a textura:
  glGenTextures(1, &_texture);
  glBindTexture(GL_TEXTURE_2D, _texture);
  glTexImage2D(
               GL_TEXTURE_2D, // É uma imagem em 2D
               0, // Nível de detalhe. Não usaremos mipmaps aqui
               GL_RGB, // Formato interno do pixel
               W.width, // Largura
               W.height, // Altura
               0, // Borda: a especifiação pede que aqui sempre seja 0
               GL_RGB, GL_UNSIGNED_BYTE, // Formato dos pixels
               NULL); // NULL, pois os pixels serão criados dinamicamente
  // Ativa antialiasing para melhorar aparência de jogo em resolução
  // menor:
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  // Ligamos a nossa textura ao buffer de cor do framebuffer
  // não-padrão:
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                         GL_TEXTURE_2D, _texture, 0);
}
@

Mas o nosso framebuffer não-padrão precisa de mais buffers além de um
único bufer de cor. Vamos precisar de um buffer de profundidade. Como
temos certeza de que o que estamos criando será sempre interpretado
como uma imagem, ao invés de criar mais texturas para isso, criaremos
diretamente um buffer de renderização:

@<Cabeçalhos Weaver@>+=
// Buffer de renderização:
GLuint _depth_stencil;
@

@<API Weaver: Inicialização@>+=
{
  glGenRenderbuffers(1, &_depth_stencil);
  glBindRenderbuffer(GL_RENDERBUFFER, _depth_stencil);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16,
                        W.width, W.height);
  // Ligando o buffer de renderização ao framebuffer não-padrão:
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                            GL_RENDERBUFFER, _depth_stencil);
  
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}
@

Naturalmente, na finalização vamos querer limpar tudo o que fizemos:

@<API Weaver: Finalização@>+=
glDeleteTextures(1, &_texture);
glDeleteRenderbuffers(1, &_depth_stencil);
@

Feito isso, nosso framebuffer está pronto para ser usado em
renderização. Então, antes de começarmos a renderizar qualquer coisa,
devemos sempre checar onde devemos fazer isso. Direto na tela ou no
nosso fram3ebuffer alternativo?

@<Antes da Renderização@>=
if(_final_shader[_number_of_loops] != W_NONE){
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, W.width, W.height);
    glEnable(GL_DEPTH_TEST); // Avaliar se é necessário
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}
@

Mas se aconteceu de renderizarmos tudo para a nossa textura ao invés
de renderizarmos para a tela, vamos ter que, depois de toda
renderização, passar a textura para a tela. E este também é o
momento no qual temos que ver se não devemos aplicar algum efeito
especial na imagem por meio de algum shader personalizado.

Primeiro vamos definir qual é o shader padrão que usaremos caso nenhum
shader personalizado seja selecionado para renderizar nossa textura
(caso em que estejamos usando o |W_DEFAULT_SHADER|). E como iremos
renderizar usando shaders, vamos precisar de uma matriz que
representará o tamanho da nossa imagem na tela.

@<Shaders: Declarações@>=
extern char _vertex_interface_texture[];
extern char _fragment_interface_texture[];
struct _shader _framebuffer_shader;
GLfloat _framebuffer_matrix[16];
@

@<Shaders: Definições@>=
char _vertex_interface_texture[] = {
#include "vertex_interface_texture.data"
        , 0x00};
char _fragment_interface_texture[] = {
#include "fragment_interface_texture.data"
    , 0x00};
@

O código do shader de vértice é então:

@(project/src/weaver/vertex_interface_texture.glsl@>=
#version 100

attribute mediump vec3 vertex_position;

uniform mat4 model_view_matrix;
uniform vec4 object_color; // A cor do objeto
uniform vec2 object_size; // Largura e altura do objeto
uniform float time; // Tempo de jogo em segundos
uniform sampler2D texture1; // Textura
uniform int integer;

varying mediump vec2 coordinate;

void main(){
    // Apenas esticamos o quadrado com este vetor para ampliar seu
    // tamanho e ele cobrir toda a tela:
    gl_Position = model_view_matrix * vec4(vertex_position, 1.0);
     // Coordenada da textura:
     coordinate = vec2(((vertex_position[0] + 0.5)),
                       ((vertex_position[1] + 0.5)));
}
@

E o shader de fragmento:

@(project/src/weaver/fragment_interface_texture.glsl@>=
#version 100

uniform sampler2D texture1;

varying mediump vec2 coordinate;

void main(){
    gl_FragData[0] = texture2D(texture1, coordinate);
}
@

Tal novo shader precisa ser compilado na inicialização, assim como a
matriz do tamanho do framebuffer precisa ser inicializada.

@<API Weaver: Inicialização@>+=
{
    GLuint vertex, fragment;
    // Começamos assumindo que vamos usar o shader padrão que
    // definimos para a renderização final:
    vertex = _compile_vertex_shader(_vertex_interface_texture);
    fragment = _compile_fragment_shader(_fragment_interface_texture);
    // Preenchendo variáeis uniformes e atributos:
    _framebuffer_shader.program_shader =
        _link_and_clean_shaders(vertex, fragment);
    _framebuffer_shader._uniform_texture1 =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "texture1");
    _framebuffer_shader._uniform_object_color =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "object_color");
    _framebuffer_shader._uniform_model_view =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "model_view_matrix");
    _framebuffer_shader._uniform_object_size =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "object_size");
    _framebuffer_shader._uniform_time =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "time");
    _framebuffer_shader._uniform_integer =
        glGetUniformLocation(_framebuffer_shader.program_shader,
                             "integer");
    _framebuffer_shader._attribute_vertex_position =
        glGetAttribLocation(_framebuffer_shader.program_shader,
                            "vertex_position");
    // Inicializando matriz de transformação para:
    // 2 0 0 0
    // 0 2 0 0 <- Isso dobra o tamanho do polígono recebido
    // 0 0 2 0
    // 0 0 0 1
    _framebuffer_matrix[0] = _framebuffer_matrix[5] =
        _framebuffer_matrix[10] = 2.0;
    _framebuffer_matrix[15] = 1.0;
    _framebuffer_matrix[1] = _framebuffer_matrix[2] =
        _framebuffer_matrix[3] = _framebuffer_matrix[4] =
        _framebuffer_matrix[6] = _framebuffer_matrix[7] =
        _framebuffer_matrix[8] = _framebuffer_matrix[9] =
        _framebuffer_matrix[11] = _framebuffer_matrix[12] =
        _framebuffer_matrix[13] = _framebuffer_matrix[14] = 0.0;
}
@

No código acima, dobramos o tamanho do polígono recebido com tal
matriz de transformação. O motivo é o fato de toda interface ser
gerada usando o mesmo quadrado de lado 1,0. É o shader quem estica e
encolhe tal quadrado para que ele fique do tamanho certo. Aqui, nós
usamos o mesmo quadrado de antes para renderizar o nosso
framebuffer. E queremos que ele ocupe a tela inteira.

Uma vez que inicializamos os detalhes do shader, podemos usá-lo para
enfim renderizar tudo:

@<Depois da Renderização@>=
if(_final_shader[_number_of_loops] != W_NONE){
    struct _shader *current_shader;
    // Usar os vértices das interfaces
    glBindBuffer(GL_ARRAY_BUFFER,_interface_VBO);
    glBindFramebuffer(GL_FRAMEBUFFER, 0); // Usar framebuffer padrão
    glViewport(0, 0, W.width, W.height);
    glBindVertexArray(_interface_VAO);
    glDisable(GL_DEPTH_TEST);
    if(_final_shader[_number_of_loops] > 0){
        glUseProgram(_shader_list[_final_shader[_number_of_loops] -
                                  1].program_shader);
        current_shader = &(_shader_list[_final_shader[_number_of_loops] - 1]);
    }
    else{
        glUseProgram(_framebuffer_shader.program_shader);
        current_shader = &(_framebuffer_shader);
    }
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glEnableVertexAttribArray(current_shader -> _attribute_vertex_position);
    glVertexAttribPointer(current_shader -> _attribute_vertex_position,
                          3, GL_FLOAT, GL_FALSE, 0, (void*)0);
    // Passando os uniformes
    glUniform2f(current_shader -> _uniform_object_size, W.width, W.height);
    glUniform4f(current_shader -> _uniform_object_color, W_DEFAULT_COLOR,
                1.0);
    glUniform1f(current_shader -> _uniform_time,
                (float) W.t / (float) 1000000);
    glUniformMatrix4fv(current_shader -> _uniform_model_view, 1, false,
    _framebuffer_matrix);
    @<Imediatamente antes da Renderização Final de Tela@>
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDisableVertexAttribArray(current_shader -> _attribute_vertex_position);
 }
@

Mas nós ainda não mudamos a resolução com nada disso. Nós apenas
expliamos como fazer a renderização caso a resolução seja
mudada. Precisamos de uma função que mude a resolução. E isso implica
fazer as seguintes coisas:

0) Se não estamos em tela cheia, mudar a resolução é simplesmente
redimensionar a nossa janela. Toda a nossa preocupação com
framebuffers é só se estivermos em tela cheia.

1) Ajustar o valor do shader final do loop atual para
|W_DEFAULT_SHADER|, o que de pronto ativa a renderização final em duas
etapas fazendo o valor ser diferente de |W_NONE|. Embora isso por si
só ainda não mude a resolução.

2) Na primeira etapa da renderização, consultamos as variáveis
|W.width| e |W.height| para saber a altura e largura da janela em
pixels. São estes os valores que precisam ser mudados para que a
resolução enfim seja mudada.

3) Gerar novamente a textura usada para armazenar a imagem da tela na
resolução certa.

4) As interfaces dentro do programa conhecem a sua posição, mas elas
medem isso em pixels. Com a mudança de resolução, a posição delas não
é mais a mesma. Nesta parte realizamos as mesmas transformações de
antes para garantir a correção na posição das interfaces.

5) Podemos precisar mudar o tamanho de cada interface se elas foram
configuradas para serem esticáveis.

@<Shaders: Declarações@>+=
void _change_resolution(int resolution_x, int resolution_y);
@

@<Shaders: Definições@>+=
void _change_resolution(int resolution_x, int resolution_y){
#if W_WIDTH != 0 || W_HEIGHT != 0
  W.resize_window(resolution_x, resolution_y);
#else
  int width, height, old_width = W.width, old_height = W.height;
  int i, j;
  _changed_resolution = true;
  // Não podemos mais em nenhum loop renderizar direto para a tela:
  for(i = 0; i < W_MAX_SUBLOOP; i ++)
    if(_final_shader[i] == W_NONE)
      _final_shader[i] = W_DEFAULT_SHADER;
  width = W.width = ((resolution_x > 0)?(resolution_x):(W.width));
  height = W.height = ((resolution_y > 0)?(resolution_y):(W.height));
  // Aqui começamos a gerar novamente os buffers do framebuffer que
  // usaremos na renderização. Ele deve ter a nova
  // resolução. Começamos gerando novamente o buffer de cor:
  glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
  glDeleteTextures(1, &_texture);
  glGenTextures(1, &_texture);
  glBindTexture(GL_TEXTURE_2D, _texture);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, W.width, W.height, 0, GL_RGB,
      GL_UNSIGNED_BYTE, NULL); // Mesmos parâmetros de antes
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  // Ligamos a nossa textura ao buffer de cor do framebuffer
  // não-padrão:
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                         GL_TEXTURE_2D, _texture, 0);
  // Agora geraremos novamente os buffers de profundidade e stêncil:
  glDeleteRenderbuffers(1, &_depth_stencil);
  glGenRenderbuffers(1, &_depth_stencil);
  glBindRenderbuffer(GL_RENDERBUFFER, _depth_stencil);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16,
                        W.width, W.height);
  // Ligando o buffer de renderização ao framebuffer não-padrão:
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                            GL_RENDERBUFFER, _depth_stencil);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  // Feito. Agora temos apenas que atualizar a posição das
  // interfaces:
  for(i = 0; i < W_MAX_SUBLOOP; i ++){
    for(j = 0; j < W_MAX_INTERFACES; j ++){
      if(_interfaces[i][j].type == W_NONE) continue;
      W.move_interface(&_interfaces[i][j],
                       _interfaces[i][j].x *
                       ((float) width) / ((float) old_width),
                       _interfaces[i][j].y *
                       ((float) height) / ((float) old_height));
      W.rotate_interface(&_interfaces[i][j],
                         _interfaces[i][j].rotation);
      // Se a interface possui os atributos stretch_x e
      // stretch_y como verdadeiros, o seu tamanho deve ser
      // mudado de acordo com a mudança da resolução:
      if(_interfaces[i][j].stretch_x || _interfaces[i][j].stretch_y){
        float new_height = _interfaces[i][j].height;
        float new_width = _interfaces[i][j].width;
        if(_interfaces[i][j].stretch_x)
          new_width *= (float) width / (float) old_width;
        if(_interfaces[i][j].stretch_y)
          new_height *= (float) height / (float) old_height;
        W.resize_interface(&_interfaces[i][j], new_width, new_height);
      }
    }
  }
#endif
}
@

E como todas as funções da nossa API, vamos colocá-la dentro da
estrutura W:

@<Funções Weaver@>+=
  void (*change_resolution)(int, int);
@
@<API Weaver: Inicialização@>+=
  W.change_resolution = &_change_resolution;
@

@*1 Shaders personalizados.

Uma das vantagens de fazer a renderização na tela em dois passos é que
podemos obter um estado intermediário da tela, aplicar algum shader
nele e só então renderizar a imagem final. Dependendo do shader
podemos querer também passar algum valor numérico específico para
ele. Para isso vamos precisar de algumas funções adicionais.

As funções e procedimentos que obtém os shaders já foram
definidos. Cada shader já possui um número específico e está
armazenado em um vetor chamado |_shader_list|. Tudo o que precisamos
fazer é associar a última etapa de renderização com um dos shaders
personalizados:

@<Shaders: Declarações@>+=
void _change_final_shader(int type);
@

@<Shaders: Definições@>+=
void _change_final_shader(int type){
  _final_shader[_number_of_loops] = type;   
}
@

E adicionando à estrutura |W|:

@<Funções Weaver@>+=
void (*change_final_shader)(int);
@
@<API Weaver: Inicialização@>+=
  W.change_final_shader = &_change_final_shader;
@


E para passar um inteiro personalizado para o shader de renderização
final, vamos definir a seguinte variável global:

@<Variáveis Weaver@>+=
// Isso fica dentro da estrutura W:
int final_shader_integer;
@

Que caso não seja mudado será tratado como zero:

@<API Weaver: Inicialização@>+=
W.final_shader_integer = 0;
@

E que será passado para o shader toda vez que formos fazer a
renderização final de toda a tela:

@<Imediatamente antes da Renderização Final de Tela@>=
glUniform1i(current_shader -> _uniform_integer,
            W.final_shader_integer);
@

E está feito! A única coisa que não ppodemos nos esquecer é que se nós
mudamos o nosso shader atual, antes de encerrar nosso loop atual temos
que remover o shader personalizado. Também temos que fazer isso ao
entrar em um novo loop:

@<Código Imediatamente antes de Loop Principal@>+=
  if(_changed_resolution){
    _final_shader[_number_of_loops] = W_DEFAULT_SHADER;
  }
  else{
    _final_shader[_number_of_loops] = W_NONE;
  }
@

@<Código após sairmos de Subloop@>+=
  if(_changed_resolution){
    _final_shader[_number_of_loops] = W_DEFAULT_SHADER;
  }
  else{
    _final_shader[_number_of_loops] = W_NONE;
  }
@


@*1 Sumário das variáveis e Funções de Resolução.

\macronome As seguintes 2 novas funções foram definidas:

\macrovalor|void W.change_resolution(int x, int y)|: Muda a resolução
do jogo para os valores passados como argumento, que correspondem
respectivamente à resolução horizontal e vertical.

\macrovalor|void W.change_final_shader(int shader)|: Faz com que a imagem
final, antes de ser passada para a tela passe por um shader
intermediário representado pelo valor indicado.

\macronome A seguinte nova variável foi definida:

\macrovalor|int W.final_shader_integer|: É o inteiro que é passado para o
shader de renderização final para que ele o use como quiser ou o
ignore.
