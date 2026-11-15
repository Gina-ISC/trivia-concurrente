defmodule Trivia.Application do

  use Application

  @impl true
  def start(_type, _args) do
    hijos = if servidor?(), do: hijos_servidor(), else: []
    Supervisor.start_link(hijos, strategy: :one_for_one, name: Trivia.Supervisor)
  end

  def servidor? do
    node() |> Atom.to_string() |> String.starts_with?("servidor@")
  end

  defp hijos_servidor do
    [
      Trivia.Persistencia,
      Trivia.BancoPreguntas,
      Trivia.GestorJugadores,
      Trivia.SupervisorPartidas,
      Trivia.GestorPartidas,
      Trivia.Servidor
    ]
  end
end
