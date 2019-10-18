# AssertEventually

Very simple test helper for Elixir's ExUnit framework that allows to use standard ExUnit assertions along with expressions that may
fail several times until they **eventually** succeed.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_assert_eventually` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_assert_eventually, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_assert_eventually](https://hexdocs.pm/ex_assert_eventually).

