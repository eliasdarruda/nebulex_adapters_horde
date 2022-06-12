defmodule Nebulex.Adapters.Horde.GenServerItem do
  @moduledoc """
  This defines Horde Cache GenServer Item process (every process represents a key that holds a value)
  """

  use GenServer

  @impl true
  def init({key, value, ttl}) do
    Process.flag(:trap_exit, true)

    entry = %Nebulex.Entry{
      key: key,
      ttl: ttl,
      value: value
    }

    timer_ref = change_timer(self(), nil, ttl)

    {:ok, parse_state({entry, timer_ref})}
  end

  @impl true
  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, parse_state(state)}
  end

  @impl true
  def handle_call(:get, _from, {entry, _} = state) do
    {:reply, entry.value, parse_state(state)}
  end

  @impl true
  def handle_call(:get_entry, _from, {entry, _} = state) do
    {:reply, entry, parse_state(state)}
  end

  @impl true
  def handle_call({:put, value, ttl}, _from, {entry, timer_ref}) do
    timer_ref = change_timer(self(), timer_ref, ttl)

    {:reply, true, parse_state({%{entry | value: value, ttl: ttl}, timer_ref})}
  end

  @impl true
  def handle_call(:touch, _from, state) do
    {:reply, true, parse_state(state)}
  end

  @impl true
  def handle_call(:take, _from, {entry, _} = state) do
    {:stop, :normal, entry.value, parse_state(state)}
  end

  @impl true
  def handle_call({:expire, ttl}, _from, {entry, timer_ref} = state) do
    cond do
      ttl <= 0 ->
        {:stop, :normal, true, parse_state(state)}

      true ->
        timer_ref = change_timer(self(), timer_ref, ttl)

        {:reply, true, parse_state({%{entry | ttl: ttl}, timer_ref})}
    end
  end

  @impl true
  def handle_call(:ttl, _from, {entry, _} = state) do
    {:reply, entry.ttl, parse_state(state)}
  end

  @impl true
  def handle_call({:update_counter, amount, ttl}, _from, {entry, timer_ref}) do
    timer_ref = change_timer(self(), timer_ref, ttl)

    new_value = entry.value + amount

    {:reply, new_value, parse_state({%{entry | value: new_value, ttl: ttl}, timer_ref})}
  end

  def start_link(registry_name, key, value \\ nil, ttl \\ nil) do
    GenServer.start_link(__MODULE__, {key, value, ttl}, name: via(key, registry_name))
  end

  def via(key, registry_name), do: {:via, Horde.Registry, {registry_name, {:cache_keys, key}}}

  defp change_timer(pid, timer_ref, :infinity), do: change_timer(pid, timer_ref, nil)
  defp change_timer(pid, timer_ref, ttl) do
    if not is_nil(timer_ref) do
      Process.cancel_timer(timer_ref)
    end

    if not is_nil(ttl) do
      Process.send_after(pid, :stop, ttl)
    end
  end

  defp parse_state({entry, ref}) do
    {%{entry | touched: Nebulex.Time.now(), ttl: to_ttl(entry.ttl)}, ref}
  end

  defp to_ttl(nil), do: :infinity
  defp to_ttl(ttl), do: ttl
end
