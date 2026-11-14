defmodule Trivia.Comando do
  @moduledoc "Traduce lo que escribe el jugador a una petición."

  def parsear(linea) do
    case linea |> String.trim() |> String.split() do
      ["connect", usuario, clave] -> {:ok, {:connect, usuario, clave}}
      ["disconnect"] -> {:ok, :disconnect}
      ["create_game" | args] -> crear_partida(args)
      ["add_bot", dificultad] when dificultad in ["facil", "dificil"] -> {:ok, {:add_bot, String.to_atom(dificultad)}}
      ["start_game"] -> {:ok, :start_game}
      ["leave_game"] -> {:ok, :leave_game}
      ["answer", letra] -> {:ok, {:answer, letra}}
      ["answer_" <> letra] -> {:ok, {:answer, letra}}
      ["score"] -> {:ok, :score}
      ["ranking"] -> {:ok, {:ranking, nil}}
      ["ranking", tema] -> {:ok, {:ranking, tema}}
      [] -> {:error, :vacio}
      _ -> {:error, :comando_desconocido}
    end
  end

  defp crear_partida(args) do
    pares =
      Enum.reduce(args, %{}, fn arg, acc ->
        case String.split(arg, "=", parts: 2) do
          [clave, valor] -> Map.put(acc, clave, valor)
          _ -> acc
        end
      end)

    with tema when is_binary(tema) <- pares["tema"],
         {total, ""} when total > 0 <- Integer.parse(pares["preguntas"] || ""),
         {tiempo, ""} when tiempo > 0 <- Integer.parse(pares["tiempo"] || "") do
      {:ok, {:create_game, tema, total, tiempo}}
    else
      _ -> {:error, :argumentos_invalidos}
    end
  end
end
