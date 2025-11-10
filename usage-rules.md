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
- Use `cascade_archive` with `except` option for automatic configuration
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

1. **Transformer**: Scans all relationships, finds fully-contained children, and sets `archive_related`
2. **Verifier**: Validates bidirectional relationships for archival consistency

## Best Practices

- Use `cascade_archive` for most resources with standard relationships
- Use `except` to exclude specific relationships (e.g., audit logs, complex filtered relationships)
- Define separate simple relationships for archival when you have complex filtered relationships
