defmodule AshCascadeArchival.Verifier do
  use Spark.Dsl.Verifier

  require Logger
  alias Spark.Dsl.Verifier
  alias Ash.Resource.Relationships.{BelongsTo, ManyToMany, HasOne, HasMany}

  @impl true
  def verify(dsl_state) do
    current = dsl_state |> Verifier.get_persisted(:module)
    # Ash.Resource.Info.multitenancy_attribute(dsl_state)
    multitenant_attr = dsl_state |> Verifier.get_option([:multitenancy], :attribute)

    belongs_toes =
      dsl_state
      |> Verifier.get_entities([:relationships])
      |> Enum.filter(fn
        %BelongsTo{source_attribute: source_attribute} ->
          source_attribute != multitenant_attr

        %{} ->
          false
      end)

    belongs_toes
    |> Enum.each(fn %BelongsTo{destination: destination} ->
      perant_dsl = destination.spark_dsl_config()

      perant_dsl
      |> Verifier.get_entities([:relationships])
      |> Enum.any?(fn rel ->
        case rel do
          %HasOne{destination: ^current} -> true
          %HasMany{destination: ^current} -> true
          %ManyToMany{through: ^current} -> true
          _ -> false
        end
      end)
      |> unless do
        parent_resource = destination |> printable()
        parent = parent_resource |> Macro.underscore()

        child_resource = current |> printable()
        child = child_resource |> Macro.underscore()
        children = "#{child}s"

        Logger.warning("""

        AshArchival이 제대로 동작하기 위해서는 belongs_to <-> has_many, has_one, many_to_many 쌍이 맞아야 합니다.
        #{parent}.ex에 아래 중 한줄을 추가하세요.

        has_many :#{children}, R.#{child_resource}
        has_one :#{child}, R.#{child_resource}
        many_to_many :<things>, <R.Thing>, through: R.#{child_resource}
        """)
      end
    end)

    :ok
  end

  defp printable(module) do
    module |> Module.split() |> List.last()
  end
end
