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
    eventually_impl(assert_call, meta, args, timeout, __CALLER__)
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

    eventually_impl(assert_call, [], args, timeout, __CALLER__)
  end

  defp eventually_impl(assert_call, meta, args, timeout, caller) do
    assert = {assert_call, meta, args}
    result_var = Macro.var(:result, unquote(__MODULE__))

    vars =
      assert
      |> Macro.expand(caller)
      |> collect_left_hand_sides()
      |> List.foldl([], fn lhs, acc ->
        collect_all_local_vars(lhs) ++ acc
      end)
      |> Enum.uniq()

    quote do
      fun = unquote(eventually_impl_fun_definition(assert, vars, timeout))

      # We pass defined function as argument to itself to allow for recursion.
      # Also, to all variables found in macro arguments we assign their values
      # captured by loop-function.
      {unquote(result_var), unquote(vars)} = fun.(fun, unquote(now_ts()))
      unquote(result_var)
    end
  end

  defp eventually_impl_fun_definition(assert, vars, timeout) do
    quote do
      fn f, start_time ->
        if unquote(now_ts()) - start_time <= unquote(timeout) do
          try do
            result = unquote(assert)
            # in addition to result we return values of all variables detected in macro arguments
            {result, unquote(mark_as_generated(vars))}
          catch
            _type, _reason ->
              Process.sleep(@assert_eventually_interval)
              f.(f, start_time)
          end
        else
          result = unquote(assert)
          {result, unquote(mark_as_generated(vars))}
        end
      end
    end
  end

  defp now_ts() do
    quote do
      :erlang.monotonic_time(:millisecond)
    end
  end

  defp collect_left_hand_sides(expr) do
    expr
    |> Macro.prewalk([], fn
      {:=, _, [left, _right]} = node, acc ->
        {node, [left | acc]}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp collect_all_local_vars(ast) do
    Macro.prewalk(ast, [], fn
      {name, meta, nil} = node, acc when is_atom(name) ->
        if String.starts_with?(to_string(name), "_") do
          {node, acc}
        else
          {:ok, [{name, meta, nil} | acc]}
        end

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  defp mark_as_generated(vars) do
    for {name, meta, context} <- vars, do: {name, [generated: true] ++ meta, context}
  end
end
