defmodule Trivia.Historial do
  @moduledoc """
  Parseo de resultados y calculo de las estadisticas
  """

  @prefijo_bot "bot_"

  def prefijo_bot, do: @prefijo_bot

  def bot?(nombre), do: String.starts_with?(nombre, @prefijo_bot)

  @doc """
  Historial en texto
  """

  def a_linea(fecha, id, tema, nivel, ganadores, puntajes) do
    pts = Enum.map_join(puntajes, ",", fn {j, p} -> "#{j}=#{p}" end)

    Enum.join([fecha, id, tema, nivel, Enum.join(ganadores, "+"), pts], "|")
  end

  @doc """
  Pasa una linea a un mapa con la informacion de la partida
  """

  def parsear(linea) do
    case String.split(String.trim(linea), "|") do
      [fecha, id, tema, nivel, ganador, pts] when pts != "" ->
        %{
          fecha: fecha,
          id: id,
          tema: tema,
          nivel: nivel,
          ganador: ganador,
          puntajes: parsear_puntajes(pts)
        }

      _ -> nil
    end
  end

  defp parsear_puntajes(texto) do
    texto
    |> String.split(",")
    |> Enum.map(fn par ->
      [nombre, valor] = String.split(par, "=")
      {nombre, String.to_integer(valor)}
    end)
  end

  defp entradas(lineas) do
    lineas
    |> Stream.map(&parsear/1)
    |> Stream.reject(&is_nil/1)
  end

  @doc """
  Calculo del puntaje acumulado de un usuario, cantidad de partidas jugadas y puntaje de cada tema
  """

  def resumen(lineas, usuario) do
    lineas
    |> entradas()
    |> Enum.reduce(%{puntaje: 0, partidas: 0, temas: %{}}, fn entrada, acc ->
      case List.keyfind(entrada.puntajes, usuario, 0) do
        nil -> acc
        {_, puntos} ->
          %{
            puntaje: acc.puntaje + puntos,
            partidas: acc.partidas + 1,
            temas: Map.update(acc.temas, entrada.tema, puntos, &(&1 + puntos))
          }
      end
    end)
  end


  @doc """
  Crea el ranking ignorando a los bots
  """

  def ranking(lineas, tema \\ nil) do
    lineas
    |> entradas()
    |> Stream.filter(fn e -> tema == nil or e.tema == tema end)
    |> Enum.reduce(%{}, fn entrada, acc ->

      entrada.puntajes
      |> Enum.reject(fn {jugador, _} -> bot?(jugador) end)
      |> Enum.reduce(acc, fn {jugador, puntos}, acc2 ->
        Map.update(acc2, jugador, {puntos, 1}, fn {p, n} -> {p + puntos, n + 1} end)
      end)
    end)

    |> Enum.map(fn {jugador, {puntos, partidas}} -> {jugador, puntos, partidas} end)
    |> Enum.sort_by(fn {jugador, puntos, _} -> {-puntos, jugador} end)
  end
end
