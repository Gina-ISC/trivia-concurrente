defmodule Trivia.SupervisorPartidas do
  @moduledoc "DynamicSupervisor de partidas: reinicia las que terminan de forma anormal."

  def start_link(_opts \\ []), do: DynamicSupervisor.start_link(strategy: :one_for_one, name: __MODULE__)
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}

  @doc "Las partidas se registran con restart: :transient (solo se reinician si fallan)."
  def iniciar_partida(args) do
    DynamicSupervisor.start_child(__MODULE__, Trivia.Partida.child_spec(args))
  end
end
