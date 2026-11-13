defmodule Trivia.PuntajeTest do
  use ExUnit.Case, async: true
  alias Trivia.Puntaje

  test "respuesta correcta suma puntos del nivel mas bonificacion" do
    assert Puntaje.ronda(:basico, :correcta, 14, 15) == 14
    assert Puntaje.ronda(:avanzado, :correcta, 1, 15) == 20
  end

  test "respuesta incorrecta resta segun el nivel" do
    assert Puntaje.ronda(:intermedio, :incorrecta, 10, 15) == -8
  end

  test "sin responder vale 0" do
    assert Puntaje.ronda(:avanzado, :sin_responder, 0, 15) == 0
  end

  test "nivel invalido lanza un error" do
    assert_raise KeyError, fn ->
      Puntaje.ronda(:super_avanzado, :correcta, 10, 15)
    end
  end
end
