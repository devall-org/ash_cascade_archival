# AshCascadeArchival

Automatically sets `archive_related` from `ash_archival` for all `has_many`, `has_one`, and `many_to_many` relationships.

## Installation

Add `ash_cascade_archival` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_cascade_archival, "~> 0.2.0"}
  ]
end
```

## Usage

```elixir
defmodule Post do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Postgres,
    extensions: [AshCascadeArchival]

  attributes do
    uuid_primary_key :id
    attribute :title, :string
  end

  relationships do
    belongs_to :author, Author

    has_many :comments, Comment
    has_many :post_tags, PostTag

    many_to_many :tags, Tag, through: PostTag
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

For the example above, `archive_related` of `ash_archival` is automatically set as follows.

```elixir
archive do
  archive_related [:comments, :post_tags]
end
```

## License

MIT