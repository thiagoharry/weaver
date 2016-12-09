@* Mudança de Resolução.

Toda vez que renderizamos algo, renderizamos para um framebuffer. Até
agora estiemos renderizando no framebuffer padrão, que corresponde ao
quê vemos na tela.

Todo framebuffer é composto por um ou mais buffer. Pode haver um para
representar a cor de cada pixel (buffer de cor), outro para armazenar
a profundidade do que foi desenhado para impedir que objetos mais
distantes apareçam na frente de objetos mais próximos (buffer de
profundidade), um buffer que serve com uma máscara para delimitar onde
iremos ou não iremos de fato desenhar (buffer de stencil)
