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
      archive_last: [
        type: {:wrap_list, :atom},
        required: false,
        default: [],
        doc: """
        Relationships to archive after all others, in the given order.

        `archive_related` is sorted alphabetically and these are then moved to the
        end, keeping the order given here. Since the tail can name every relationship
        that participates in a constraint, this one option expresses any order the
        cascade needs.

        The constraint is almost always "these go last": a used resource is used by
        many of its siblings, so stating the position directly beats one pair per
        couple, which goes stale whenever a sibling is added.
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
    verifiers: [
      AshCascadeArchival.Verifier,
      AshCascadeArchival.Verifier.ArchivalDestinations,
      AshCascadeArchival.Verifier.UseOrder
    ]
end
