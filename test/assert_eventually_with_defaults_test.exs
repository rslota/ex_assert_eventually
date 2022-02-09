defmodule AssertEventually.WithDefaultsTest do
  use ExUnit.Case, async: true
  # Don't pass any options here - we use defaults
  use AssertEventually

  alias AssertEventually.Utils.MockOperation

  describe "happy case using eventually(assert_in_delta)" do
    test "when trivial range is passed" do
      eventually(assert_in_delta 5, 2, 3)
    end

    test "when range is passed that becomes sucessful after few tries" do
      {:ok, mock} =
        start_supervised({MockOperation, [success_return: 50, failure_return: 10, fail_times: 4]})

      eventually assert_in_delta 52, MockOperation.do_something(mock), 5
    end
  end

  describe "not so happy case using eventually(assert_in_delta)" do
    test "when trivial range is passed" do
      try do
        eventually(assert_in_delta(5, 2, 1), 70)
        flunk("Should've thrown ExUnit.AssertionError")
      catch
        _type, %ExUnit.AssertionError{} ->
          :ok
      end
    end

    test "when range is passed that becomes sucessful after too much time" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: 50, failure_return: 10, succeed_after: 70]}
        )

      try do
        eventually assert_in_delta(53, MockOperation.do_something(mock), 5), 40
        flunk("Should've thrown ExUnit.AssertionError")
      catch
        _type, %ExUnit.AssertionError{} ->
          :ok
      end
    end
  end

  describe "happy case using assert_eventually" do
    test "when trivial boolean value is passed" do
      returne_value = assert_eventually(true)
      assert returne_value == true
    end

    test "when trivial truthly value is passed" do
      returne_value = assert_eventually(15)
      assert returne_value == 15
    end

    test "when trivial match is passed" do
      returne_value =
        assert_eventually {:ok, %{some: value}} = {:ok, %{some: :real_value, other: :value}}

      assert returne_value == {:ok, %{some: :real_value, other: :value}}
      assert value == :real_value
    end

    test "when match is successful from the first try with assignment" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, fail_times: 0]}
        )

      returned_value = assert_eventually :ok = MockOperation.do_something(mock), :ok

      assert returned_value == :ok

      stats = MockOperation.get_stats(mock)
      # there should be just one call
      assert stats.call_counter ==  1
    end

    test "when match is successful from the first try with comparision" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, fail_times: 0]}
        )

      assert_eventually :ok == MockOperation.do_something(mock), :ok

      stats = MockOperation.get_stats(mock)
      # there should be just one call
      assert stats.call_counter ==  1
    end

    test "when match is passed that becomes sucessful after few tries" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, fail_times: 10]}
        )

      returne_value = assert_eventually :ok = MockOperation.do_something(mock), 1000

      assert returne_value == :ok

      stats = MockOperation.get_stats(mock)
      # by default there should be one call each 20ms
      assert_in_delta stats.call_counter, 10, 2
    end

    test "when match is passed that becomes sucessful after few seconds" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, succeed_after: 500]}
        )

      returne_value = assert_eventually :ok = MockOperation.do_something(mock)
      assert returne_value == :ok

      stats = MockOperation.get_stats(mock)
      # by default there should be one call each 20ms
      assert_in_delta stats.call_counter, 25, 5
    end

    test "when match is passed that becomes sucessful after few 900ms when 1000ms is a timeout" do
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, succeed_after: 900]}
        )

      returne_value = assert_eventually :ok = MockOperation.do_something(mock), 1000

      assert returne_value == :ok
    end
  end

  describe "not so happy case using assert_eventually" do
    test "when trivial boolean value is passed" do
      assert_raise ExUnit.AssertionError, fn -> assert_eventually(false, 20) end
    end

    test "when trivial truthly value is passed" do
      assert_raise ExUnit.AssertionError, fn -> assert_eventually(nil, 20) end
    end

    test "when trivial match is passed" do
      e =
        assert_raise ExUnit.AssertionError, fn ->
          assert_eventually {:ok, _} = {:error, :something}, 20
        end

      assert e.right == {:error, :something}
    end

    test "when match is passed that becomes sucessful after too many tries" do
      # Default 20ms per try * 10 = 200ms timeout
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, fail_times: 11]}
        )

      e =
        assert_raise ExUnit.AssertionError, fn ->
          assert_eventually :ok = MockOperation.do_something(mock), 200
        end

      assert e.right == :error
    end

    test "when match is passed that becomes sucessful after too much time" do
      # Default 20ms per try * 10 = 200ms timeout
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, succeed_after: 240]}
        )

      e =
        assert_raise ExUnit.AssertionError, fn ->
          assert_eventually :ok = MockOperation.do_something(mock), 200
        end

      assert e.right == :error
    end
  end
end
