defmodule AssertEventually.Utils.MockOperation do
  use GenServer

  def do_something(server) do
    GenServer.call(server, :do_something)
  end

  def get_stats(server) do
    GenServer.call(server, :get_stats)
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       opts: %{
         fail_times: opts[:fail_times] || 0,
         succeed_after: opts[:succeed_after] || 0,
         success_return: opts[:success_return],
         failure_return: opts[:failure_return]
       },
       first_call_timestamp: nil,
       call_counter: 0,
       successful_call_timestamp: nil
     }}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, %{} = state) do
    stats = Map.take(state, [:first_call_timestamp, :call_counter, :successful_call_timestamp])
    {:reply, stats, state}
  end

  def handle_call(:do_something, _from, %{} = state) do
    state = %{state | first_call_timestamp: state.first_call_timestamp || ts()}

    {state, response} =
      if state.call_counter >= state.opts.fail_times and
           ts() - state.first_call_timestamp >=
             state.opts.succeed_after do
        state = %{state | successful_call_timestamp: ts()}
        {state, state.opts.success_return}
      else
        {state, state.opts.failure_return}
      end

    state = %{state | call_counter: state.call_counter + 1}

    {:reply, response, state}
  end

  defp ts() do
    :os.system_time(:millisecond)
  end
end
