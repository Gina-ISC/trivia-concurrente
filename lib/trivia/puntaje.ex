defmodule Trivia.Puntaje do

  @puntos %{
    basico: {10, -5},
    intermedio: {15, -8},
    avanzado: {20, -10}
  }

  @doc """
  Aqui se calcula el puntaje final de una ronda dependiendo si la respuesta es correcta, no lo es o no respondio
  """

  def ronda(nivel, :correcta, segundos_restantes, tiempo_pregunta) do
    {correcta, _} = Map.fetch!(@puntos, nivel)
    correcta + bonificacion(segundos_restantes, tiempo_pregunta)
  end

  def ronda(nivel, :incorrecta, _restantes, _tiempo) do
    {_, incorrecta} = Map.fetch!(@puntos, nivel)
    incorrecta
  end

  def ronda(_nivel, :sin_responder, _restantes, _tiempo), do: 0


  @doc """
  Calculo de la bonificacion por velocidad de respuesta, va de 0 a 5 puntos
  """

  def bonificacion(segundos_restantes, tiempo_pregunta) do
    restantes =
      segundos_restantes
      |> max(0)
      |> min(tiempo_pregunta)

    trunc(5 * restantes / tiempo_pregunta)
  end
end
