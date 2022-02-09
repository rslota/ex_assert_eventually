# AssertEventually
[![CircleCI](https://circleci.com/gh/rslota/ex_assert_eventually.svg?style=svg)](https://circleci.com/gh/rslota/ex_assert_eventually)

Very simple test helper for Elixir's ExUnit framework that allows to use standard ExUnit assertions along with expressions that may
fail several times until they **eventually** succeed.

## Documentation

Documentation can be found on [https://hexdocs.pm/ex_assert_eventually](https://hexdocs.pm/assert_eventually).

## Installation

The package can be installed by adding `assert_eventually` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:assert_eventually, "~> 1.0.0", only: :test}
  ]
end
```

AssertEventually is usually added only to the :test environment since it's used in tests. To also import AssertEventually's formatter configuration, add the :dev environment as well as :test for `assert_eventually` and add :assert_eventually to your .formatter.exs:
```elixir
[
  import_deps: [:assert_eventually]
]
```

## Just tell me how to use it already...


Here you go (just replace `ComplexSystem` with something of yours):

```elixir
defmodule MyApp.SomeTest do
  use ExUnit.Case, async: true

  # Fail after 50ms of retrying with 5ms time between attempts
  use AssertEventually, timeout: 50, interval: 5

  test "get meaningful value by using normal assert" do
    {:ok, server_pid} = start_supervised(ComplexSystem)

    eventually assert {:ok, value} = ComplexSystem.get_value(server_pid)
    assert value == 42
  end

  test "get meaningful value by using assert_in_delta" do
    {:ok, server_pid} = start_supervised(ComplexSystem)

    eventually assert_in_delta 42, elem(ComplexSystem.get_value(server_pid), 1), 0
  end
end
```

For more details please consult the [documentation](https://hexdocs.pm/assert_eventually).
