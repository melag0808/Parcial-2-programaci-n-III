defmodule Validador do
  @moduledoc """
  Realiza la validación previa del problema 2 utilizando recursividad propia.

  Las funciones de validación no utilizan Enum ni Stream. Se verifican:

  * formato de los registros;
  * IDs duplicados;
  * duración positiva;
  * plazo no negativo;
  * IDs que contengan `|`;
  * dependencias repetidas;
  * dependencias desconocidas;
  * dependencias de una tarea consigo misma;
  * ciclos distintos en el grafo de dependencias.

  - autor: David Cuellar Vélez.
  - fecha: Noviembre del 2026
  - licencia: GNU GPL v3
  """

  @doc """
  Valida todos los registros y escribe `validacion_tareas.txt`.

  Si no encuentra errores retorna `{:ok, tareas}`, donde `tareas` es una lista
  de structs `%Tarea{}`. Si encuentra problemas retorna `{:error, errores}`.
  """
  def validar(registros, archivo_salida \\ "validacion_tareas.txt") do
    ids = obtener_ids(registros, []) |> invertir([])

    errores =
      []
      |> validar_registros(registros, ids)
      |> validar_ids_duplicados(registros, [])
      |> agregar_errores_ciclos(registros)
      |> invertir([])

    escribir_reporte(archivo_salida, errores)

    case errores do
      [] -> {:ok, construir_tareas(registros, []) |> invertir([])}
      _ -> {:error, errores}
    end
  end


  defp validar_registros(errores, [], _ids), do: errores

  defp validar_registros(errores, [registro | resto], ids) do
    nuevos_errores = validar_registro(registro, ids, errores)
    validar_registros(nuevos_errores, resto, ids)
  end

  defp validar_registro(%{error_formato: true, linea: linea, contenido: contenido}, _ids, errores) do
    [
      "Línea #{linea}: formato inválido. Se esperaban 4 campos id;duracion;plazo;dependencias. Contenido: #{contenido}"
      | errores
    ]
  end

  defp validar_registro(registro, ids, errores) do
    errores
    |> validar_id(registro)
    |> validar_duracion(registro)
    |> validar_plazo(registro)
    |> validar_dependencias_repetidas(registro)
    |> validar_dependencias_desconocidas(registro, ids)
    |> validar_autodependencia(registro)
  end

  defp validar_id(errores, %{id: id, linea: linea}) do
    if String.contains?(id, "|") do
      ["Línea #{linea}: el ID '#{id}' no puede contener |." | errores]
    else
      errores
    end
  end

  defp validar_duracion(errores, %{duracion: texto, linea: linea, id: id}) do
    case Integer.parse(texto) do
      {valor, ""} when valor > 0 -> errores
      _ -> ["Línea #{linea}: la duración de '#{id}' debe ser un entero positivo." | errores]
    end
  end

  defp validar_plazo(errores, %{plazo: texto, linea: linea, id: id}) do
    case Integer.parse(texto) do
      {valor, ""} when valor >= 0 -> errores
      _ -> ["Línea #{linea}: el plazo de '#{id}' debe ser un entero no negativo." | errores]
    end
  end

  defp validar_dependencias_repetidas(errores, %{dependencias: dependencias, linea: linea, id: id}) do
    repetidas = buscar_repetidas(dependencias, [], []) |> invertir([])
    agregar_repetidas(repetidas, linea, id, errores)
  end

  defp validar_dependencias_desconocidas(errores, %{dependencias: dependencias, linea: linea, id: id}, ids) do
    agregar_desconocidas(dependencias, ids, linea, id, errores)
  end

  defp validar_autodependencia(errores, %{dependencias: dependencias, linea: linea, id: id}) do
    if miembro?(id, dependencias) do
      ["Línea #{linea}: la tarea '#{id}' no puede depender de sí misma." | errores]
    else
      errores
    end
  end

  defp validar_ids_duplicados(errores, [], _vistos), do: errores

  defp validar_ids_duplicados(errores, [%{error_formato: true} | resto], vistos) do
    validar_ids_duplicados(errores, resto, vistos)
  end

  defp validar_ids_duplicados(errores, [%{id: id, linea: linea} | resto], vistos) do
    if miembro?(id, vistos) do
      validar_ids_duplicados(
        ["Línea #{linea}: ID duplicado '#{id}'." | errores],
        resto,
        vistos
      )
    else
      validar_ids_duplicados(errores, resto, [id | vistos])
    end
  end


  defp buscar_repetidas([], _vistos, repetidas), do: repetidas

  defp buscar_repetidas([dep | resto], vistos, repetidas) do
    cond do
      miembro?(dep, vistos) and not miembro?(dep, repetidas) ->
        buscar_repetidas(resto, vistos, [dep | repetidas])

      true ->
        buscar_repetidas(resto, [dep | vistos], repetidas)
    end
  end

  defp agregar_repetidas([], _linea, _id, errores), do: errores

  defp agregar_repetidas([dep | resto], linea, id, errores) do
    agregar_repetidas(
      resto,
      linea,
      id,
      ["Línea #{linea}: la dependencia '#{dep}' está repetida en la tarea '#{id}'." | errores]
    )
  end

  defp agregar_desconocidas([], _ids, _linea, _id, errores), do: errores

  defp agregar_desconocidas([dep | resto], ids, linea, id, errores) do
    nuevos_errores =
      if miembro?(dep, ids) do
        errores
      else
        ["Línea #{linea}: la tarea '#{id}' depende de '#{dep}', que no existe." | errores]
      end

    agregar_desconocidas(resto, ids, linea, id, nuevos_errores)
  end

  defp agregar_errores_ciclos(errores, registros) do
    ids = obtener_ids(registros, []) |> invertir([])
    ciclos = buscar_ciclos_ids(ids, registros, [])
    agregar_ciclos_a_errores(ciclos, errores)
  end

  defp buscar_ciclos_ids([], _registros, ciclos), do: ciclos

  defp buscar_ciclos_ids([id | resto], registros, ciclos) do
    ciclos_actualizados = explorar_ciclo(id, registros, [], ciclos)
    buscar_ciclos_ids(resto, registros, ciclos_actualizados)
  end

  defp explorar_ciclo(id, registros, camino, ciclos) do
    if miembro?(id, camino) do
      ciclo = extraer_ciclo(camino, id)
      canonico = normalizar_ciclo(ciclo)

      if miembro_lista?(canonico, ciclos) do
        ciclos
      else
        [canonico | ciclos]
      end
    else
      dependencias = dependencias_de(id, registros)
      explorar_dependencias(dependencias, registros, camino ++ [id], ciclos)
    end
  end

  defp explorar_dependencias([], _registros, _camino, ciclos), do: ciclos

  defp explorar_dependencias([dep | resto], registros, camino, ciclos) do
    ciclos_actualizados =
      if existe_id?(dep, registros) do
        explorar_ciclo(dep, registros, camino, ciclos)
      else
        ciclos
      end

    explorar_dependencias(resto, registros, camino, ciclos_actualizados)
  end

  defp extraer_ciclo([id | resto], id), do: [id | resto]
  defp extraer_ciclo([_ | resto], id), do: extraer_ciclo(resto, id)
  defp extraer_ciclo([], _id), do: []

  defp normalizar_ciclo([]), do: []

  defp normalizar_ciclo(ciclo) do
    menor = minimo_texto(ciclo)
    rotado = rotar_hasta(ciclo, menor, [])
    rotado ++ [hd(rotado)]
  end

  defp minimo_texto([primero | resto]), do: minimo_texto(resto, primero)
  defp minimo_texto([], menor), do: menor

  defp minimo_texto([actual | resto], menor) do
    nuevo_menor = if actual < menor, do: actual, else: menor
    minimo_texto(resto, nuevo_menor)
  end

  defp rotar_hasta([menor | resto], menor, acumulado) do
    [menor | resto] ++ invertir(acumulado, [])
  end

  defp rotar_hasta([actual | resto], menor, acumulado) do
    rotar_hasta(resto, menor, [actual | acumulado])
  end

  defp agregar_ciclos_a_errores([], errores), do: errores

  defp agregar_ciclos_a_errores([ciclo | resto], errores) do
    texto = unir_ciclo(ciclo)
    agregar_ciclos_a_errores(resto, ["Ciclo detectado: #{texto}." | errores])
  end

  defp unir_ciclo([ultimo]), do: ultimo
  defp unir_ciclo([primero | resto]), do: primero <> " -> " <> unir_ciclo(resto)
  defp unir_ciclo([]), do: ""

  defp construir_tareas([], acumulador), do: acumulador

  defp construir_tareas([%{error_formato: true} | resto], acumulador) do
    construir_tareas(resto, acumulador)
  end

  defp construir_tareas([registro | resto], acumulador) do
    tarea = %Tarea{
      id: registro.id,
      duracion: String.to_integer(registro.duracion),
      plazo: String.to_integer(registro.plazo),
      dependencias: registro.dependencias
    }

    construir_tareas(resto, [tarea | acumulador])
  end

  defp escribir_reporte(archivo, []) do
    File.write!(archivo, "Validación correcta: no se encontraron errores.\n")
  end

  defp escribir_reporte(archivo, errores) do
    File.write!(archivo, "ERRORES DE VALIDACIÓN DE TAREAS\n")
    escribir_errores(archivo, errores)
  end

  defp escribir_errores(_archivo, []), do: :ok

  defp escribir_errores(archivo, [error | resto]) do
    File.write!(archivo, "- #{error}\n", [:append])
    escribir_errores(archivo, resto)
  end


  defp obtener_ids([], acumulador), do: acumulador

  defp obtener_ids([%{error_formato: true} | resto], acumulador) do
    obtener_ids(resto, acumulador)
  end

  defp obtener_ids([%{id: id} | resto], acumulador) do
    obtener_ids(resto, [id | acumulador])
  end

  defp dependencias_de(_id, []), do: []

  defp dependencias_de(id, [%{error_formato: true} | resto]) do
    dependencias_de(id, resto)
  end

  defp dependencias_de(id, [%{id: id, dependencias: dependencias} | _]), do: dependencias
  defp dependencias_de(id, [_ | resto]), do: dependencias_de(id, resto)

  defp existe_id?(_id, []), do: false
  defp existe_id?(id, [%{error_formato: true} | resto]), do: existe_id?(id, resto)
  defp existe_id?(id, [%{id: id} | _]), do: true
  defp existe_id?(id, [_ | resto]), do: existe_id?(id, resto)

  defp miembro?(_elemento, []), do: false
  defp miembro?(elemento, [elemento | _]), do: true
  defp miembro?(elemento, [_ | resto]), do: miembro?(elemento, resto)

  defp miembro_lista?(_lista, []), do: false
  defp miembro_lista?(lista, [lista | _]), do: true
  defp miembro_lista?(lista, [_ | resto]), do: miembro_lista?(lista, resto)

  defp invertir([], acumulador), do: acumulador
  defp invertir([elemento | resto], acumulador), do: invertir(resto, [elemento | acumulador])
end
