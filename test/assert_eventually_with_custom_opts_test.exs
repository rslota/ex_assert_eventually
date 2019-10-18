defmodule AssertEventually.WithCustomOptsTest do
  use ExUnit.Case, async: true
  use AssertEventually, timeout: 50, interval: 5

  alias AssertEventually.Utils.MockOperation

  describe "not so happy case using assert_eventually" do
    test "when match is passed that becomes sucessful after too many tries" do
      # Default 20ms per try * 10 = 200ms timeout
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, fail_times: 12]}
        )

      e =
        assert_raise ExUnit.AssertionError, fn ->
          assert_eventually(:ok = MockOperation.do_something(mock))
        end

      assert e.right == :error

      stats = MockOperation.get_stats(mock)
      assert_in_delta stats.call_counter, 10, 2
    end

    test "when match is passed that becomes sucessful after too much time" do
      # Default 20ms per try * 10 = 200ms timeout
      {:ok, mock} =
        start_supervised(
          {MockOperation, [success_return: :ok, failure_return: :error, succeed_after: 60]}
        )

      e =
        assert_raise ExUnit.AssertionError, fn ->
          assert_eventually(:ok = MockOperation.do_something(mock))
        end

      assert e.right == :error

      stats = MockOperation.get_stats(mock)
      assert_in_delta stats.call_counter, 11, 2
    end
  end
end
