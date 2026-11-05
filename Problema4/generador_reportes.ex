defmodule ReportesParentesis do
  @moduledoc """
  Genera todos los archivos de salida del Problema 4:
  informe de validez verificación_parentesis.txt
  secuencia de conteos secuencia_parentesis.csv
  primera solución primera_n18_p18.txt
  y todos los archivos de soluciones válidas parentesis_n<N>_p<P>.txt
  """

  @umbral 1000


  # Punto de entrada

  @doc """
  Ejecuta los reportes que no dependen del validador:
  parámetros del CSV, primera solución n=18/p=18 y secuencia infinita.
  """
  def ejecutar(ruta_parametros \\ "parametros.csv") do
    ruta_parametros
    |> leer_parametros()
    |> Enum.each(fn {n, p} -> reporte_parentesis(n, p) end)

    reporte_primera_solucion(18, 18)
    reporte_secuencia()
    :ok
  end


  # Lectura de parametros.csv  (formato n;profundidad_max, '#' = comentario)

  def leer_parametros(ruta) do
    ruta
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(&parsear_linea/1)
  end

  defp parsear_linea(linea) do
    [n, p] =
      linea
      |> String.split(";")
      |> Enum.map(fn campo -> campo |> String.trim() |> String.to_integer() end)

    if n >= 1 and p >= 1 and p <= n do
      {n, p}
    else
      raise ArgumentError, "parámetros inválidos (se requiere n >= 1 y 1 <= p <= n): #{linea}"
    end
  end

  # parentesis_n<N>_p<P>.txt
  # Escribe cada solución al consumirla y cuenta el total sin guardar lista.
  def reporte_parentesis(n, p) do
    nombre = "parentesis_n#{n}_p#{p}.txt"

    total =
      File.open!(nombre, [:write, :utf8], fn dispositivo ->
        total =
          n
          |> GeneradorParentesis.generar(p)
          |> Enum.reduce(0, fn cadena, acumulado ->
            IO.puts(dispositivo, cadena)
            acumulado + 1
          end)

        IO.puts(dispositivo, "Total: #{total}")
        total
      end)

    IO.puts("n=#{n}, p=#{p} -> total: #{total}  (#{nombre})")
    total
  end


  # primera_n18_p18.txt
  # Enum.take(stream, 1) consume SOLO el primer elemento: el resto del Stream nunca se calcula.

  def reporte_primera_solucion(n, p) do
    nombre = "primera_n#{n}_p#{p}.txt"

    [primera] =
      n
      |> GeneradorParentesis.generar(p)
      |> Enum.take(1)

    File.write!(nombre, primera <> "\n")
    IO.puts("Primera solución n=#{n}, p=#{p}: #{primera}  (#{nombre})")
    primera
  end


  # verificacion_parentesis.txt

  def reporte_verificacion(resultados, ruta \\ "verificacion_parentesis.txt") do
    contenido =
      resultados
      |> Enum.map(&formatear_resultado/1)
      |> Enum.join("\n")

    File.write!(ruta, contenido <> "\n")
    IO.puts("Verificación escrita en #{ruta}")
    :ok
  end

  defp formatear_resultado(%{n: n, p: p, cadena: cadena, valida: true}) do
    "#{n};#{p};#{cadena} -> VÁLIDA"
  end

  defp formatear_resultado(%{n: n, p: p, cadena: cadena, motivos: motivos}) do
    detalle = Enum.map_join(motivos, "\n", fn motivo -> "    - " <> motivo end)
    "#{n};#{p};#{cadena} -> INVÁLIDA\n" <> detalle
  end


  # secuencia_parentesis.csv

  @doc """
  Stream infinito {n, total} para n = 1, 2, 3, ... con p = n.
  Stream.iterate y Stream.map son perezosos
  """
  def secuencia_infinita do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn n -> {n, GeneradorParentesis.contar(n, n)} end)
  end

  @doc """
  Escribe el CSV y deja de consumir justo después del primer n con tottal >= 1000 (incluyéndolo). Enum.reduce_while corta sin pedirle
  al Stream el siguiente elemento, por eso n=9 no se calcula.
  """
  def reporte_secuencia(ruta \\ "secuencia_parentesis.csv") do
    File.open!(ruta, [:write, :utf8], fn dispositivo ->
      IO.puts(dispositivo, "n;total")

      secuencia_infinita()
      |> Enum.reduce_while(nil, fn {n, total}, _ ->
        IO.puts(dispositivo, "#{n};#{total}")
        IO.puts("n=#{n} -> total #{total}")

        if total >= @umbral do
          {:halt, {n, total}}
        else
          {:cont, nil}
        end
      end)
    end)
  end
end
