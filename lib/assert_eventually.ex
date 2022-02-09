defmodule AssertEventually do
  @moduledoc """
  `AssertEventually` allows to use standard ExUnit assertions along with expressions that may
  fail several times until they **eventually** succeed.

  In order to use macros from this module, you first need to `use AssertEventually` in you test case.
  On-use, you can provide two options:
   * `timeout` - default time after which your assertions will stop ignoring errors (can be set individually for each assert)
   * `interval` - time before retring your expression after previous one fails

  All provided times are milliseconds.

   Examples:

   ```
   defmodule MyApp.SomeTest do
     use ExUnit.Case, async: true

     # Fail after 50ms of retrying with time between attempts 5ms
     use AssertEventually, timeout: 50, interval: 5

     test "my test with" do
       assert_eventually {:ok, %{some: value}} = {:ok, %{some: :real_value, other: :value}}
     end
   end
  """

  defmacro __using__(opts) do
    quote do
      import ExUnit.Assertions
      import unquote(__MODULE__)

      Module.put_attribute(
        __MODULE__,
        :assert_eventually_timeout,
        unquote(opts)[:timeout] || :timer.seconds(1)
      )

      Module.put_attribute(
        __MODULE__,
        :assert_eventually_interval,
        unquote(opts)[:interval] || 20
      )
    end
  end

  @doc """
  This macro should be used with other ExUnit macros to allow the original
  `assert_expr` to fail for a given period of time (`timeout`).

  First argument should always be a ExUnit `assert`-like macro call with all its arguments,
  while second argument is optional timeout (default 1000ms). For more details on default `timeout`
  value and other available options, please refer to module docs.

  ## Usage use-case / example:
  Let's say, you have complex system that can be started with `start_supervised(ComplexSystem)`.
  `ComplexSystem` has some things to take care of before it's fully operational and can actually return
  something meaningful with `ComplexSystem.get_value()`. `eventually/2` allows to verify the return value
  when you don't really care how much time exactly it took the `ComplexSystem` to start as long this time is
  "resonable". To implement such test, you can do the following:

  ```
  test "get meaningful value" do
    {:ok, _pid} = start_supervised(ComplexSystem)

    eventually assert {:ok, value} = ComplexSystem.get_value()
    assert value == 42
  end
  ```

  The code above will try running the given expression (match in this case) for some time (1000ms here - default).
  If it's successful within the given time, the behaviour will be the same as normal `assert` macro. If the expression will
  fail for at least the time given as `timeout`, the behaviour will also be the same as normal `assert` macro.

  This macro can be used with any ExUnit `assert`-like macro:

  ```
  test "get meaningful value" do
    {:ok, _pid} = start_supervised(ComplexSystem)

    eventually assert_in_delta 42, elem(ComplexSystem.get_value(), 1), 0
  end
  ```
  """
  defmacro eventually({assert_call, meta, args} = _assert_expr, timeout \\ nil) do
    timeout = timeout || Module.get_attribute(__CALLER__.module, :assert_eventually_timeout)
    eventually_impl(assert_call, meta, args, timeout)
  end

  @doc """
  Equivalent to: `eventually(assert(expr), timeout)`
  """
  defmacro assert_eventually(expr, timeout \\ nil) do
    timeout = timeout || Module.get_attribute(__CALLER__.module, :assert_eventually_timeout)

    {assert_call, _, _} =
      quote do
        ExUnit.Assertions.assert()
      end

    # List.wrap/1 can't be used here, as it returns empty list when input is `nil`
    # while here, we really need to get `[nil]` instead.
    args =
      if is_list(expr) do
        expr
      else
        [expr]
      end

    eventually_impl(assert_call, [], args, timeout)
  end

  defp eventually_impl(assert_call, meta, [{:=, opts, [variable, rest]}], timeout) do
    ignored_variable = neutralize_variable(variable)
    neutral_assignment_ast = [{:=, opts, [ignored_variable, rest]}]
    assert = {assert_call, meta, neutral_assignment_ast}

    quote do
      fun = unquote(eventually_impl_fun_definition(assert, timeout))

      # pass defined function as argument to itself to allow for recursion
      result = fun.(fun, unquote(now_ts()))
      unquote({:=, opts, [variable, {:result, [], AssertEventually}]})
    end
  end

  defp eventually_impl(assert_call, meta, args, timeout) do
    assert = {assert_call, meta, args}

    quote do
      fun = unquote(eventually_impl_fun_definition(assert, timeout))

      # pass defined function as argument to itself to allow for recursion
      fun.(fun, unquote(now_ts()))
    end
  end

  defp eventually_impl_fun_definition(assert, timeout) do
    quote do
      fn f, start_time ->
        if unquote(now_ts()) - start_time <= unquote(timeout) do
          try do
            unquote(assert)
          catch
            _type, _reason ->
              Process.sleep(@assert_eventually_interval)
              f.(f, start_time)
          end
        else
          unquote(assert)
        end
      end
    end
  end

  # lists
  defp neutralize_variable(list) when is_list(list) do
    Enum.map(list, &neutralize_variable/1)
  end

  # pinned values
  defp neutralize_variable({:^, meta, values}) do
    {:^, meta, values}
  end

  # lists with head separator
  defp neutralize_variable({:|, meta, values}) do
    {:|, meta, Enum.map(values, &neutralize_variable/1)}
  end

  # tuples
  defp neutralize_variable({:{}, meta, rest}) do
    {:{}, meta, Enum.map(rest, &neutralize_variable/1)}
  end

  # Exception - 2-elem tuples are represented as-is in AST
  defp neutralize_variable({part1, part2}) do
    {neutralize_variable(part1), neutralize_variable(part2)}
  end

  # maps
  defp neutralize_variable({:%{}, meta, content}) do
    {:%{}, meta,
     Enum.map(content, fn
       {key, variable} -> {key, neutralize_variable(variable)}
     end)}
  end

  # structs
  defp neutralize_variable({:%, meta, [aliases, map]}) do
    {:%, meta, [aliases, neutralize_variable(map)]}
  end

  # variables
  defp neutralize_variable({atom, meta, module}) when is_atom(atom) do
    string_value = Atom.to_string(atom)

    if String.starts_with?(string_value, "_") do
      {atom, meta, module}
    else
      {:"_#{string_value}", meta, module}
    end
  end

  # base values
  defp neutralize_variable(variable), do: variable

  defp now_ts() do
    quote do
      :erlang.monotonic_time(:millisecond)
    end
  end
end
