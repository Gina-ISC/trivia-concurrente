defmodule Trivia.PartidaTest do
  use ExUnit.Case, async: false
  alias Trivia.{BancoPreguntas, Partida}

  setup do
    preguntas =
      for nivel <- [:basico, :intermedio, :avanzado], i <- 1..6 do
        %{
          id: "#{nivel}-#{i}",
          tema: "t",
          nivel: nivel,
          enunciado: "Pregunta",
          opciones: %{"A" => "a", "B" => "b", "C" => "c", "D" => "d"},
          correcta: "B"
        }
      end

    start_supervised!({BancoPreguntas, preguntas: preguntas})
    Application.put_env(:trivia, :pausa_ms, 50)
    on_exit(fn -> Application.delete_env(:trivia, :pausa_ms) end)

    args = %{id: "P-T", creador: "ana", tema: "t", total: 2, tiempo: 5, nivel: :basico, cliente: self()}
    {:ok, pid} = Partida.start_link(args)
    %{partida: pid}
  end


  test "no permite iniciar con menos de dos bots", %{partida: p} do
    assert Partida.iniciar(p) == {:error, :pocos_bots}
    {:ok, _} = Partida.agregar_bot(p, :facil)
    assert Partida.iniciar(p) == {:error, :pocos_bots}
  end

  test "rechaza agregar bots si la partida está llena o ya iniciada", %{partida: p} do
    for _ <- 1..3, do: {:ok, _} = Partida.agregar_bot(p, :facil)
    assert Partida.agregar_bot(p, :facil) == {:error, :partida_llena}

    {:ok, p2} = Partida.start_link(%{id: "P-U", creador: "luis", tema: "t", total: 2, tiempo: 5, nivel: :basico, cliente: self()})
    {:ok, _} = Partida.agregar_bot(p2, :facil)
    {:ok, _} = Partida.agregar_bot(p2, :dificil)
    assert Partida.iniciar(p2) == :ok
    assert Partida.agregar_bot(p2, :facil) == {:error, :partida_iniciada}
  end

  test "sin ronda abierta se rechaza la respuesta", %{partida: p} do
    assert Partida.responder(p, "ana", "A") == {:error, :sin_ronda}
  end

  test "acepta solo la primera respuesta y rechaza la letra inválida sin consumirla", %{partida: p} do
    {:ok, _} = Partida.agregar_bot(p, :facil)
    {:ok, _} = Partida.agregar_bot(p, :facil)
    :ok = Partida.iniciar(p)

    assert_receive {:trivia, {:pregunta, %{numero: 1}}}

    assert Partida.responder(p, "ana", "E") == {:error, :letra_invalida}

    assert Partida.responder(p, "ana", "B") == {:ok, :registrada}

    assert Partida.responder(p, "ana", "C") == {:error, :ya_respondio}
  end

  test "al responder todos se cierra la ronda y llega la siguiente tras la pausa", %{partida: p} do
    {:ok, _} = Partida.agregar_bot(p, :dificil)
    {:ok, _} = Partida.agregar_bot(p, :dificil)
    :ok = Partida.iniciar(p)

    assert_receive {:trivia, {:pregunta, %{numero: 1}}}

    {:ok, :registrada} = Partida.responder(p, "ana", "B")

    assert_receive {:trivia, {:cierre_ronda, %{correcta: "B"}}}, 6000
    assert_receive {:trivia, {:pregunta, %{numero: 2}}}, 1000
  end
end
