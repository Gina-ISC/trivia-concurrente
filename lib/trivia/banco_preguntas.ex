defmodule Trivia.BancoPreguntas do
  @moduledoc """
  Carga las preguntas del JSON y las sortea de acuerdo al nivel del jugador
  """

  use GenServer

  alias Trivia.{Nivel, Persistencia}

  @niveles %{"basico" => :basico, "intermedio" => :intermedio, "avanzado" => :avanzado}

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def validar(tema, total, nivel), do: GenServer.call(__MODULE__, {:validar, tema, total, nivel})

  def sortear(tema, total, nivel), do: GenServer.call(__MODULE__, {:sortear, tema, total, nivel})


  def normalizar(mapa) do
    %{
      id: mapa["id"],
      tema: mapa["tema"],
      nivel: Map.fetch!(@niveles, mapa["nivel"]),
      enunciado: mapa["enunciado"],
      opciones: mapa["opciones"],
      correcta: mapa["correcta"]
    }
  end

  def validar_en(preguntas, tema, total, nivel) do
    del_tema = Enum.filter(preguntas, &(&1.tema == tema))

    if del_tema == [] do
      {:error, :tema_inexistente}
    else
      suficientes? =
        nivel
        |> then(&Nivel.reparto(total, &1))
        |> Enum.all?(fn {n, cantidad} -> Enum.count(del_tema, &(&1.nivel == n)) >= cantidad end)

        if suficientes?, do: :ok, else: {:error, :preguntas_insuficientes}
    end
  end

  @doc """
  Sorteo de preguntas
  """

  def sortear_en(preguntas, tema, total, nivel) do
    with :ok <- validar_en(preguntas, tema, total, nivel) do
      reparto = Nivel.reparto(total, nivel)

      sorteadas =
        Nivel.niveles()
        |> Enum.flat_map(fn n ->
          preguntas
          |> Enum.filter(&(&1.tema == tema and &1.nivel == n))
          |> Enum.shuffle()
          |> Enum.take(Map.fetch!(reparto, n))
        end)

        {:ok, sorteadas}
    end
  end


  @impl true
  def init(opts) do
    preguntas =
      case Keyword.fetch(opts, :preguntas) do
        {:ok, lista} -> lista
        :error -> Persistencia.leer_preguntas()
        |> Enum.map(&normalizar/1)
      end

    {:ok, preguntas}
  end


  @impl true
  def handle_call({:validar, tema, total, nivel}, _from, preguntas),
    do: {:reply, validar_en(preguntas, tema, total, nivel), preguntas}


  @impl true
  def handle_call({:sortear, tema, total, nivel}, _from, preguntas),
    do: {:reply, sortear_en(preguntas, tema, total, nivel), preguntas}

end
