defmodule Nebulex.Adapters.Horde.Cache do
  @moduledoc """
  This defines a facade to access the desired horde cache implementation
  """

  alias Nebulex.Adapters.Horde.DynamicSupervisor
  alias Nebulex.Adapters.Horde.GenServerItem, as: Item

  def get!(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call(:get)
  catch
    :exit, {:noproc, _details} -> nil
  end

  def get_all!(adapter_meta, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      if value = get!(adapter_meta, key) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  def put!(adapter_meta, key, value, ttl) do
    %{name: name, registry_name: registry_name} = adapter_meta

    case DynamicSupervisor.add_gen_server_child(name, registry_name, key, value, ttl) do
      {:error, {:already_started, _pid}} ->
        Item.via(key, adapter_meta.registry_name)
        |> GenServer.call({:put, value, ttl})

      {:ok, _pid} ->
        true
    end
  end

  def put_all!(adapter_meta, entries, ttl) do
    Enum.map(entries, fn {key, value} ->
      try do
        put!(adapter_meta, key, value, ttl)
      catch
        :exit, {:noproc, _details} -> false
      end
    end)
    |> Enum.any?()
  end

  def put_new_all!(adapter_meta, entries, ttl) do
    keys = all(adapter_meta)

    has_key_already? =
      Enum.any?(entries, fn {key, _value} ->
        key in keys
      end)

    if has_key_already? do
      false
    else
      Enum.reduce(entries, true, fn {key, value}, _acc ->
        put_new!(adapter_meta, key, value, ttl)
      end)
    end
  end

  def put_new!(adapter_meta, key, value, ttl) do
    %{name: name, registry_name: registry_name} = adapter_meta

    case DynamicSupervisor.add_gen_server_child(name, registry_name, key, value, ttl) do
      {:error, {:already_started, _pid}} ->
        false

      {:ok, _pid} ->
        true
    end
  end

  def update!(adapter_meta, key, value, ttl) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call({:put, value, ttl})
  catch
    :exit, {:noproc, _details} -> false
  end

  def delete!(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call(:stop)
  catch
    :exit, {:noproc, _details} -> :ok
  end

  def take!(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call(:take)
  catch
    :exit, {:noproc, _details} -> nil
  end

  def exists?(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name) |> Horde.Registry.lookup() |> Enum.any?()
  end

  def expire!(adapter_meta, key, ttl) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call({:expire, ttl})
  catch
    :exit, {:noproc, _details} -> false
  end

  def ttl!(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call(:ttl)
  catch
    :exit, {:noproc, _details} -> nil
  end

  def touch!(adapter_meta, key) do
    Item.via(key, adapter_meta.registry_name)
    |> GenServer.call(:touch)
  catch
    :exit, {:noproc, _details} -> false
  end

  def count_all(adapter_meta) do
    %{active: count} = Horde.DynamicSupervisor.count_children(adapter_meta.name)

    count
  end

  def delete_all(adapter_meta) do
    pids = Horde.DynamicSupervisor.which_children(adapter_meta.name)

    Enum.each(pids, fn {_, pid, _type, _args} ->
      Horde.DynamicSupervisor.terminate_child(adapter_meta.name, pid)
    end)

    Enum.count(pids)
  end

  def all(adapter_meta, return_type \\ nil) do
    adapter_meta.name
    |> Horde.DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _type, _args} ->
      GenServer.call(pid, :get_entry)
    end)
    |> Enum.map(fn entry ->
      case return_type do
        :value -> entry.value
        :key -> entry.key
        :entry -> entry
        {:key, :value} -> {entry.key, entry.value}
        nil -> entry.key
      end
    end)
  end

  def stream_all(adapter_meta, return_type \\ nil) do
    adapter_meta.name
    |> Horde.DynamicSupervisor.which_children()
    |> Stream.map(fn {_, pid, _type, _args} ->
      GenServer.call(pid, :get_entry)
    end)
    |> Stream.map(fn entry ->
      case return_type do
        :value -> entry.value
        :key -> entry.key
        :entry -> entry
        {:key, :value} -> {entry.key, entry.value}
        nil -> entry.key
      end
    end)
  end

  def update_counter!(adapter_meta, key, amount, ttl, default) do
    %{name: name, registry_name: registry_name} = adapter_meta

    initial_amount = amount + default

    case DynamicSupervisor.add_gen_server_child(name, registry_name, key, initial_amount, ttl) do
      {:error, {:already_started, _pid}} ->
        Item.via(key, adapter_meta.registry_name)
        |> GenServer.call({:update_counter, amount, ttl})

      {:ok, _pid} ->
        initial_amount
    end
  end
end
