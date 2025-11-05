defmodule AshCascadeArchival do
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
      """
    ],
    schema: [
      except: [
        type: {:wrap_list, :atom},
        required: false,
        default: [],
        doc: "List of relationships to exclude from archival."
      ]
    ],
    entities: []
  }

  use Spark.Dsl.Extension,
    sections: [@cascade_archive],
    add_extensions: [AshArchival.Resource],
    transformers: [AshCascadeArchival.Transformer]
end
