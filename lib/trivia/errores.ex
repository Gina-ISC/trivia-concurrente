defmodule Trivia.Errores do
  @moduledoc """
  Errores que podrian surgir en el juego
  """

  @mensajes %{
    sin_sesion: "Debe iniciar sesión primero: connect <usuario> <clave>.",
    clave_incorrecta: "La clave no coincide con la del usuario.",
    sesion_duplicada: "Ese usuario ya tiene una sesión abierta en otro cliente.",
    ya_conectado: "Este cliente ya tiene una sesión abierta.",
    usuario_reservado: "Los usuarios que empiezan por \"bot_\" están reservados.",
    servidor_no_disponible: "No se pudo contactar al servidor.",
    ya_en_partida: "Ya estás en una partida.",
    tema_inexistente: "El tema no existe en el banco de preguntas.",
    preguntas_insuficientes: "El tema no tiene suficientes preguntas de algún nivel para esta partida.",
    sin_partida: "No estás en ninguna partida.",
    partida_llena: "La partida ya tiene 4 jugadores.",
    partida_iniciada: "La partida ya fue iniciada.",
    pocos_bots: "Se necesitan al menos 2 bots para iniciar la partida.",
    letra_invalida: "La letra debe ser A, B, C o D.",
    sin_ronda: "No hay una ronda abierta; la respuesta se rechaza.",
    ya_respondio: "Ya respondiste esta pregunta; la respuesta se ignora.",
    argumentos_invalidos: "Argumentos inválidos para el comando.",
    comando_desconocido: "Comando desconocido.",
    partida_no_disponible: "La partida no está disponible en este momento."
  }


  def mensaje(motivo), do: Map.get(@mensajes, motivo, "Error: #{inspect(motivo)}")
end
