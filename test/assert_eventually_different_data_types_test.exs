defmodule AssertEventually.DifferentDataTypesTest do
  use ExUnit.Case, async: true
  use AssertEventually, timeout: 50, interval: 5

  defmodule TestStruct do
    defstruct [:a]
  end

  test "big map" do
    assert_eventually %{a: %{b: %{c: [%{a: a}, %{b: b}, %{c: _c}]}}} = %{
                        a: %{b: %{c: [%{a: 123}, %{b: 321}, %{c: :ignore}]}}
                      }

    assert 123 == a
    assert 321 == b
  end

  test "tuple" do
    assert_eventually {a, b, c} = {:a, 2, "C"}

    assert :a == a
    assert 2 == b
    assert "C" == c
  end

  test "2-elem tuple" do
    assert_eventually {:ok, %{a: a}} = {:ok, %{a: 1}}
    assert 1 == a
  end

  test "one tuple" do
    assert_eventually {:ok} = {:ok}
    assert_eventually {a} = {:ok}
    assert :ok == a
  end

  test "structs" do
    assert_eventually %AssertEventually.DifferentDataTypesTest.TestStruct{a: a} = %TestStruct{a: :ok}
    assert :ok == a

    assert_eventually a
  end

  test "lists" do
    assert_eventually [a, b, c] = [1, "b", :c]

    assert 1 == a
    assert "b" == b
    assert :c == c

    assert_eventually [a | b] = [1, 2, 3]

    assert 1 == a
    assert [2, 3] == b

    assert_eventually [1 | [2 | [3 | _]]] = [1, 2, 3]
  end
end
