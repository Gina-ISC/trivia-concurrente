defmodule Trivia.GestorJugadores do
  @moduledoc "Registro y sesiones, procesos de los clientes."
  use GenServer

  alias Trivia.{GestorPartidas, Historial, Persistencia}

  #API
  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def conectar(usuario, clave, pid), do: GenServer.call(__MODULE__, {:conectar, usuario, clave, pid})
  def desconectar(pid), do: GenServer.call(__MODULE__, {:desconectar, pid})
  def sesion(pid), do: GenServer.call(__MODULE__, {:sesion, pid})

  #callbacks
  @impl true
  def init(:ok) do
    {:ok, %{usuarios: Persistencia.leer_usuarios(), sesiones: %{}, por_pid: %{}, monitores: %{}}}
  end

  @impl true
  def handle_call({:conectar, usuario, clave, pid}, _from, estado) do
    cond do
      Historial.bot?(usuario) -> {:reply, {:error, :usuario_reservado}, estado}
      Map.has_key?(estado.por_pid, pid) -> {:reply, {:error, :ya_conectado}, estado}
      Map.has_key?(estado.sesiones, usuario) -> {:reply, {:error, :sesion_duplicada}, estado}
      true -> autenticar(usuario, clave, pid, estado)
    end
  end

  def handle_call({:desconectar, pid}, _from, estado) do
    case Map.get(estado.por_pid, pid) do
      nil ->
        {:reply, {:error, :sin_sesion}, estado}

      usuario ->
        Process.demonitor(estado.monitores[pid], [:flush])
        {:reply, {:ok, usuario}, cerrar_sesion(estado, usuario, pid)}
    end
  end

  def handle_call({:sesion, pid}, _from, estado) do
    case Map.get(estado.por_pid, pid) do
      nil -> {:reply, {:error, :sin_sesion}, estado}
      usuario -> {:reply, {:ok, usuario}, estado}
    end
  end

  #El cliente se cae o se cierra, se cierra su sesión y se aplica
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _razon}, estado) do
    case Map.get(estado.por_pid, pid) do
      nil ->
        {:noreply, estado}

      usuario ->
        GestorPartidas.desconectar(usuario)
        {:noreply, cerrar_sesion(estado, usuario, pid)}
    end
  end

  def handle_info(_otro, estado), do: {:noreply, estado}

  #privadas
  defp autenticar(usuario, clave, pid, estado) do
    case Map.fetch(estado.usuarios, usuario) do
      {:ok, ^clave} ->
        {:reply, {:ok, :autenticado}, abrir_sesion(estado, usuario, pid)}

      {:ok, _otra} ->
        {:reply, {:error, :clave_incorrecta}, estado}

      :error ->
        :ok = Persistencia.guardar_usuario(usuario, clave)
        estado = %{estado | usuarios: Map.put(estado.usuarios, usuario, clave)}
        {:reply, {:ok, :registrado}, abrir_sesion(estado, usuario, pid)}
    end
  end

  defp abrir_sesion(estado, usuario, pid) do
    ref = Process.monitor(pid)

    %{
      estado
      | sesiones: Map.put(estado.sesiones, usuario, pid),
        por_pid: Map.put(estado.por_pid, pid, usuario),
        monitores: Map.put(estado.monitores, pid, ref)
    }
  end

  defp cerrar_sesion(estado, usuario, pid) do
    %{
      estado
      | sesiones: Map.delete(estado.sesiones, usuario),
        por_pid: Map.delete(estado.por_pid, pid),
        monitores: Map.delete(estado.monitores, pid)
    }
  end
end
