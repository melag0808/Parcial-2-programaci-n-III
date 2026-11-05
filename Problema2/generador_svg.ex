defmodule GeneradorSvg do
  @moduledoc """
  Salida -> `mejor_plan.svg`: diagrama de Gantt del primer plan óptimo.

  - Eje horizontal en unidades de tiempo.
  - Una barra por tarea, con longitud proporcional a su duración.
  - Hora de inicio y de fin visibles en cada barra.
  - Tareas terminadas fuera de plazo en rojo (distincion visual).
  - Si no hay plan, dibuja una leyenda explicativa.

  Escritura progresiva sobre el archivo, sin construir un único string gigante.
  """

  @margen 20
  @ancho_etiquetas 70
  @margen_derecho 60
  @ancho_util 800
  @alto_titulo 50
  @alto_fila 40
  @alto_barra 24
  @alto_eje 35
  @alto_leyenda 80

  @color_a_tiempo "#4caf50"
  @color_tarde "#e53935"

  # ------------------------------------------------------------------
  # API pública
  # ------------------------------------------------------------------

  @doc """
  Escribe el SVG en `ruta`. Si `plan` es `nil`, dibuja solo la leyenda
  explicativa (opcionalmente con un `motivo`).
  """
  def generar(ruta, plan, tareas \\ [], motivo \\ nil) #Pone por defecto tareas a [] y motivo a nil

  def generar(ruta, nil, _tareas, motivo) do # Clausula generar 2: omite tarea y dibuja la leyenda explicativa
    preparar_directorio(ruta)

    File.open!(ruta, [:write, :utf8], fn dev ->
      ancho = 640
      alto = 260

      abrir_svg(dev, ancho, alto)
      escribir_fondo(dev)
      escribir_titulo(dev, "No hay plan para mostrar", @margen)

      texto_motivo =
        motivo ||
          "El proyecto está vacío o la red de tareas no es válida, por eso no se enumeraron planes."

      IO.write(dev, texto(@margen, 62, texto_motivo, "start", "font-size=\"13\""))
      escribir_leyenda(dev, @margen, 90)
      cerrar_svg(dev)
    end)

    :ok
  end

  def generar(ruta, plan, tareas, _motivo) do #Clausula generar 3: Dibuja el diagrama de Gantt
    preparar_directorio(ruta)

    mapa = indexar_tareas(tareas)
    fin = Map.new(plan.finalizaciones)
    orden = plan.orden
    total = max(fin |> Map.values() |> Enum.max(fn -> 0 end), 1)

    escala = @ancho_util / total
    izquierda = @margen + @ancho_etiquetas
    ancho = izquierda + @ancho_util + @margen_derecho
    alto = @alto_titulo + length(orden) * @alto_fila + @alto_eje + @alto_leyenda

    File.open!(ruta, [:write, :utf8], fn dev ->
      abrir_svg(dev, ancho, alto)
      escribir_fondo(dev)
      escribir_titulo(dev, "Diagrama de Gantt - mejor plan", @margen)

      escribir_eje(dev, total, escala, izquierda, orden)

      orden
      |> Enum.with_index()
      |> Enum.each(fn {id, i} ->
        escribir_fila(dev, id, i, Map.fetch!(mapa, id), Map.fetch!(fin, id), escala, izquierda)
      end)

      y_leyenda = @alto_titulo + length(orden) * @alto_fila + @alto_eje + 10
      escribir_leyenda(dev, @margen, y_leyenda)
      cerrar_svg(dev)
    end)

    :ok
  end

end 
