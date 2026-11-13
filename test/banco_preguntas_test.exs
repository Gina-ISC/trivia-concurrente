defmodule Trivia.BancoPreguntasTest do
  use ExUnit.Case, async: true
  alias Trivia.BancoPreguntas

  defp banco do
    for tema <- ["ciencia"], nivel <- [:basico, :intermedio, :avanzado], i <- 1..8 do
      %{id: "#{tema}-#{nivel}-#{i}", tema: tema, nivel: nivel, enunciado: "?", opciones: %{}, correcta: "A"}
    end
  end

  test "sortea la cantidad pedida, sin repetir y con el reparto correcto" do
    {:ok, sorteadas} = BancoPreguntas.sortear_en(banco(), "ciencia", 5, :basico)

    assert length(sorteadas) == 5
    assert Enum.frequencies_by(sorteadas, & &1.nivel) == %{basico: 4, intermedio: 1}
  end

  test "tema inexistente" do
    assert BancoPreguntas.sortear_en(banco(), "arte", 5, :basico) == {:error, :tema_inexistente}
  end

  test "no se pueden sortear más preguntas de las disponibles en un nivel" do
    assert BancoPreguntas.sortear_en(banco(), "ciencia", 20, :basico) == {:error, :preguntas_insuficientes}
  end
end
