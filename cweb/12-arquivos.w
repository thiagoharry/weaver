@*Leitura e Escrita de Dados.

Em um jogo é importane que sejamos capazes de ler e escrever dados que
sejam preservados mesmo quando o jogo for encerrado, para que possam
ser obidos novamene no futuro. Um dos usos mais antigos disso é
armazenar a pontuação máxima obtida por um jogador em um dado jogo, e
assim estimular uma competição por maiores pontos.

Jogos mais sofisticados podem armazenar muitas outras informações,
tais como o nome do jogador, nome de personagens e várias informações
sobre escolhas tomadas.

É importante então que sejamos capazes de armazenar e recuperar depois
três tipos de dados: inteiros, número em ponto flutuante e strings. E
cada armazenamento pode ter um nome específico. Isso tornará o
gerenciamento de leitura e escrita muito mais intuitiva do que o uso
direto de arquivos que precisam ser sempre abertos e fechados. Weaver
deverá cuidar de toda essa burocracia sem que um programador tenha que
se preocupar com isso.

A leitura e escrita de dados em arquivos não é algo tão simples como
parece. Uma queda de energia ou falha fatal do jogo em momentosruins
pode acabar corrompendo todos os dados salvos. A melhor forma de evitar
isso é usar um banco de dados se estivermos rodando um programa
nativo. Se estivermos executando em um navegador de Internet, aí o
problema torna-se outro. Nós nem mesmo seremos capazes de abrir
arquivos, salvar dados precisa ser feito por meio de cookies.

Então, uma grande vantagem de abstrairmos coisas como gerenciamento de
arquivos e criarmos apenas uma interface para ler e escrever variáveis
permanentes, é que essa mesma interface pode ser usada taqnto em jogos
executados nativamente com aqueles que executam em um navegador.
