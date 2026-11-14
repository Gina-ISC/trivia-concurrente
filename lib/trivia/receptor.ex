defmodule Trivia.Receptor do
  @moduledoc "cliente, proceso que recibe e imprime las notificaciones de la partida"

  def iniciar, do: spawn_link(&bucle/0)

  defp bucle do
    receive do
      {:trivia, notificacion} ->
        notificacion |> formatear() |> IO.puts()
        bucle()

      :detener ->
        :ok

      _otro ->
        bucle()
    end
  end

  def formatear({:pregunta, i}) do
    letras = ["A", "B", "C", "D"]
    opciones = Enum.map_join(letras, "  ", fn l -> "#{l}) #{i.opciones[l]}" end)

    """

    === Pregunta #{i.numero} de #{i.total} - #{i.tema} - Nivel #{i.nivel} ===
    #{i.enunciado}
    #{opciones}
    Tiempo: #{i.tiempo} segundos
    Respuesta > (answer <letra>)\
    """
  end

  def formatear({:cierre_ronda, c}) do
    filas = Enum.map_join(c.puntajes, "\n", fn {j, delta, total} -> "#{j} #{signo(delta)} (total #{total})" end)
    "\nRespuesta correcta: #{c.correcta}) #{c.texto}\n#{filas}"
  end

  def formatear({:fin, f}) do
    filas =
      f.ranking
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {{j, p}, pos} -> "#{pos} #{j} #{p}" end)

    nota = if f.abandono, do: " (partida terminada por abandono)", else: ""

    "\n= Fin de la partida #{f.id} (#{f.tema}, nivel #{f.nivel}) =#{nota}\nJugador Puntaje\n#{filas}\nGanador: #{Enum.join(f.ganadores, ", ")}"
  end

  def formatear({:cancelada, id}), do: "La partida #{id} fue cancelada."

  def formatear({:reinicio, id}),
    do: "La partida #{id} falló y se reinició sin su progreso. Agrega los bots y ejecuta start_game."

  def formatear(otra), do: inspect(otra)

  defp signo(n) when n >= 0, do: "+#{n}"
  defp signo(n), do: "#{n}"
end
