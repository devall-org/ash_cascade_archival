defmodule AshCascadeArchival.Helpers do
  @moduledoc false

  alias Ash.Resource.Relationships.{HasOne, HasMany}

  @doc """
  Returns true if the child relationship is fully-contained (child is completely owned by parent).
  Only applies to has_one and has_many relationships.
  many_to_many is excluded because archive_related would target the destination, not the through resource.
  Relationships marked as `used_by` (see `ash_ownership`) are excluded: they point at
  users of this resource, not contained children, and archiving them would drag
  the users down with the used resource.

  Relationships marked with `__cascade_skip__` are excluded too. Extensions that
  generate several relationships over the same rows use it to nominate one of them
  as the cascade path, so the parent does not walk the same children repeatedly.
  """
  def fully_contained_child?(rel) do
    case rel do
      %HasOne{no_attributes?: false, manual: nil, filters: []} -> contained?(rel)
      %HasMany{no_attributes?: false, manual: nil, filters: []} -> contained?(rel)
      _ -> false
    end
  end

  defp contained?(rel), do: not used_by?(rel) and not cascade_skip?(rel)

  defp used_by?(rel), do: Map.get(rel, :__used_by__, false) == true

  @doc """
  Returns true if the relationship opted out of being a cascade path.
  """
  def cascade_skip?(rel), do: Map.get(rel, :__cascade_skip__, false) == true

  @doc """
  Returns true if the relationship is a `uses` edge (see `ash_borrow`):
  a non-owning belongs_to that must not be treated as a containment chain.
  """
  def uses?(rel), do: Map.get(rel, :__uses__, false) == true

  @doc """
  Returns true if the relationship was declared with `ancestor` (see ash_ownership).
  """
  def ancestor?(rel), do: Map.get(rel, :__ancestor__, false) == true

  @doc """
  Returns true if the child relationship points to the given module.
  Only applies to has_one and has_many relationships.
  """
  def child_relationship_to_module?(rel, module) do
    case rel do
      %HasOne{destination: ^module} -> true
      %HasMany{destination: ^module} -> true
      _ -> false
    end
  end
end
