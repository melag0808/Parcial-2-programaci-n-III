defmodule Tarea do
  @moduledoc """
  Representa una tarea del proyecto.

  - autor: David Cuellar Vélez.
  - fecha: Noviembre del 2026
  - licencia: GNU GPL v3.
  """

  defstruct id: "", duracion: 0, plazo: 0, dependencias: []
end


defmodule Plan do
  @moduledoc """
  Representa un plan válido de ejecución de tareas.

  Guarda el orden de ejecución, los tiempos de finalización de cada tarea
  y la penalización total del plan.
  """

  defstruct orden: [], finalizaciones: %{}, penalizacion: 0
end
