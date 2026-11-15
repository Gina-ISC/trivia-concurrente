defmodule Trivia.GestorPartidas do
  @moduledoc "Crea y ubica partidas, y avisa al creador cuando una se reinicia."
  use GenServer

  alias Trivia.{BancoPreguntas, Nivel, Persistencia, SupervisorPartidas}

  #API
  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def crear(usuario, cliente, tema, total, tiempo),
    do: GenServer.call(__MODULE__, {:crear, usuario, cliente, tema, total, tiempo})

  def ubicar(usuario), do: GenServer.call(__MODULE__, {:ubicar, usuario})


  def reportar(id, creador, pid), do: GenServer.cast(__MODULE__, {:reportar, id, creador, pid})
  def terminada(id), do: GenServer.cast(__MODULE__, {:terminada, id})
  def desconectar(usuario), do: GenServer.cast(__MODULE__, {:desconectar, usuario})

  #callbacks
  @impl true
  def init(:ok), do: {:ok, %{siguiente: 1001, partidas: %{}, por_usuario: %{}}}

  @impl true
  def handle_call({:crear, usuario, cliente, tema, total, tiempo}, _from, s) do
    with :ok <- no_en_partida(s, usuario),
         nivel = Nivel.nivel_en_tema(Persistencia.historial(), usuario, tema),
         :ok <- BancoPreguntas.validar(tema, total, nivel) do
      id = "P-#{s.siguiente}"
      args = %{id: id, creador: usuario, tema: tema, total: total, tiempo: tiempo, nivel: nivel, cliente: cliente}

      case SupervisorPartidas.iniciar_partida(args) do
        {:ok, pid} ->
          s = %{
            s
            | siguiente: s.siguiente + 1,
              partidas: Map.put(s.partidas, id, %{pid: pid, creador: usuario, cliente: cliente}),
              por_usuario: Map.put(s.por_usuario, usuario, id)
          }

          {:reply, {:ok, %{id: id, nivel: nivel}}, s}

        {:error, _} ->
          {:reply, {:error, :partida_no_disponible}, s}
      end
    else
      {:error, motivo} -> {:reply, {:error, motivo}, s}
    end
  end

  def handle_call({:ubicar, usuario}, _from, s) do
    with {:ok, id} <- Map.fetch(s.por_usuario, usuario),
         %{pid: pid} <- Map.get(s.partidas, id) do
      {:reply, {:ok, pid}, s}
    else
      _ -> {:reply, {:error, :sin_partida}, s}
    end
  end

  @impl true
  def handle_cast({:reportar, id, _creador, pid}, s) do
    case Map.get(s.partidas, id) do
      nil ->
        {:noreply, s}

      %{pid: ^pid} ->
        {:noreply, s}

      %{cliente: cliente} = info ->
        # otro PID para la misma partida: es un reinicio
        if cliente, do: send(cliente, {:trivia, {:reinicio, id}})
        {:noreply, put_in(s.partidas[id], %{info | pid: pid})}
    end
  end

  def handle_cast({:terminada, id}, s) do
    case Map.pop(s.partidas, id) do
      {nil, _} ->
        {:noreply, s}

      {%{creador: creador}, partidas} ->
        {:noreply, %{s | partidas: partidas, por_usuario: Map.delete(s.por_usuario, creador)}}
    end
  end

  # El cliente se cayó: se aplica 6.5 (o se cancela si no había iniciado)
  def handle_cast({:desconectar, usuario}, s) do
    with {:ok, id} <- Map.fetch(s.por_usuario, usuario),
         %{pid: pid} <- Map.get(s.partidas, id) do
      Task.start(fn ->
        try do
          Trivia.Partida.abandonar(pid, usuario)
        catch
          # la partida ya había terminado
          :exit, _ -> :ok
        end
      end)
    end

    {:noreply, s}
  end

  defp no_en_partida(s, usuario) do
    if Map.has_key?(s.por_usuario, usuario), do: {:error, :ya_en_partida}, else: :ok
  end
end
