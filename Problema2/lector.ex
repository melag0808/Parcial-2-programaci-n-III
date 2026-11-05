defmodule Lector do
  @moduledoc """
  Modulo que lee el archivo de tareas utilizando File.stream!/1 y transformaciones
  perezosas. Conserva el número de línea física para que el validador
  pueda informar la ubicación de los errores.

  - autor: David Cuellar Vélez.
  - fecha: Noviembre del 2026
  - licencia: GNU GPL v3
  """

  @doc """
  Lee `tareas.csv` o la ruta indicada.

  Ignora líneas vacías y comentarios cuyo primer carácter no blanco sea `#`.
  Retorna `{:ok, registros}` o `{:error, {:archivo_no_encontrado, ruta}}`.

  Los registros con cuatro campos se conservan como mapas con sus valores
  todavía en texto, para que `Validador` haga las verificaciones recursivas.
  """
  def leer_tareas(ruta \\ "tareas.csv") do
    if File.exists?(ruta) do
      registros =
        ruta
        |> File.stream!()
        |> Stream.with_index(1)
        |> Stream.map(fn {linea, numero_linea} ->
          {String.trim(linea), numero_linea}
        end)
        |> Stream.reject(fn {linea, _numero_linea} ->
          linea == "" or String.starts_with?(linea, "#")
        end)
        |> Stream.map(&convertir_linea/1)
        |> Enum.to_list()

      {:ok, registros}
    else
      {:error, {:archivo_no_encontrado, ruta}}
    end
  end

  defp convertir_linea({texto, numero_linea}) do
    case String.split(texto, ";") do
      [id, duracion, plazo, dependencias] ->
        %{
          linea: numero_linea,
          id: String.trim(id),
          duracion: String.trim(duracion),
          plazo: String.trim(plazo),
          dependencias: convertir_dependencias(String.trim(dependencias))
        }

      _ ->
        %{
          linea: numero_linea,
          error_formato: true,
          contenido: texto
        }
    end
  end

  defp convertir_dependencias("-"), do: []

  defp convertir_dependencias(texto) do
    texto
    |> String.split("|")
    |> Enum.map(&String.trim/1)
  end
end
