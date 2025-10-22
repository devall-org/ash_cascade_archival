# Rules for working with AshCascadeArchival

## Purpose

AshCascadeArchival automatically sets `archive_related` from `ash_archival` for all `has_many`, `has_one`, and `many_to_many` relationships. When a resource is archived, related records are also archived.

## Usage

Add the extension to your resource:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCascadeArchival]

  relationships do
    has_many :comments, Comment
    has_many :post_tags, PostTag
    many_to_many :tags, Tag, through: PostTag
  end
end
```

This automatically sets `archive_related [:comments, :post_tags]`.

## Simple Child Relationships

AshCascadeArchival only processes "simple child" relationships:

**has_many conditions:**
- `no_attributes?: false` (default)
- `manual: nil` (default)
- `filters: []` (no filters)

**has_one conditions:**
- `no_attributes?: false` (default)
- `manual: nil` (default)
- `from_many?: false` (default)

**many_to_many:**
- The through resource is automatically handled as a simple has_many

## Excluding Relationships

Use the `except` option to exclude specific relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival]

  cascade_archive do
    except [:audit_logs]
  end

  relationships do
    has_many :comments, Comment
    has_many :audit_logs, AuditLog  # This won't be archived
  end
end
```

## Complex Relationships

Filtered has_many or from_many? has_one relationships are not automatically processed. In these cases:

1. Define a separate simple child relationship, or
2. Manually set `archive_related` in `ash_archival`

```elixir
relationships do
  # Complex relationship - not automatically processed
  has_many :published_posts, Post do
    filter expr(status == :published)
  end

  # Simple relationship - this will be automatically processed
  has_many :posts, Post
end
```

## Manual Override

If `archive_related` is already manually set, AshCascadeArchival does nothing:

```elixir
archive do
  archive_related [:custom_list]  # Already set, will be ignored
end
```

