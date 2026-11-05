
defmodule Planificador do
  @moduledoc """
  Genera todos los planes posibles de ejecución de tareas,
  respetando sus dependencias.

  Calcula el tiempo de finalización de cada tarea y la
  penalización por terminar después del plazo establecido.
  """

  @doc """
  Ejecuta la planificación.

  Recibe:
  - tareas: lista de estructuras %Tarea{} ya validadas.
  - errores: lista de errores encontrados por el validador.
  - directorio: carpeta donde se guardan los reportes.

  Si hay errores, no enumera planes.
  """
  def ejecutar(tareas, errores, directorio \\ "problema2")
      when is_list(tareas) and is_list(errores) do

    ruta_planes = Path.join(directorio, "planes.csv")
    ruta_resumen = Path.join(directorio, "resumen_tareas.txt")
    ruta_validacion = Path.join(directorio, "validacion_tareas.txt")
    ruta_svg = Path.join(directorio, "mejor_plan.svg")

    # Primero se escribe el resultado de la validación.
    GeneradorReportes.escribir_validacion(ruta_validacion, errores)

    cond do
      # Si existen errores, no se generan planes.
      errores != [] ->
        crear_csv_vacio(ruta_planes)

        File.write!(
          ruta_resumen,
          "La red de tareas es inválida.\n" <>
          "No se enumeraron planes porque existen errores de validación.\n"
        )

        GeneradorSvg.generar(
          ruta_svg,
          nil,
          tareas,
          "La red de tareas contiene errores de validación."
        )

        {:error, :red_invalida}

      # Si no hay tareas, se informa que el proyecto está vacío.
      tareas == [] ->
        crear_csv_vacio(ruta_planes)

        GeneradorReportes.escribir_resumen(
          ruta_resumen,
          0,
          nil,
          []
        )

        GeneradorSvg.generar(
          ruta_svg,
          nil,
          [],
          "El proyecto está vacío."
        )

        {:ok, %{total_planes: 0}}

      # Si la validación fue satisfactoria, comienza la planificación.
      true ->
        ejecutar_planificacion(
          tareas,
          ruta_planes,
          ruta_resumen,
          ruta_svg
        )
    end
  end

  # ---------------------------------------------------------
  # Ejecución de la planificación
  # ---------------------------------------------------------

  defp ejecutar_planificacion(tareas, ruta_planes, ruta_resumen, ruta_svg) do
    dispositivo = GeneradorReportes.abrir_planes_csv(ruta_planes)

    estado_inicial = %{
      total: 0,
      penalizacion_minima: nil,
      mejores: []
    }

    estado_final =
      try do
        enumerar(
          tareas,
          MapSet.new(),
          [],
          0,
          %{},
          0,
          dispositivo,
          estado_inicial
        )
      after
        GeneradorReportes.cerrar_planes_csv(dispositivo)
      end

    total = estado_final.total
    mejores = Enum.reverse(estado_final.mejores)
    penalizacion_minima = estado_final.penalizacion_minima

    cond do
      total == 0 ->
        File.write!(
          ruta_resumen,
          "No se encontró ningún orden válido de ejecución.\n" <>
          "Revise las dependencias de las tareas.\n"
        )

        GeneradorSvg.generar(
          ruta_svg,
          nil,
          tareas,
          "No se encontró un orden válido de ejecución."
        )

        {:error, :sin_planes}

      true ->
        GeneradorReportes.escribir_resumen(
          ruta_resumen,
          total,
          penalizacion_minima,
          mejores
        )

        # El primer plan de la lista es el primer plan óptimo encontrado.
        mejor_plan = hd(mejores)

        GeneradorSvg.generar(
          ruta_svg,
          mejor_plan,
          tareas
        )

        {:ok,
         %{
           total_planes: total,
           penalizacion_minima: penalizacion_minima,
           mejores: mejores
         }}
    end
  end

  # ---------------------------------------------------------
  # Enumeración recursiva de los planes
  # ---------------------------------------------------------

  # Caso base: no quedan tareas pendientes.
  # Se ha completado un plan válido.
  defp enumerar(
         [],
         _completadas,
         orden,
         _tiempo,
         finalizaciones,
         penalizacion,
         dispositivo,
         estado
       ) do

    plan = struct(Plan,
      orden: orden,
      finalizaciones: finalizaciones,
      penalizacion: penalizacion
    )

    numero_plan = estado.total + 1

    # Escribe el plan inmediatamente en planes.csv.
    GeneradorReportes.escribir_plan(
      dispositivo,
      numero_plan,
      plan
    )

    actualizar_mejores(estado, plan)
  end

  # Caso recursivo: todavía quedan tareas por ejecutar.
  defp enumerar(
         pendientes,
         completadas,
         orden,
         tiempo,
         finalizaciones,
         penalizacion,
         dispositivo,
         estado
       ) do

    # Busca las tareas cuyas dependencias ya fueron completadas.
    # Las ordena alfabéticamente por su identificador.
    disponibles =
      pendientes
      |> Enum.filter(fn tarea ->
        Enum.all?(tarea.dependencias, fn dependencia ->
          MapSet.member?(completadas, dependencia)
        end)
      end)
      |> Enum.sort_by(fn tarea -> tarea.id end)

    # Prueba cada tarea disponible como siguiente paso.
    Enum.reduce(disponibles, estado, fn tarea, acumulador ->

      nuevos_pendientes =
        Enum.reject(pendientes, fn otra ->
          otra.id == tarea.id
        end)

      nuevo_tiempo = tiempo + tarea.duracion

      # Penalización: solo se suma si termina después del plazo.
      retraso = max(0, nuevo_tiempo - tarea.plazo)

      nuevas_finalizaciones =
        Map.put(finalizaciones, tarea.id, nuevo_tiempo)

      nuevas_completadas =
        MapSet.put(completadas, tarea.id)

      nuevo_orden = orden ++ [tarea.id]

      enumerar(
        nuevos_pendientes,
        nuevas_completadas,
        nuevo_orden,
        nuevo_tiempo,
        nuevas_finalizaciones,
        penalizacion + retraso,
        dispositivo,
        acumulador
      )
    end)
  end

  # ---------------------------------------------------------
  # Actualización del mejor resultado
  # ---------------------------------------------------------

  defp actualizar_mejores(estado, plan) do
    total = estado.total + 1
    minima = estado.penalizacion_minima
    penalizacion = plan.penalizacion

    cond do
      # Es el primer plan encontrado.
      minima == nil ->
        %{
          total: total,
          penalizacion_minima: penalizacion,
          mejores: [plan]
        }

      # Se encontró una penalización menor.
      penalizacion < minima ->
        %{
          total: total,
          penalizacion_minima: penalizacion,
          mejores: [plan]
        }

      # Se encontró otro plan con la misma penalización mínima.
      penalizacion == minima ->
        %{
          total: total,
          penalizacion_minima: minima,
          mejores: [plan | estado.mejores]
        }

      # El plan no mejora el resultado.
      true ->
        %{estado | total: total}
    end
  end

  # ---------------------------------------------------------
  # Creación de un CSV sin planes
  # ---------------------------------------------------------

  defp crear_csv_vacio(ruta) do
    dispositivo = GeneradorReportes.abrir_planes_csv(ruta)
    GeneradorReportes.cerrar_planes_csv(dispositivo)
  end
end
