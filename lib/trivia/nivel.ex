defmodule Trivia.Nivel do
  @moduledoc """
  Determina el nivel de un jugador de acuerdo al puntaje acumulado y calcula cuantas preguntas de cada nivel debe recibir
  """

  alias Trivia.Historial

  @niveles [:basico, :intermedio, :avanzado]

  @reparto %{
    basico: %{basico: 70, intermedio: 30, avanzado: 0},
    intermedio: %{basico: 20, intermedio: 60, avanzado: 20},
    avanzado: %{basico: 0, intermedio: 30, avanzado: 70}
  }

  def niveles, do: @niveles

  @doc """
  Se calcula el nivel de un jugador a partir del puntaje acumulado en un tema
  """

  def nivel(puntaje) when puntaje < 60, do: :basico
  def nivel(puntaje) when puntaje < 100, do: :intermedio
  def nivel(_puntaje), do: :avanzado

  @doc """
  Calcula el puntaje de un jugador en un tema
  """

  def puntaje_tema(lineas, usuario, tema) do
    lineas
    |> Historial.resumen(usuario)
    |> Map.fetch!(:temas)
    |> Map.get(tema, 0)
  end

  @doc """
  El nivel de un jugador en un tema
  """

  def nivel_en_tema(lineas, usuario, tema) do
    lineas
    |> puntaje_tema(usuario, tema)
    |> nivel()
  end


  @doc """
  Cantidad de preguntas de cada nivel que debe tener una partida
  """

  def reparto(total, nivel) do
    porcentajes = Map.fetch!(@reparto, nivel)

    otros =
      @niveles
      |> Enum.reject(&(&1 == nivel))
      |> Map.new(fn n ->
        {n, trunc(total * Map.fetch!(porcentajes, n) / 100)}
      end)


    suma_otros =
      otros
      |> Map.values()
      |> Enum.sum()

    propias = total - suma_otros

    Map.put(otros, nivel, propias)
  end
end
