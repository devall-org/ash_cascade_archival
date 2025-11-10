# AshCascadeArchival

Automatically sets `archive_related` from `ash_archival` for all fully-contained child relationships (`has_many`, `has_one`, and `many_to_many`).

## Installation

Add `ash_cascade_archival` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_cascade_archival, "~> 0.3.0"}
  ]
end
```

## Usage

Simply add `AshCascadeArchival` to your resource's extensions:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival]

  attributes do
    uuid_primary_key :id
    attribute :title, :string
  end

  relationships do
    belongs_to :author, MyApp.Author

    has_many :comments, MyApp.Comment
    has_many :post_tags, MyApp.PostTag

    many_to_many :tags, MyApp.Tag, through: MyApp.PostTag
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

For the example above, `archive_related` is automatically set to:

```elixir
archive do
  archive_related [:comments, :post_tags]
end
```

## Features

### Automatic Archive Configuration

`AshCascadeArchival` automatically identifies fully-contained child relationships and adds them to `archive_related`. A relationship is considered fully-contained when:

- **has_one**: `no_attributes?: false`, `manual: nil`, `filters: []`
- **has_many**: `no_attributes?: false`, `manual: nil`, `filters: []`
- **many_to_many**: `filters: []`

### Excluding Relationships

Use the `except` option to exclude specific relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival]

  cascade_archive do
    except [:post_tags]
  end

  relationships do
    has_many :comments, MyApp.Comment
    has_many :post_tags, MyApp.PostTag
  end
end
```

Result:

```elixir
archive do
  archive_related [:comments]  # post_tags excluded
end
```

### Validation

`AshCascadeArchival` verifies that parent resources with `AshArchival` have proper reverse relationships. If a child has a `belongs_to` to an archival parent, the parent must have a corresponding fully-contained relationship back to the child.

**Example error:**

```
AshArchival requires has_many, has_one, or many_to_many to pair with belongs_to.
Parent MyApp.Author must have one of the following:

has_many :posts, MyApp.Post
has_one :post, MyApp.Post
many_to_many :<relationship_name>, <RelatedResource>, through: MyApp.Post
```

## How It Works

1. **Transformer**: Finds all fully-contained child relationships and sets `archive_related`
2. **Verifier**: Ensures bidirectional relationships are properly configured for archival

## Conflict with Manual Configuration

You cannot use both `cascade_archive` and manually set `archive_related`. If you need to exclude specific relationships, use the `except` option in `cascade_archive`:

```elixir
cascade_archive do
  except [:relationship_name]
end
```

## License

MIT
