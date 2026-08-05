defmodule AshCascadeArchival.Resource do
  @cascade_archive %Spark.Dsl.Section{
    name: :cascade_archive,
    describe: """
    Sets `archive_related` from `ash_archival` for all `has_many`, `has_one`, and `many_to_many` relationships.
    """,
    examples: [
      """
      cascade_archive do
        except [:emails]
      end
      """,
      """
      cascade_archive do
        only [:comments]
      end
      """
    ],
    schema: [
      except: [
        type: {:wrap_list, :atom},
        required: false,
        default: [],
        doc: "List of relationships to exclude from archival."
      ],
      only: [
        type: {:wrap_list, :atom},
        required: false,
        doc: "List of relationships to include in archival. Cannot be used with except."
      ],
      order: [
        type: {:list, {:tuple, [:atom, :atom]}},
        required: false,
        default: [],
        doc: """
        Partial-order constraints as {earlier, later} pairs. archive_related is sorted
        alphabetically, then these pairs are applied via a stable topological sort, so
        the cascade order is fully deterministic.
        """
      ],
      hard_delete: [
        type: {:wrap_list, :atom},
        required: false,
        default: [],
        doc: """
        Relationships whose destinations are intentionally hard-deleted by the cascade.
        Destinations here must not be archival (their primary destroy action really
        deletes) and must have a primary destroy action. Without this opt-in, a
        non-archival destination in archive_related is a compile error.
        """
      ]
    ],
    entities: []
  }

  use Spark.Dsl.Extension,
    sections: [@cascade_archive],
    add_extensions: [AshArchival.Resource],
    transformers: [AshCascadeArchival.Transformer],
    verifiers: [AshCascadeArchival.Verifier, AshCascadeArchival.Verifier.ArchivalDestinations]
end
