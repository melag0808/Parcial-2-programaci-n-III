defmodule ValidadorParentesis do
  @moduledoc """
  Valida las propuestas del problema 4.

  La lectura del archivo se realiza como Stream, pero la comprobación de cada
  cadena se hace con una función recursiva propia, sin Enum ni Stream.
  """

  @doc """
  Lee `propuestas.txt`, valida cada registro y escribe
  `verificacion_parentesis.txt`.

  Se ignoran comentarios y líneas vacías, conservando el número de línea física.

  - autor: David Cuellar Vélez.
  - fecha: Noviembre del 2026
  - licencia: GNU GPL v3
  """
  def validar_archivo(
        entrada \\ "propuestas.txt",
        salida \\ "verificacion_parentesis.txt"
      ) do
    if File.exists?(entrada) do
      File.write!(salida, "VERIFICACIÓN DE PARÉNTESIS\n")

      entrada
      |> File.stream!()
      |> Stream.with_index(1)
      |> Stream.map(fn {linea, numero} -> {String.trim(linea), numero} end)
      |> Stream.reject(fn {linea, _numero} ->
        linea == "" or String.starts_with?(linea, "#")
      end)
      |> Stream.each(fn {linea, numero} ->
        resultado = validar_linea(linea, numero)
        escribir_resultado(salida, resultado)
      end)
      |> Stream.run()

      :ok
    else
      mensaje = "No existe el archivo requerido: #{entrada}"
      IO.puts(:standard_error, mensaje)
      {:error, :archivo_no_encontrado}
    end
  end

  @doc """
  Valida una propuesta ya separada en `n`, `p` y `cadena`.

  Comprueba recursivamente:

  * longitud igual a `2 * n`;
  * uso exclusivo de `(` y `)`;
  * que ningún prefijo cierre más paréntesis de los abiertos;
  * balance final igual a cero;
  * profundidad máxima no superior a `p`.

  Retorna un mapa con `valida`, `motivos`, `primer_prefijo_problematico`
  y `profundidad_alcanzada`.
  """
  def validar_propuesta(n, p, cadena) do
    errores_iniciales = validar_parametros(n, p, cadena, [])

    estado =
      recorrer(
        String.to_charlist(cadena),
        0,
        0,
        0,
        p,
        nil,
        "",
        []
      )

    errores =
      errores_iniciales
      |> agregar_errores_caracteres(estado.errores_caracteres)
      |> agregar_error_prefijo(estado.primer_prefijo_problematico)
      |> agregar_error_balance(estado.balance)
      |> agregar_error_profundidad(estado.profundidad_maxima, p)
      |> invertir([])

    %{
      valida: errores == [],
      motivos: errores,
      primer_prefijo_problematico: estado.primer_prefijo_problematico,
      profundidad_alcanzada: estado.profundidad_maxima
    }
  end


  defp validar_linea(texto, numero_linea) do
    case String.split(texto, ";") do
      [n_texto, p_texto, cadena] ->
        with {n, ""} <- Integer.parse(String.trim(n_texto)),
             {p, ""} <- Integer.parse(String.trim(p_texto)) do
          resultado = validar_propuesta(n, p, String.trim(cadena))

          %{
            linea: numero_linea,
            n: n,
            p: p,
            cadena: String.trim(cadena),
            resultado: resultado
          }
        else
          _ ->
            %{
              linea: numero_linea,
              error_formato: "n y p deben ser enteros."
            }
        end

      _ ->
        %{
          linea: numero_linea,
          error_formato: "se esperaban exactamente tres campos n;p;cadena."
        }
    end
  end


  defp recorrer([], _posicion, balance, profundidad_maxima, _p, primer_prefijo, _prefijo, errores) do
    %{
      balance: balance,
      profundidad_maxima: profundidad_maxima,
      primer_prefijo_problematico: primer_prefijo,
      errores_caracteres: errores
    }
  end

  defp recorrer([caracter | resto], posicion, balance, profundidad_maxima, p, primer_prefijo, prefijo, errores) do
    nuevo_prefijo = prefijo <> <<caracter>>

    {nuevo_balance, nueva_profundidad, nuevos_errores} =
      case caracter do
        ?( ->
          balance_nuevo = balance + 1
          profundidad_nueva = maximo(balance_nuevo, profundidad_maxima)
          {balance_nuevo, profundidad_nueva, errores}

        ?) ->
          {balance - 1, profundidad_maxima, errores}

        _ ->
          {
            balance,
            profundidad_maxima,
            ["carácter inválido '#{<<caracter>>}' en posición #{posicion}" | errores]
          }
      end

    nuevo_primer_prefijo =
      cond do
        primer_prefijo != nil ->
          primer_prefijo

        nuevo_balance < 0 ->
          %{
            posicion: posicion,
            prefijo: nuevo_prefijo,
            motivo: "se cerraron más paréntesis de los que estaban abiertos"
          }

        nueva_profundidad > p ->
          %{
            posicion: posicion,
            prefijo: nuevo_prefijo,
            motivo: "se superó la profundidad máxima permitida #{p}"
          }

        true ->
          nil
      end

    recorrer(
      resto,
      posicion + 1,
      nuevo_balance,
      nueva_profundidad,
      p,
      nuevo_primer_prefijo,
      nuevo_prefijo,
      nuevos_errores
    )
  end


  defp validar_parametros(n, p, cadena, errores) do
    errores =
      if n >= 1 do
        errores
      else
        ["n debe ser mayor o igual a 1" | errores]
      end

    errores =
      if p >= 1 and p <= n do
        errores
      else
        ["la profundidad máxima debe cumplir 1 <= p <= n" | errores]
      end

    if String.length(cadena) == 2 * n do
      errores
    else
      [
        "la longitud debe ser #{2 * n} y se obtuvo #{String.length(cadena)}"
        | errores
      ]
    end
  end

  defp agregar_errores_caracteres(errores, []), do: errores

  defp agregar_errores_caracteres(errores, [error | resto]) do
    agregar_errores_caracteres([error | errores], resto)
  end

  defp agregar_error_prefijo(errores, nil), do: errores

  defp agregar_error_prefijo(errores, %{posicion: posicion, prefijo: prefijo, motivo: motivo}) do
    [
      "primer prefijo problemático en posición #{posicion}: '#{prefijo}' (#{motivo})"
      | errores
    ]
  end

  defp agregar_error_balance(errores, 0), do: errores

  defp agregar_error_balance(errores, balance) do
    ["el balance final debe ser 0 y terminó en #{balance}" | errores]
  end

  defp agregar_error_profundidad(errores, profundidad, p) do
    if profundidad > p do
      ["la profundidad alcanzada fue #{profundidad}, superior al máximo permitido #{p}" | errores]
    else
      errores
    end
  end


  defp escribir_resultado(salida, %{linea: linea, error_formato: error}) do
    File.write!(salida, "Línea #{linea}: INVÁLIDA - #{error}\n", [:append])
  end

  defp escribir_resultado(salida, %{linea: linea, n: n, p: p, cadena: cadena, resultado: resultado}) do
    if resultado.valida do
      File.write!(
        salida,
        "Línea #{linea}: n=#{n}; p=#{p}; #{cadena} -> VÁLIDA\n",
        [:append]
      )
    else
      File.write!(
        salida,
        "Línea #{linea}: n=#{n}; p=#{p}; #{cadena} -> INVÁLIDA\n",
        [:append]
      )

      escribir_motivos(salida, resultado.motivos)
    end
  end

  defp escribir_motivos(_salida, []), do: :ok

  defp escribir_motivos(salida, [motivo | resto]) do
    File.write!(salida, "  - #{motivo}\n", [:append])
    escribir_motivos(salida, resto)
  end

 defp maximo(a, b) when a >= b, do: a
defp maximo(_a, b), do: b

defp invertir([], acumulador), do: acumulador

defp invertir([elemento | resto], acumulador) do
  invertir(resto, [elemento | acumulador])
end

end
