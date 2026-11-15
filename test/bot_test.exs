defmodule Trivia.BotTest do
  use ExUnit.Case, async: true
  alias Trivia.Bot

  test "devuelve una letra válida y un retardo dentro del rango de su dificultad" do
    for _ <- 1..300 do
      {letra, retardo} = Bot.decidir(:facil, :basico, "B", 15)
      assert letra in ["A", "B", "C", "D"]
      assert retardo >= 6000 and retardo <= 13_500

      {letra, retardo} = Bot.decidir(:dificil, :avanzado, "C", 15)
      assert letra in ["A", "B", "C", "D"]
      assert retardo >= 1500 and retardo <= 6000
    end
  end

  test "el bot difícil acierta más que el fácil" do
    aciertos = fn dif -> Enum.count(1..2000, fn _ -> elem(Bot.decidir(dif, :basico, "A", 10), 0) == "A" end) end
    assert aciertos.(:dificil) > aciertos.(:facil)
  end
end
