defmodule Trivia.Persistencia do
  @moduledoc """
  Este involucra el sistema de archivos. Las escrituras pasan
  por este proceso y no se mezcla con otra.
  """
  use GenServer

  @dir_por_defecto Path.expand("../../data", __DIR__)

  def dir, do: Application.get_env(:trivia, :data_dir, @dir_por_defecto)
  defp ruta(nombre), do: Path.join(dir(), nombre)

  #API
  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def guardar_usuario(usuario, clave), do: GenServer.call(__MODULE__, {:guardar_usuario, usuario, clave})
  def registrar_resultado(linea), do: GenServer.cast(__MODULE__, {:resultado, linea})

  #lecturas
  def leer_usuarios do
    case File.read(ruta("users.json")) do
      {:ok, contenido} ->
        contenido
        |> Jason.decode!()
        |> Map.new(fn u -> {u["usuario"], u["clave"]} end)

      {:error, :enoent} ->
        %{}
    end
  end

  def leer_preguntas do
    ruta("questions.json") |> File.read!() |> Jason.decode!()
  end

  @doc "Historial como stream perezoso de líneas."
  def historial do
    if File.exists?(ruta("results.log")) do
      ruta("results.log")
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
    else
      []
    end
  end

  #callbacks
  @impl true
  def init(:ok) do
    File.mkdir_p!(dir())
    {:ok, nil}
  end

  @impl true
  def handle_call({:guardar_usuario, usuario, clave}, _from, estado) do
    usuarios = leer_usuarios() |> Map.put(usuario, clave)

    lista =
      usuarios
      |> Enum.sort()
      |> Enum.map(fn {u, c} -> %{"usuario" => u, "clave" => c} end)

    File.write!(ruta("users.json"), Jason.encode!(lista, pretty: true))
    {:reply, :ok, estado}
  end

  @impl true
  def handle_cast({:resultado, linea}, estado) do
    File.write!(ruta("results.log"), linea <> "\n", [:append])
    {:noreply, estado}
  end
end
