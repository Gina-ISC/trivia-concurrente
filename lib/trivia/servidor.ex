defmodule Trivia.Servidor do
  @moduledoc "Recibe las peticiones de los clientes y las enruta."
  use GenServer

  alias Trivia.{GestorJugadores, GestorPartidas, Historial, Nivel, Partida, Persistencia}

  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, :ok, name: :servidor)

  @impl true
  def init(:ok), do: {:ok, nil}

  #el receptor es el PID del proceso del cliente que recibe las notificaciones
  @impl true
  def handle_call({:peticion, receptor, comando}, _from, estado) do
    {:reply, atender(receptor, comando), estado}
  end

  defp atender(receptor, {:connect, usuario, clave}) do
    case GestorJugadores.conectar(usuario, clave, receptor) do
      {:ok, :registrado} -> {:ok, "Usuario #{usuario} registrado. Sesión iniciada."}
      {:ok, :autenticado} -> {:ok, "Sesión iniciada. Bienvenido, #{usuario}."}
      error -> error
    end
  end

  defp atender(receptor, comando) do
    with {:ok, usuario} <- GestorJugadores.sesion(receptor) do
      ejecutar(usuario, receptor, comando)
    end
  end

  defp ejecutar(usuario, receptor, :disconnect) do
    GestorPartidas.desconectar(usuario)
    GestorJugadores.desconectar(receptor)
    {:ok, "Sesión cerrada."}
  end

  defp ejecutar(usuario, receptor, {:create_game, tema, total, tiempo}) do
    case GestorPartidas.crear(usuario, receptor, tema, total, tiempo) do
      {:ok, %{id: id, nivel: nivel}} -> {:ok, "Partida #{id} creada. Tu nivel en #{tema}: #{nivel}."}
      error -> error
    end
  end

  defp ejecutar(usuario, _receptor, {:add_bot, dificultad}) do
    con_partida(usuario, fn pid ->
      case Partida.agregar_bot(pid, dificultad) do
        {:ok, nombre} -> {:ok, "Bot #{nombre} (#{dificultad}) agregado."}
        error -> error
      end
    end)
  end

  defp ejecutar(usuario, _receptor, :start_game) do
    con_partida(usuario, fn pid ->
      case Partida.iniciar(pid) do
        :ok -> {:ok, "Partida iniciada."}
        error -> error
      end
    end)
  end

  defp ejecutar(usuario, _receptor, :leave_game) do
    con_partida(usuario, fn pid ->
      case Partida.abandonar(pid, usuario) do
        {:ok, :cancelada} -> {:ok, "Partida cancelada."}
        {:ok, :finalizada} -> {:ok, "Abandonaste la partida; el resultado quedó registrado."}
        error -> error
      end
    end)
  end

  defp ejecutar(usuario, _receptor, {:answer, letra}) do
    con_partida(usuario, fn pid ->
      case Partida.responder(pid, usuario, letra) do
        {:ok, :registrada} -> {:ok, "Respuesta #{letra} registrada."}
        error -> error
      end
    end)
  end

  defp ejecutar(usuario, _receptor, :score) do
    resumen = Historial.resumen(Persistencia.historial(), usuario)

    filas =
      resumen.temas
      |> Enum.sort()
      |> Enum.map(fn {tema, puntos} -> "#{tema} #{puntos} #{Nivel.nivel(puntos)}" end)

    texto =
      Enum.join(
        [usuario, "Puntaje acumulado: #{resumen.puntaje}", "Partidas jugadas: #{resumen.partidas}"] ++
          if(filas == [], do: [], else: ["Tema Puntaje Nivel" | filas]),
        "\n"
      )

    {:ok, texto}
  end

  defp ejecutar(_usuario, _receptor, {:ranking, tema}) do
    filas =
      Persistencia.historial()
      |> Historial.ranking(tema)
      |> Enum.with_index(1)
      |> Enum.map(fn {{jugador, puntos, partidas}, pos} -> "#{pos} #{jugador} #{puntos} #{partidas}" end)

    titulo = if tema, do: "Ranking #{tema}", else: "Ranking global"
    {:ok, Enum.join([titulo, "# Jugador Puntaje Partidas" | filas], "\n")}
  end

  defp ejecutar(_usuario, _receptor, _otro), do: {:error, :comando_desconocido}

  # Ubica la partida del usuario, si el proceso murió justo ahora, informa sin caerse
  defp con_partida(usuario, funcion) do
    with {:ok, pid} <- GestorPartidas.ubicar(usuario) do
      try do
        funcion.(pid)
      catch
        :exit, _ -> {:error, :partida_no_disponible}
      end
    end
  end
end
