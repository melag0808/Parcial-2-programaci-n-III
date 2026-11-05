defmodule Main do
  @moduledoc """
  Programa principal del parcial. Ejecuta el Problema 2 (planificación de
  tareas) y el Problema 4 (paréntesis balanceados).

  Debe estar en la carpeta que contiene Problema2/ y Problema4/.

      elixir main.exs

  Cada problema se ejecuta dentro de su propia carpeta, porque lee sus
  entradas y escribe sus salidas en el directorio actual.
  """

  @raiz __DIR__

  def run do
    IO.puts("""
    ==============================
     PARCIAL - PROGRAMACIÓN III
    ==============================
     1. Problema 2: planificación de tareas
     2. Problema 4: paréntesis balanceados
     3. Ejecutar ambos
    """)

    case "Elige una opción (1-3): " |> IO.gets() |> to_string() |> String.trim() do
      "1" -> problema_2()
      "2" -> problema_4()
      "3" ->
        problema_2()
        problema_4()

      _ -> IO.puts("Opción no válida.")
    end
  end

  # ------------------------------------------------------------------
  # Problema 2: planificación de tareas con dependencias
  # ------------------------------------------------------------------

  defp problema_2 do
    IO.puts("\n>>> PROBLEMA 2: planificación de tareas\n")

    en_carpeta("Problema2", fn ->
      # tarea.ex va primero: define los structs Tarea y Plan que usan los demás.
      cargar([
        "tarea.ex",
        "lector.ex",
        "validador.ex",
        "generador_reportes.ex",
        "generador_svg.ex",
        "planificador.ex"
      ])

      case Lector.leer_tareas("tareas.csv") do
        {:ok, registros} ->
          {tareas, errores} = validar_tareas(registros)

          # "." = los reportes se escriben en la carpeta Problema2
          tareas
          |> Planificador.ejecutar(errores, ".")
          |> mostrar_resultado_2()

        {:error, {:archivo_no_encontrado, ruta}} ->
          IO.puts("No existe el archivo de tareas: #{ruta}")
      end
    end)
  end

  defp validar_tareas(registros) do
    case Validador.validar(registros, "validacion_tareas.txt") do
      {:ok, tareas} -> {tareas, []}
      {:error, errores} -> {[], errores}
    end
  end

  defp mostrar_resultado_2({:ok, %{total_planes: 0}}) do
    IO.puts("Proyecto vacío: no hay tareas, no se enumeraron planes.")
  end

  defp mostrar_resultado_2({:ok, %{total_planes: total, penalizacion_minima: minima, mejores: [mejor | _]}}) do
    IO.puts("Planes válidos: #{total}")
    IO.puts("Penalización mínima: #{minima}")
    IO.puts("Primer plan óptimo: #{Enum.join(mejor.orden, " -> ")}")
    IO.puts("Archivos: planes.csv, resumen_tareas.txt, validacion_tareas.txt, mejor_plan.svg")
  end

  defp mostrar_resultado_2({:error, :red_invalida}) do
    IO.puts("La red de tareas es inválida. Revisa validacion_tareas.txt")
  end

  defp mostrar_resultado_2({:error, :sin_planes}) do
    IO.puts("No se encontró ningún orden válido de ejecución.")
  end

  # ------------------------------------------------------------------
  # Problema 4: paréntesis balanceados con profundidad máxima
  # ------------------------------------------------------------------

  defp problema_4 do
    IO.puts("\n>>> PROBLEMA 4: paréntesis balanceados\n")

    en_carpeta("Problema4", fn ->
      cargar([
        "generador_parentesis.ex",
        "validador_parentesis.ex",
        "generador_reportes.ex"
      ])

      IO.puts("--- Validación de propuestas ---")

      case ValidadorParentesis.validar_archivo("propuestas.txt", "verificacion_parentesis.txt") do
        :ok -> IO.puts(File.read!("verificacion_parentesis.txt"))
        {:error, razon} -> IO.puts("No se pudo validar: #{inspect(razon)}\n")
      end

      IO.puts("--- Soluciones, primera n=18/p=18 y secuencia ---")

      if File.exists?("parametros.csv") do
        ReportesParentesis.ejecutar("parametros.csv")
      else
        IO.puts("No existe parametros.csv; no se generan los archivos de soluciones.")
      end
    end)
  end

  # ------------------------------------------------------------------
  # Utilidades
  # ------------------------------------------------------------------

  # Ejecuta `funcion` dentro de la carpeta del problema y vuelve a la anterior.
  defp en_carpeta(nombre, funcion) do
    File.cd!(Path.join(@raiz, nombre), funcion)
  end

  defp cargar(archivos), do: Enum.each(archivos, &Code.require_file/1)
end

Main.run()
