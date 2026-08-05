defmodule AshCascadeArchival.Test.Support.FakeBorrow do
  @moduledoc false
  # Minimal stand-in for ash_borrow's `borrows` entity: compiles to a
  # BelongsTo carrying the `:__borrows__` marker, so the integration between
  # the marker and this library's verifiers can be tested without a
  # dependency on ash_borrow.

  @fake_borrows %Spark.Dsl.Entity{
    name: :fake_borrows,
    describe: "Test-only borrows stand-in.",
    no_depend_modules: [:destination],
    target: Ash.Resource.Relationships.BelongsTo,
    schema: Ash.Resource.Relationships.BelongsTo.opt_schema(),
    transform: {__MODULE__, :transform, []},
    args: [:name, :destination]
  }

  use Spark.Dsl.Extension,
    dsl_patches: [
      %Spark.Dsl.Patch.AddEntity{section_path: [:relationships], entity: @fake_borrows}
    ]

  @doc false
  def transform(belongs_to) do
    with {:ok, belongs_to} <- Ash.Resource.Relationships.BelongsTo.transform(belongs_to) do
      {:ok, Map.put(belongs_to, :__borrows__, true)}
    end
  end
end
