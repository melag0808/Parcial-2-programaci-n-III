defmodule GeneradorParentesis do
  @moduledoc """
  Genera cadenas de paréntesis balanceados
  respetando una profundidad máxima.
  """

  @doc """
  Devuelve un Stream con todas las soluciones válidas.
  """
  def generar(n, profundidad_max) do
    generar_rec("", 0, 0, n, profundidad_max)
    |> Stream.map(& &1)
  end

  defp generar_rec(cadena, abiertos, cerrados, n, _p)
       when abiertos == n and cerrados == n do
    [cadena]
  end

  defp generar_rec(cadena, abiertos, cerrados, n, p) do
    agregar_abierto =
      if abiertos < n and abiertos - cerrados < p do
        generar_rec(
          cadena <> "(",
          abiertos + 1,
          cerrados,
          n,
          p
        )
      else
        []
      end

    agregar_cerrado =
      if cerrados < abiertos do
        generar_rec(
          cadena <> ")",
          abiertos,
          cerrados + 1,
          n,
          p
        )
      else
        []
      end

    agregar_abierto ++ agregar_cerrado
  end

  @doc """
  Cuenta las soluciones sin almacenarlas.
  """
  def contar(n, p) do
    generar(n, p)
    |> Enum.count()
  end
end
