# AshCascadeArchival

Automatically sets `archive_related` from `ash_archival` for all fully-contained child relationships (`has_many` and `has_one`).

## Installation

Add `ash_cascade_archival` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_cascade_archival, "~> 0.6.0"}
  ]
end
```

## Usage

Simply add `AshCascadeArchival` to your resource's extensions:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

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

**Note**: `many_to_many` relationships are excluded because `archive_related` would target the destination resource, not the through resource. Instead, define a `has_many` relationship to the through resource (e.g., `has_many :post_tags, PostTag`) to archive it.

### Excluding Relationships

Use the `except` option to exclude specific relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

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

### Including Only Specific Relationships

Use the `only` option to include a specific set of relationships:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    extensions: [AshCascadeArchival.Resource]

  cascade_archive do
    only [:comments]
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
  archive_related [:comments]  # post_tags not included
end
```

`only` and `except` cannot be used together.
When neither option is set, all fully-contained child relationships are archived.
Use `only []` to archive no relationships.

### Deterministic Cascade Order

`archive_related` is executed sequentially, so its order is the cascade
execution order. Since 0.6.0 the list is sorted **alphabetically** by default
(instead of following declaration order), so reordering relationships in the
source file can never silently change cascade behavior.

When the order matters — e.g. an [ash_ownership](https://hex.pm/packages/ash_ownership)
`used_by` destination must be archived *after* everything that uses it — pin the
tail with `archive_last`:

```elixir
cascade_archive do
  archive_last [:post_tags, :comments]  # ...everything else..., post_tags, comments
end
```

Only the tail needs stating. Independent children can be archived at any point,
so the constraint is always "these go last, in this order" — never "this goes
first". Named relationships are removed from the alphabetical base and appended
in the order given, which is enough to express any order the cascade needs.

`AshCascadeArchival.Verifier.UseOrder` checks the result against the actual
`used_by` edges and, when it fails, reports a ready-to-paste `archive_last`.

### Archival Destinations

Cascading invokes each `archive_related` destination's **primary destroy
action**, so that action decides what really happens: a soft destroy runs as
an update (archiving when its changes set the archive attribute, as
ash_archival's do), a non-soft destroy **hard-deletes**, and a missing
destroy crashes at runtime. Since 0.6.0 the verifier classifies by that
actual action (not by extension presence, which `exclude_destroy_actions`
and custom soft destroys can contradict): a destination without a primary
destroy action, with a non-soft one, or with a no-op soft one (no changes
and no manual implementation) is rejected — make its destroys actually
archive, exclude the relationship with `except`, or opt into hard deletion
explicitly with `hard_delete`. The no-op check is a heuristic: any change or
manual implementation counts as evidence of archiving; the verifier cannot
prove your custom soft destroy really archives.

> **Note**: Spark surfaces verifier errors as compiler *warnings* — the
> module still compiles. Treat warnings as errors in CI
> (`mix compile --warnings-as-errors`) to make these checks enforcing.

### Intentional Hard Deletes

Some children are worthless without their parent and need no soft-delete
history (derived caches, computation results). Declare that the cascade
really deletes them:

```elixir
cascade_archive do
  hard_delete [:derived_caches]
end
```

`hard_delete` destinations must have a non-soft primary destroy action: a
soft one would archive (making the declaration misleading), and a missing
one would crash the cascade at runtime — both are verified at compile time.

Relationships marked by [ash_borrow](https://hex.pm/packages/ash_borrow)
are recognized on both sides: `used_by` is never included in
`archive_related` (it points at users, not contained children), and a
`uses` edge is exempt from the reverse-relationship requirement (it is a
non-owning reference, not a containment chain).

### Validation

`AshCascadeArchival` verifies that parent resources with `AshArchival` have proper reverse relationships. If a child has a `belongs_to` to an archival parent, the parent must have a corresponding fully-contained relationship back to the child.

**Example error:**

```
AshArchival requires has_many or has_one to pair with belongs_to.
Parent MyApp.Author must have one of the following:

has_many :posts, MyApp.Post
has_one :post, MyApp.Post
```

## How It Works

1. **Transformer**: Finds all fully-contained child relationships, sets `archive_related`, and orders it (alphabetical base + `archive_last` tail)
2. **Verifiers**: Ensure bidirectional relationships are properly configured for archival, and that every `archive_related` destination is itself archival

## Breaking changes in 0.6.0

- `archive_related` is now sorted alphabetically instead of following
  relationship declaration order. If your code depended on the previous
  implicit order, declare it explicitly with the `archive_last` option.
- A relationship in `archive_related` whose destination has no primary
  destroy action, or a non-soft one, is now a compile error (previously the
  cascade silently hard-deleted or crashed on such destinations). Make the
  destination's destroys soft, use `except`, or declare the intent with
  `hard_delete`.

## Configuration

### Logging

By default, `AshCascadeArchival` logs the configured `archive_related` relationships during compilation. You can disable this in your config:

```elixir
# config/config.exs
config :ash_cascade_archival, :log, false
```

Default: `true` (logging enabled)

## Conflict with Manual Configuration

You cannot use both `cascade_archive` and manually set `archive_related`. If you need to include or exclude specific relationships, use the `only` or `except` option in `cascade_archive`:

```elixir
cascade_archive do
  only [:relationship_name]
end
```

```elixir
cascade_archive do
  except [:relationship_name]
end
```

## License

MIT
