defmodule GeneradorReportes do
  @moduledoc """
  Genera los reportes de texto del Problema 2:

    * `planes.csv`            -> una fila por plan, escrita a medida que la
                                 recursión produce cada plan.
    * `resumen_tareas.txt`    -> total de planes, penalización mínima y los
                                 planes que la alcanzan.
    * `validacion_tareas.txt` -> problemas detectados en la validación previa.

  @separador_orden "->"
  @encabezado_planes "id;orden;duracion_total;penalizacion"

  @doc """
  Abre `planes.csv`, escribe el encabezado y devuelve el dispositivo de
  archivo. Se usa antes de iniciar la recursión del planificador.
  """
  def abrir_planes_csv(ruta) do
    File.mkdir_p!(Path.dirname(ruta))
    dev = File.open!(ruta, [:write, :utf8])
    IO.write(dev, @encabezado_planes <> "\n")
    dev
  end

  @doc """
  Escribe una fila de plan. `id` es el número consecutivo del plan (1, 2, ...).
  Se llama desde la recursión cada vez que se completa un orden válido.
  """
  def escribir_plan(dev, id, plan) do
    IO.write(
      dev,
      "#{id};#{orden_a_texto(plan.orden)};#{duracion_total(plan)};#{plan.penalizacion}\n"
    )
  end

  @doc "Cierra el archivo de `planes.csv`."
  def cerrar_planes_csv(dev), do: File.close(dev)

  # ------------------------------------------------------------------
  # resumen_tareas.txt
  # ------------------------------------------------------------------

  @doc """
  Escribe el resumen. Recibe lo que el planificador fue acumulando:

    * `total`                 -> cantidad de planes válidos
    * `penalizacion_minima`   -> menor penalización encontrada
    * `mejores`               -> lista de planes que alcanzan esa penalización

  Si `total` es 0 (proyecto vacío) lo reporta sin más.
  """
  def escribir_resumen(ruta, total, penalizacion_minima, mejores)

  def escribir_resumen(ruta, 0, _penalizacion_minima, _mejores) do
    File.mkdir_p!(Path.dirname(ruta))

    File.open!(ruta, [:write, :utf8], fn dev ->
      IO.write(dev, "Resumen de planificación\n")
      IO.write(dev, "========================\n")
      IO.write(dev, "Proyecto vacío: no hay tareas, no se enumeraron planes.\n")
      IO.write(dev, "Total de planes: 0\n")
    end)

    :ok
  end

  def escribir_resumen(ruta, total, penalizacion_minima, mejores) do
    File.mkdir_p!(Path.dirname(ruta))

    File.open!(ruta, [:write, :utf8], fn dev ->
      IO.write(dev, "Resumen de planificación\n")
      IO.write(dev, "========================\n")
      IO.write(dev, "Total de planes válidos: #{total}\n")
      IO.write(dev, "Penalización mínima: #{penalizacion_minima}\n")

      case mejores do
        [primero | _] ->
          IO.write(dev, "Tiempo total del proyecto: #{duracion_total(primero)}\n")

        [] ->
          :ok
      end

      IO.write(
        dev,
        "Planes que alcanzan la penalización mínima (#{length(mejores)}):\n"
      )

      mejores
      |> Enum.with_index(1)
      |> Enum.each(fn {plan, i} ->
        IO.write(
          dev,
          "  #{i}. #{orden_a_texto(plan.orden)} " <>
            "(duración total: #{duracion_total(plan)}, penalización: #{plan.penalizacion})\n"
        )
      end)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # validacion_tareas.txt
  # ------------------------------------------------------------------

  @doc """
  Escribe el reporte de validación. `errores` es una lista de mensajes
  (strings) con todos los problemas detectados. Si está vacía, la red es válida.
  """
  def escribir_validacion(ruta, errores) do
    File.mkdir_p!(Path.dirname(ruta))

    File.open!(ruta, [:write, :utf8], fn dev ->
      IO.write(dev, "Validación de tareas\n")
      IO.write(dev, "====================\n")

      case errores do
        [] ->
          IO.write(dev, "Red válida: no se detectaron problemas.\n")

        _ ->
          IO.write(dev, "Red inválida. Problemas detectados (#{length(errores)}):\n")
          Enum.each(errores, fn error -> IO.write(dev, "- #{error}\n") end)
          IO.write(dev, "No se enumeraron planes.\n")
      end
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Utilidades
  # ------------------------------------------------------------------

  defp orden_a_texto(orden), do: Enum.join(orden, @separador_orden)

  # Sin pausas entre tareas, la duración total es el mayor tiempo de fin.
  defp duracion_total(plan) do
    plan.finalizaciones
    |> Map.new()
    |> Map.values()
    |> Enum.max(fn -> 0 end)
  end
end
