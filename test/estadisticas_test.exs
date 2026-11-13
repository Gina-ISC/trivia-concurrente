defmodule Trivia.EstadisticasTest do
  use ExUnit.Case, async: true
  alias Trivia.{Historial, Nivel}

  @lineas [
    "2026-11-01T10:00:00Z|P-1001|ciencia|basico|pedro|pedro=48,bot_1=22,bot_2=-11",
    "2026-11-02T10:00:00Z|P-1002|historia|basico|bot_1|pedro=13,bot_1=40,bot_2=5",
    "2026-11-03T10:00:00Z|P-1003|ciencia|basico|ana|ana=30,pedro=-10,bot_1=2"
  ]

  test "puntaje acumulado y partidas jugadas ignorando bots" do
    assert %{puntaje: 51, partidas: 3} = Historial.resumen(@lineas, "pedro")
    assert Historial.ranking(@lineas) == [{"pedro", 51, 3}, {"ana", 30, 1}]
  end

  test "umbrales de nivel" do
    assert Nivel.nivel(59) == :basico
    assert Nivel.nivel(60) == :intermedio
    assert Nivel.nivel(180) == :avanzado
  end

  test "reparto por nivel" do
    assert Nivel.reparto(5, :basico) == %{basico: 4, intermedio: 1, avanzado: 0}
    assert Nivel.reparto(10, :avanzado) == %{basico: 0, intermedio: 3, avanzado: 7}
  end

  test "los puntajes negativos restan del acumulado total" do
    lineas = [
      "2026-11-01T10:00:00Z|P-1|ciencia|basico|pedro|pedro=-15,bot_1=5"
    ]
    assert %{puntaje: -15, partidas: 1} = Historial.resumen(lineas, "pedro")
  end
end
