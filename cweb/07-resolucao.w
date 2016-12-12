@* Mudança de Resolução.

Toda vez que renderizamos algo, renderizamos para um framebuffer. Até
agora estiemos renderizando no framebuffer padrão, que corresponde ao
quê vemos na tela.

Todo framebuffer é composto por um ou mais buffer. Pode haver um para
representar a cor de cada pixel (buffer de cor), outro para armazenar
a profundidade do que foi desenhado para impedir que objetos mais
distantes apareçam na frente de objetos mais próximos (buffer de
profundidade), um buffer que serve com uma máscara para delimitar onde
iremos ou não iremos de fato desenhar (buffer de stencil).

Até agora nós estivemos desenhando apenas no framebuffer padrão, o
qual é habilitado quando criamos o contexto OpenGL na
inicialização. Mas podemos renderizar as coisas também em outros
framebuffers. A ideia é que assim podemos renderizar texturas ou
aplicar efeitos especiais na imagem antes de passá-la para a tela. Um
dos tais efeitos especiais seria fazer com que ela tenha uma resolução
menor que a tela. Assim podemos reduzir a resolução de nosso jogo caso
ele seja muito pesado, tentando assim economizar o desempenho gasto
para desenhar cada pixel na tela por meio do shader de fragmento.

A primeira coisa que precisamos é de um novo framebuffer não-padrão, o
qual iremos declarar e gerar na inicialização.

@<Cabeçalhos Weaver@>+=
// Abaixo saberemos se mudamos a nossa resolução e com isso precisamos
// renderizar no framebuffer de renderização não-padrão:
bool _use_non_default_render;
// E este é o framebuffer de renderização não-padrão:
GLuint _framebuffer;
@

@<API Weaver: Inicialização@>+=
{
    // Inicialmente iremos renderizar diretamente na tela. Se esta
    // variável mudar, aí sim renderizaremos no nosso framebuffer:
    _use_non_default_render = false;
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
textura em um quadrado que renderizaremos ocupando toda a tela. Nossa
textura deverá ter a resolução que queremos para o nosso jogo:

@<Cabeçalhos Weaver@>+=
// A textura na qual renderizaremos se estivermos fazendo uma
// renderização não-padrão.
GLuint _texture;
@

@<API Weaver: Inicialização@>+=
{
    // Gerando a textura:
    glGenTextures(1, &_texure);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexImage2D(
        GL_TEXTURE_2D, // É uma imagem em 2D
        0, // Nível de detalhe. Não usaremos mipmaps aqui
        GL_RGB, // Formato interno do pixel
        W.width, // Largura
        W.height, // Altura
        0, // A especifiação pede que aqui sempre seja 0
        GL_RGB, GL_UNSIGNED_BYTE, // Formato dos pixels como serão passados
        NULL); // NULL, pois os pixels serão criados dinamicamente
    // Ativa antialiasing para melhorar aparência de jogo em resolução
    // menor:
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // Ligamos a nossa textura ao buffer de cor do framebuffer
    // não-padrão:
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, _texture, 0);
}
@

Mas o nosso framebuffer não-padrão precisa de mais buffers além de um
único bufer de cor. Vamos precisar de um buffer de profundidade, e
quem sabe de um buffer de stêncil. Como temos certeza de que o que
estamos criando será sempre interpretado como uma imagem, ao invés de
criar mais texturas para isso, criaremos diretamente um buffer de
renderização:

@<Cabeçalhos Weaver@>+=
// Buffer de renderização:
GLuint _depth_stencil;
@

@<API Weaver: Inicialização@>+=
{
    glGenRenderbuffers(1, &_depth_stencil);
    glBindRenderbuffer(GL_RENDERBUFFER, _depth_stencil);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8,
                          W.width, W.height);
    // Ligando o buffer de renderização ao framebuffer não-padrão:
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                              GL_RENDERBUFFER, _depth_stencil);
}
@
