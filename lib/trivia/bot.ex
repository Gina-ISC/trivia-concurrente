defmodule Trivia.Bot do
  
  @acierto %{
    facil: %{basico: 0.40, intermedio: 0.30, avanzado: 0.20},
    dificil: %{basico: 0.80, intermedio: 0.70, avanzado: 0.60}
  }

  # fracción del tiempo de la pregunta en que responde {mínimo, máximo}
  @momento %{facil: {0.40, 0.90}, dificil: {0.10, 0.40}}

  @letras ["A", "B", "C", "D"]

  @doc "Devuelve `{letra, retardo_ms}`."
  def decidir(dificultad, nivel, correcta, tiempo_pregunta) do
    probabilidad = @acierto |> Map.fetch!(dificultad) |> Map.fetch!(nivel)
    {minimo, maximo} = Map.fetch!(@momento, dificultad)

    letra =
      if :rand.uniform() < probabilidad do
        correcta
      else
        @letras |> List.delete(correcta) |> Enum.random()
      end

    fraccion = minimo + :rand.uniform() * (maximo - minimo)
    {letra, round(fraccion * tiempo_pregunta * 1000)}
  end

  def start_link(nombre, dificultad, partida) do
    {:ok, spawn_link(fn -> bucle(nombre, dificultad, partida) end)}
  end

  defp bucle(nombre, dificultad, partida) do
    receive do
      {:trivia, {:pregunta, info}} ->
        programar_respuesta(nombre, dificultad, partida, info)
        bucle(nombre, dificultad, partida)

      {:responder, letra} ->
        GenServer.call(partida, {:responder, nombre, letra})
        bucle(nombre, dificultad, partida)

      _otro ->
        bucle(nombre, dificultad, partida)
    end
  end

  defp programar_respuesta(nombre, dificultad, partida, info) do
    case GenServer.call(partida, {:respuesta_correcta, nombre}) do
      {:ok, correcta} ->
        {letra, retardo} = decidir(dificultad, info.nivel, correcta, info.tiempo)
        Process.send_after(self(), {:responder, letra}, retardo)

      _ ->
        :ok
    end
  end
end
