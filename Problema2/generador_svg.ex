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

 # Piezas del dibujo (cada una escribe directamente al archivo)

  defp abrir_svg(dev, ancho, alto) do
    IO.write(dev, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")

    IO.write(
      dev,
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{ancho}\" height=\"#{alto}\" " <>
        "viewBox=\"0 0 #{ancho} #{alto}\" font-family=\"sans-serif\">\n"
    )
  end

  defp cerrar_svg(dev), do: IO.write(dev, "</svg>\n")

  defp escribir_fondo(dev) do
    IO.write(dev, "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n")
  end

  defp escribir_titulo(dev, titulo, x) do
    IO.write(dev, texto(x, 30, titulo, "start", "font-size=\"18\" font-weight=\"bold\""))
  end

  # Eje de tiempo con líneas de guía verticales y números.
  defp escribir_eje(dev, total, escala, izquierda, orden) do
    paso = max(ceil(total / 20), 1)
    y_ini = @alto_titulo
    y_fin = @alto_titulo + length(orden) * @alto_fila

    for t <- 0..total//paso do
      x = izquierda + t * escala

      IO.write(
        dev,
        "<line x1=\"#{n(x)}\" y1=\"#{y_ini}\" x2=\"#{n(x)}\" y2=\"#{y_fin}\" " <>
          "stroke=\"#dddddd\" stroke-width=\"1\"/>\n"
      )

      IO.write(dev, texto(x, y_fin + 16, Integer.to_string(t), "middle", "font-size=\"11\""))
    end

    # Línea base del eje y título del eje
    IO.write(
      dev,
      "<line x1=\"#{n(izquierda)}\" y1=\"#{y_fin}\" x2=\"#{n(izquierda + total * escala)}\" " <>
        "y2=\"#{y_fin}\" stroke=\"#333333\" stroke-width=\"1.5\"/>\n"
    )

    IO.write(
      dev,
      texto(
        izquierda + total * escala / 2,
        y_fin + 30,
        "Tiempo (unidades)",
        "middle",
        "font-size=\"12\""
      )
    )
  end

  # Una fila: etiqueta con el id, barra, inicio/fin y marcador de plazo.
  defp escribir_fila(dev, id, i, tarea, fin, escala, izquierda) do
    inicio = fin - tarea.duracion
    tarde? = fin > tarea.plazo
    color = if tarde?, do: @color_tarde, else: @color_a_tiempo

    y_fila = @alto_titulo + i * @alto_fila
    y_barra = y_fila + div(@alto_fila - @alto_barra, 2)
    x_ini = izquierda + inicio * escala
    x_fin = izquierda + fin * escala
    centro_y = y_barra + div(@alto_barra, 2) + 4

    # Etiqueta de la tarea
    IO.write(
      dev,
      texto(izquierda - 8, centro_y, id, "end", "font-size=\"13\" font-weight=\"bold\"")
    )

    # Barra
    IO.write(
      dev,
      "<rect x=\"#{n(x_ini)}\" y=\"#{y_barra}\" width=\"#{n(x_fin - x_ini)}\" " <>
        "height=\"#{@alto_barra}\" fill=\"#{color}\" stroke=\"#333333\" stroke-width=\"1\" rx=\"3\"/>\n"
    )

    # Hora de inicio (a la izquierda de la barra) y de fin (a la derecha)
    IO.write(dev, texto(x_ini - 4, centro_y, Integer.to_string(inicio), "end", "font-size=\"11\""))

    etiqueta_fin =
      if tarde?, do: "#{fin} (+#{fin - tarea.plazo})", else: Integer.to_string(fin)

    IO.write(dev, texto(x_fin + 4, centro_y, etiqueta_fin, "start", "font-size=\"11\""))

    # Marcador del plazo (línea discontinua)
    x_plazo = izquierda + tarea.plazo * escala

    IO.write(
      dev,
      "<line x1=\"#{n(x_plazo)}\" y1=\"#{y_barra - 3}\" x2=\"#{n(x_plazo)}\" " <>
        "y2=\"#{y_barra + @alto_barra + 3}\" stroke=\"#000000\" stroke-width=\"2\" " <>
        "stroke-dasharray=\"4,2\"/>\n"
    )
  end

  # Leyenda explicativa (también se usa cuando no hay plan).
  defp escribir_leyenda(dev, x, y) do
    IO.write(dev, texto(x, y + 14, "Leyenda", "start", "font-size=\"13\" font-weight=\"bold\""))

    IO.write(
      dev,
      "<rect x=\"#{x}\" y=\"#{y + 22}\" width=\"20\" height=\"12\" fill=\"#{@color_a_tiempo}\" " <>
        "stroke=\"#333333\"/>\n"
    )

    IO.write(dev, texto(x + 28, y + 32, "Tarea terminada dentro de plazo", "start", "font-size=\"12\""))

    IO.write(
      dev,
      "<rect x=\"#{x + 260}\" y=\"#{y + 22}\" width=\"20\" height=\"12\" " <>
        "fill=\"#{@color_tarde}\" stroke=\"#333333\"/>\n"
    )

    IO.write(
      dev,
      texto(x + 288, y + 32, "Tarea terminada fuera de plazo (+retraso)", "start", "font-size=\"12\"")
    )

    IO.write(
      dev,
      "<line x1=\"#{x + 10}\" y1=\"#{y + 44}\" x2=\"#{x + 10}\" y2=\"#{y + 58}\" " <>
        "stroke=\"#000000\" stroke-width=\"2\" stroke-dasharray=\"4,2\"/>\n"
    )

    IO.write(dev, texto(x + 28, y + 56, "Plazo de la tarea", "start", "font-size=\"12\""))
  end

  # Utilidades

  defp texto(x, y, contenido, ancla, extra) do
    "<text x=\"#{n(x)}\" y=\"#{n(y)}\" text-anchor=\"#{ancla}\" #{extra}>" <>
      escapar(to_string(contenido)) <> "</text>\n"
  end

  defp indexar_tareas(tareas) when is_map(tareas) and not is_struct(tareas), do: tareas
  defp indexar_tareas(tareas), do: Map.new(tareas, &{&1.id, &1})

  defp preparar_directorio(ruta), do: File.mkdir_p!(Path.dirname(ruta))

  # Formatea números (enteros tal cual, decimales con 2 cifras).
  defp n(valor) when is_integer(valor), do: Integer.to_string(valor)
  defp n(valor) when is_float(valor), do: valor |> Float.round(2) |> Float.to_string()

  defp escapar(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")

end
