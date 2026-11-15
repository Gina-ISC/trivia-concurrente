defmodule Trivia.Partida do
  @moduledoc """
  Una partida = un proceso. Atiende a la vez el temporizador de la ronda, la
  respuesta del jugador y las de sus bots.
  """
  use GenServer, restart: :transient

  alias Trivia.{BancoPreguntas, Bot, GestorPartidas, Historial, Persistencia, Puntaje}

  @letras ["A", "B", "C", "D"]
  @max_jugadores 4

  defstruct [
    :id, :creador, :tema, :total, :tiempo, :nivel, :cliente,
    estado: :esperando,
    jugadores: %{},
    bots: %{},
    preguntas: [],
    indice: 0,
    ronda_abierta: false,
    inicio: nil,
    respuestas: %{},
    puntajes: %{},
    timer: nil
  ]

  # ---- API ----
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def agregar_bot(pid, dificultad), do: GenServer.call(pid, {:agregar_bot, dificultad})
  def iniciar(pid), do: GenServer.call(pid, :iniciar)
  def responder(pid, jugador, letra), do: GenServer.call(pid, {:responder, jugador, letra})
  def abandonar(pid, jugador), do: GenServer.call(pid, {:abandonar, jugador})
  def estado(pid), do: GenServer.call(pid, :estado)

  # ---- callbacks ----
  @impl true
  def init(%{id: id, creador: creador, cliente: cliente} = args) do
    estado = %__MODULE__{
      id: id,
      creador: creador,
      tema: args.tema,
      total: args.total,
      tiempo: args.tiempo,
      nivel: args.nivel,
      cliente: cliente,
      jugadores: %{creador => cliente},
      puntajes: %{creador => 0}
    }

    # Con cast: el gestor está esperando a que el supervisor termine de arrancarnos
    GestorPartidas.reportar(id, creador, self())
    {:ok, estado}
  end

  @impl true
  def handle_call({:agregar_bot, dificultad}, _from, s) do
    cond do
      s.estado != :esperando ->
        {:reply, {:error, :partida_iniciada}, s}

      map_size(s.jugadores) >= @max_jugadores ->
        {:reply, {:error, :partida_llena}, s}

      true ->
        nombre = "#{Historial.prefijo_bot()}#{map_size(s.bots) + 1}"
        {:ok, pid} = Bot.start_link(nombre, dificultad, self())

        s = %{
          s
          | bots: Map.put(s.bots, nombre, pid),
            jugadores: Map.put(s.jugadores, nombre, pid),
            puntajes: Map.put(s.puntajes, nombre, 0)
        }

        {:reply, {:ok, nombre}, s}
    end
  end

  def handle_call(:iniciar, _from, s) do
    cond do
      s.estado != :esperando ->
        {:reply, {:error, :partida_iniciada}, s}

      map_size(s.bots) < 2 ->
        {:reply, {:error, :pocos_bots}, s}

      true ->
        case BancoPreguntas.sortear(s.tema, s.total, s.nivel) do
          {:ok, preguntas} ->
            s = %{s | estado: :en_curso, preguntas: preguntas, indice: 0}
            {:reply, :ok, iniciar_ronda(s)}

          {:error, motivo} ->
            {:reply, {:error, motivo}, s}
        end
    end
  end

  def handle_call({:responder, jugador, letra}, _from, s) do
    cond do
      not s.ronda_abierta ->
        {:reply, {:error, :sin_ronda}, s}

      not Map.has_key?(s.jugadores, jugador) ->
        {:reply, {:error, :sin_partida}, s}

      letra not in @letras ->
        {:reply, {:error, :letra_invalida}, s}

      Map.has_key?(s.respuestas, jugador) ->
        {:reply, {:error, :ya_respondio}, s}

      true ->
        ahora = System.monotonic_time(:millisecond)
        s = %{s | respuestas: Map.put(s.respuestas, jugador, {letra, ahora})}

        if map_size(s.respuestas) == map_size(s.jugadores) do
          case cerrar_ronda(s) do
            {:seguir, s} -> {:reply, {:ok, :registrada}, s}
            {:fin, s} -> {:stop, :normal, {:ok, :registrada}, s}
          end
        else
          {:reply, {:ok, :registrada}, s}
        end
    end
  end

  # Solo los bots usan esta consulta: reciben la respuesta correcta del servidor
  def handle_call({:respuesta_correcta, bot}, _from, s) do
    if s.ronda_abierta and Map.has_key?(s.bots, bot) do
      {:reply, {:ok, Enum.at(s.preguntas, s.indice).correcta}, s}
    else
      {:reply, {:error, :sin_ronda}, s}
    end
  end

  def handle_call({:abandonar, jugador}, _from, s) do
    cond do
      s.estado == :esperando and jugador == s.creador ->
        notificar(s, {:cancelada, s.id})
        GestorPartidas.terminada(s.id)
        {:stop, :normal, {:ok, :cancelada}, s}

      s.estado == :en_curso and jugador == s.creador ->
        if s.timer, do: Process.cancel_timer(s.timer)
        finalizar(s, true)
        {:stop, :normal, {:ok, :finalizada}, s}

      true ->
        {:reply, {:error, :sin_partida}, s}
    end
  end

  def handle_call(:estado, _from, s), do: {:reply, s, s}

  @impl true
  def handle_info({:vence, indice}, %{ronda_abierta: true, indice: indice} = s) do
    case cerrar_ronda(s) do
      {:seguir, s} -> {:noreply, s}
      {:fin, s} -> {:stop, :normal, s}
    end
  end

  def handle_info(:siguiente, s) do
    {:noreply, iniciar_ronda(%{s | indice: s.indice + 1})}
  end

  # {:vence, _} de una ronda ya cerrada, y cualquier otro mensaje
  def handle_info(_otro, s), do: {:noreply, s}

  @impl true
  def terminate(_razon, s) do
    Enum.each(s.bots, fn {_nombre, pid} -> Process.exit(pid, :shutdown) end)
  end

  # ---- rondas ----
  defp iniciar_ronda(s) do
    pregunta = Enum.at(s.preguntas, s.indice)

    info = %{
      numero: s.indice + 1,
      total: s.total,
      tema: s.tema,
      nivel: pregunta.nivel,
      enunciado: pregunta.enunciado,
      opciones: pregunta.opciones,
      tiempo: s.tiempo
    }

    s = %{
      s
      | ronda_abierta: true,
        respuestas: %{},
        inicio: System.monotonic_time(:millisecond),
        timer: Process.send_after(self(), {:vence, s.indice}, s.tiempo * 1000)
    }

    notificar(s, {:pregunta, info})
    s
  end

  defp cerrar_ronda(s) do
    Process.cancel_timer(s.timer)
    pregunta = Enum.at(s.preguntas, s.indice)

    deltas =
      Map.new(s.jugadores, fn {jugador, _pid} ->
        {jugador, puntos_ronda(s, pregunta, Map.get(s.respuestas, jugador))}
      end)

    puntajes = Map.new(s.puntajes, fn {j, total} -> {j, total + Map.fetch!(deltas, j)} end)

    detalle =
      deltas
      |> Enum.sort()
      |> Enum.map(fn {j, delta} -> {j, delta, Map.fetch!(puntajes, j)} end)

    texto = Map.fetch!(pregunta.opciones, pregunta.correcta)
    s = %{s | ronda_abierta: false, puntajes: puntajes, respuestas: %{}, timer: nil}
    notificar(s, {:cierre_ronda, %{correcta: pregunta.correcta, texto: texto, puntajes: detalle}})

    if s.indice + 1 >= s.total do
      finalizar(s, false)
      {:fin, s}
    else
      {:seguir, %{s | timer: Process.send_after(self(), :siguiente, pausa_ms())}}
    end
  end

  defp puntos_ronda(_s, _pregunta, nil), do: 0

  defp puntos_ronda(s, pregunta, {letra, llegada}) do
    transcurridos = (llegada - s.inicio) / 1000
    restantes = s.tiempo - transcurridos
    resultado = if letra == pregunta.correcta, do: :correcta, else: :incorrecta
    Puntaje.ronda(pregunta.nivel, resultado, restantes, s.tiempo)
  end

  defp pausa_ms, do: Application.get_env(:trivia, :pausa_ms, 3000)

  # ---- fin de partida ----
  defp finalizar(s, abandono?) do
    ranking = s.puntajes |> Enum.sort_by(fn {j, p} -> {-p, j} end)
    {_, maximo} = hd(ranking)
    ganadores = for {j, p} <- ranking, p == maximo, do: j

    notificar(s, {:fin, %{id: s.id, tema: s.tema, nivel: s.nivel, ranking: ranking, ganadores: ganadores, abandono: abandono?}})

    fecha = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    linea = Historial.a_linea(fecha, s.id, s.tema, s.nivel, ganadores, ranking)
    Persistencia.registrar_resultado(linea)
    GestorPartidas.terminada(s.id)
  end

  defp notificar(s, mensaje) do
    Enum.each(s.jugadores, fn {_jugador, pid} -> send(pid, {:trivia, mensaje}) end)
  end
end
