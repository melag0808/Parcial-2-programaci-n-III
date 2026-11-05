defmodule GeneradorParentesis do
  @moduledoc """
  Genera cadenas de paréntesis balanceados respetando una profundidad
  máxima. La búsqueda es recursiva y perezosa: devuelve un Stream y cada
  solución se calcula solo cuando alguien la consume.
  """

  @doc """
  Devuelve un Stream con todas las soluciones válidas.
  Orden: primero se intenta "(" y luego ")".
  """
  def generar(n, profundidad_max) do
    generar_rec("", 0, 0, n, profundidad_max)
  end

  # Caso base: cadena completa
  defp generar_rec(cadena, n, n, n, _p), do: [cadena]

  defp generar_rec(cadena, abiertos, cerrados, n, p) do
    # Stream.flat_map con una función: la rama NO se evalúa hasta que
    # el consumidor llega a ella (esto es lo que da la pereza real).
    abrir =
      Stream.flat_map([:abrir], fn _ ->
        if abiertos < n and abiertos - cerrados < p do
          generar_rec(cadena <> "(", abiertos + 1, cerrados, n, p)
        else
          []
        end
      end)

    cerrar =
      Stream.flat_map([:cerrar], fn _ ->
        if cerrados < abiertos do
          generar_rec(cadena <> ")", abiertos, cerrados + 1, n, p)
        else
          []
        end
      end)

    Stream.concat(abrir, cerrar)
  end

  @doc """
  Cuenta las soluciones sin almacenarlas.
  """
  def contar(n, p) do
    n
    |> generar(p)
    |> Enum.count()
  end
end
