defmodule Trivia.Cliente do
  @moduledoc """
  consola del jugador, no tiene lógica de juego: traduce lo que el
  jugador escribe en una petición al servidor y muestra lo que recibe.
  """

  alias Trivia.{Comando, Errores, Receptor}

  def jugar(servidor \\ nil) do
    nodo = nodo_servidor(servidor)
    receptor = Receptor.iniciar()
    IO.puts("Cliente listo. Comandos: connect, disconnect, create_game, add_bot, start_game, leave_game, answer, score, ranking, exit")
    bucle(nodo, receptor)
  end

  defp bucle(nodo, receptor) do
    case IO.gets("trivia> ") do
      :eof ->
        salir(nodo, receptor)

      {:error, _} ->
        salir(nodo, receptor)

      linea ->
        if String.trim(linea) in ["exit", "quit"] do
          salir(nodo, receptor)
        else
          linea |> Comando.parsear() |> procesar(nodo, receptor) |> IO.puts()
          bucle(nodo, receptor)
        end
    end
  end

  defp procesar({:ok, comando}, nodo, receptor) do
    case enviar(nodo, receptor, comando) do
      {:ok, texto} -> texto
      {:error, motivo} -> "Error: " <> Errores.mensaje(motivo)
    end
  end

  defp procesar({:error, :vacio}, _nodo, _receptor), do: ""
  defp procesar({:error, motivo}, _nodo, _receptor), do: "Error: " <> Errores.mensaje(motivo)

  @doc "Envía una petición y espera la respuesta del servidor"
  def enviar(nodo, receptor, comando) do
    if Node.alive?() and (nodo == node() or Node.connect(nodo)) do
      try do
        GenServer.call({:servidor, nodo}, {:peticion, receptor, comando}, 10_000)
      catch
        :exit, _ -> {:error, :servidor_no_disponible}
      end
    else
      {:error, :servidor_no_disponible}
    end
  end

  defp salir(nodo, receptor) do
    enviar(nodo, receptor, :disconnect)
    send(receptor, :detener)
    IO.puts("Hasta pronto.")
  end

  defp nodo_servidor(nil) do
    [_, host] = node() |> Atom.to_string() |> String.split("@")
    :"servidor@#{host}"
  end

  defp nodo_servidor(nombre) when is_binary(nombre), do: String.to_atom(nombre)
  defp nodo_servidor(nodo) when is_atom(nodo), do: nodo
end
