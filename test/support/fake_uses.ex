defmodule AshCascadeArchival.Test.Support.FakeUses do
  @moduledoc false
  # Minimal stand-in for ash_ownership's `uses` entity: compiles to a
  # BelongsTo carrying the `:__uses__` marker, so the integration between
  # the marker and this library's verifiers can be tested without a
  # dependency on ash_ownership.

  @fake_used_by %Spark.Dsl.Entity{
    name: :fake_used_by,
    describe: "Test-only `used_by` stand-in.",
    no_depend_modules: [:destination],
    target: Ash.Resource.Relationships.HasMany,
    schema: Ash.Resource.Relationships.HasMany.opt_schema(),
    transform: {__MODULE__, :transform_used_by, []},
    args: [:name, :destination]
  }

  @fake_uses %Spark.Dsl.Entity{
    name: :fake_uses,
    describe: "Test-only `uses` stand-in.",
    no_depend_modules: [:destination],
    target: Ash.Resource.Relationships.BelongsTo,
    schema: Ash.Resource.Relationships.BelongsTo.opt_schema(),
    transform: {__MODULE__, :transform, []},
    args: [:name, :destination]
  }

  use Spark.Dsl.Extension,
    dsl_patches: [
      %Spark.Dsl.Patch.AddEntity{section_path: [:relationships], entity: @fake_uses},
      %Spark.Dsl.Patch.AddEntity{section_path: [:relationships], entity: @fake_used_by}
    ]

  @doc false
  def transform(belongs_to) do
    with {:ok, belongs_to} <- Ash.Resource.Relationships.BelongsTo.transform(belongs_to) do
      {:ok, Map.put(belongs_to, :__uses__, true)}
    end
  end

  @doc false
  def transform_used_by(has_many) do
    with {:ok, has_many} <- Ash.Resource.Relationships.HasMany.transform(has_many) do
      {:ok, Map.put(has_many, :__used_by__, true)}
    end
  end
end
