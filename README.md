# trivia-concurrente

Proyecto final de la asignatura **Programación III** de la Universidad del Quindío. Consiste en un juego de trivia por consola con arquitectura cliente-servidor, comunicación distribuida mediante nodos de Erlang, concurrencia con GenServers y persistencia en archivos JSON.

## Integrantes
- Cristhian López Leyton
- Gina Marcela Tamayo Castañeda
- Samuel Gutierrez Vega

Compilación

mix deps.get      # descarga Jason
mix compile
mix test          # pruebas ExUnit


Cómo levantar los nodos
El rol del nodo depende de su nombre corto: un nodo llamado servidor levanta el juego

# Consola 1: servidor (carga data/questions.json y queda esperando)
iex --sname servidor -S mix

# Consola 2: cliente de Pedro
iex --sname pedro -S mix
iex> Trivia.Cliente.jugar()

# Consola 3: cliente de Carlos
iex --sname carlos -S mix
iex> Trivia.Cliente.jugar()

Comandos

connect <usuario> <clave>	Inicia sesión; si el usuario no existe, lo registra
disconnect	Cierra la sesión (y abandona la partida en curso)
create\_game tema=<tema> preguntas=<n> tiempo=<seg>	Crea una partida y responde con id y nivel
add\_bot facil|dificil	Agrega un bot (máx. 3, la partida queda de 3 a 4 jugadores)
start\_game	Inicia (requiere al menos 2 bots)
answer <A-D> (o answer\_<letra>)	Responde la ronda abierta
leave\_game	Abandona; antes de iniciar cancela la partida
score	Puntaje acumulado, partidas y nivel por tema
ranking \[tema]	Ranking histórico global o por tema
exit	Cierra el cliente
