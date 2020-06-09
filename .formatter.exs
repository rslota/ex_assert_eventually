# Used by "mix format"
locals_without_parens = [
  assert_eventually: 1,
  assert_eventually: 2,
  eventually: 1,
  eventually: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
