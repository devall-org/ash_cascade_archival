# Rules for working with AshCascadeArchival

## Purpose

AshCascadeArchival automatically sets `archive_related` from `ash_archival` for all fully-contained child relationships (`has_many` and `has_one`). When a resource is archived, related records are also archived.

## Usage

Add the extension to your resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCascadeArchival.Resource]

  relationships do
    has_many :comments, Comment
    has_many :post_tags, PostTag
    many_to_many :tags, Tag, through: PostTag
  end
end
```

This automatically sets `archive_related [:comments, :post_tags]`.

## Fully-Contained Child Relationships

AshCascadeArchival only processes "fully-contained" child relationships:

**has_many conditions:**
- `no_attributes?: false` (default)
- `manual: nil` (default)
- `filters: []` (no filters)

**has_one conditions:**
- `no_attributes?: false` (default)
- `manual: nil` (default)
- `filters: []` (no filters)

**many_to_many is excluded:**
- `archive_related` would target the destination resource, not the through resource
- Instead, define a `has_many` relationship to the through resource to archive it

## Excluding Relationships

Use the `except` option to exclude specific relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

  cascade_archive do
    except [:audit_logs]
  end

  relationships do
    has_many :comments, Comment
    has_many :audit_logs, AuditLog  # This won't be archived
  end
end
```

## Including Only Specific Relationships

Use the `only` option to include a specific set of relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

  cascade_archive do
    only [:comments]
  end

  relationships do
    has_many :comments, Comment
    has_many :audit_logs, AuditLog  # This won't be archived
  end
end
```

You cannot use `only` and `except` together.
When neither option is set, all fully-contained child relationships are archived.
Use `only []` to archive no relationships.

## Cascade Order

`archive_related` executes sequentially, so its order is the cascade order.
The list is sorted alphabetically by default; declaration order is ignored.

Use the `order` option to declare partial-order constraints as
`{earlier, later}` pairs — no need to enumerate the full list:

```elixir
cascade_archive do
  order [{:post_tags, :comments}]  # archive post_tags before comments
end
```

Pairs are applied on top of the alphabetical base order via a stable
topological sort. Unknown names and cycles raise at compile time.

## Archival Destinations

Cascading calls each `archive_related` destination's primary destroy action,
so that action decides the outcome: soft destroy runs as an update (it
archives only when its changes or manual implementation set the archive
attribute), non-soft destroy hard-deletes, missing destroy crashes at
runtime. The verifier classifies by the actual primary destroy action (not
extension presence). A destination with a missing, non-soft, or no-op soft
(no changes, no manual) primary destroy is rejected; make its destroys
actually archive, exclude the relationship with `except`, or opt in with
`hard_delete`. The no-op check is a heuristic — any change counts as
evidence; the verifier cannot prove a custom change archives.

Spark surfaces verifier errors as compiler warnings, so run CI with
`mix compile --warnings-as-errors` to make all of this library's checks
enforcing.

## Intentional Hard Deletes

Use `hard_delete` for children that are worthless without their parent and
need no soft-delete history (derived caches, computation results):

```elixir
cascade_archive do
  hard_delete [:derived_caches]
end
```

Verified at compile time: `hard_delete` destinations must have a non-soft
primary destroy action (a soft one would archive, making the declaration
misleading; a missing one would crash the cascade). Names must be part of
the final archive_related. Do not use `hard_delete` for resources referenced
elsewhere via foreign keys (e.g. `ash_borrow` used resources) — the database
will reject the delete.

Relationships marked by `ash_borrow` are recognized on both sides:
`:__used_by__` has_many/has_one relationships are never treated as
fully-contained children (excluded from `archive_related` automatically),
and `:__uses__` belongs_to relationships are exempt from the
reverse-relationship validation (non-owning references form no containment
chain).

## Validation

AshCascadeArchival verifies bidirectional relationships. If a child has a `belongs_to` to an archival parent, the parent must have a corresponding fully-contained relationship back to the child.

**Example:**

```elixir
# Child resource
defmodule MyApp.Comment do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

  relationships do
    belongs_to :post, MyApp.Post  # Parent must have reverse relationship
  end
end

# Parent resource - MUST have one of these:
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshArchival.Resource]

  relationships do
    has_many :comments, MyApp.Comment  # ✓ Valid
    # OR
    has_one :comment, MyApp.Comment    # ✓ Valid
    # OR
    many_to_many :items, Item, through: MyApp.Comment  # ✓ Valid
  end
end
```

If the parent doesn't have a proper reverse relationship, you'll get a compile-time error.

## Conflict with Manual Configuration

You **cannot** use both `cascade_archive` and manually set `archive_related`. This will raise an error:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

  cascade_archive do
    # Using cascade_archive
  end

  archive do
    archive_related [:comments]  # ✗ Error: Cannot use both!
  end
end
```

**Solution:** Choose one approach:
- Use `cascade_archive` with `only` or `except` for automatic configuration
- Remove `AshCascadeArchival` extension and manually set `archive_related`

## Complex Relationships

Filtered relationships are not automatically processed:

```elixir
relationships do
  # Complex relationship - not automatically processed
  has_many :published_posts, Post do
    filter expr(status == :published)
  end

  # Simple relationship - automatically processed
  has_many :posts, Post
end
```

For complex relationships:
1. Define a separate simple child relationship for archival
2. Use `except` to exclude the complex relationship if needed

## How It Works

1. **Transformer**: Scans all relationships, finds fully-contained children, sets `archive_related`, and orders it (alphabetical base + `order` pairs)
2. **Verifiers**: Validate bidirectional relationships for archival consistency, and that every `archive_related` destination is archival

## Best Practices

- Use `cascade_archive` for most resources with standard relationships
- Use `only` to archive a specific set of relationships
- Use `except` to exclude specific relationships (e.g., audit logs, complex filtered relationships)
- Define separate simple relationships for archival when you have complex filtered relationships
