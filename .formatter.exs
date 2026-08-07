spark_locals_without_parens = [archive_last: 1, except: 1, hard_delete: 1, only: 1]

[
  import_deps: [:spark, :reactor, :ash],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  plugins: [Spark.Formatter],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
