defmodule NebulexAdaptersHorde.TestCache do
  @moduledoc false

  defmodule Common do
    @moduledoc false

    defmacro __using__(_opts) do
      quote do
        def get_and_update_fun(nil), do: {nil, 1}
        def get_and_update_fun(current) when is_integer(current), do: {current, current * 2}

        def get_and_update_bad_fun(_), do: :other
      end
    end
  end

  defmodule Local do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_horde,
      adapter: Nebulex.Adapters.Horde

    use NebulexAdaptersHorde.TestCache.Common
  end

  defmodule Partitioned do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_horde,
      adapter: Nebulex.Adapters.Partitioned,
      primary_storage_adapter: Nebulex.Adapters.Horde

    use NebulexAdaptersHorde.TestCache.Common
  end

  defmodule Replicated do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_horde,
      adapter: Nebulex.Adapters.Replicated,
      primary_storage_adapter: Nebulex.Adapters.Horde

    use NebulexAdaptersHorde.TestCache.Common
  end

  defmodule Multilevel do
    @moduledoc false
    use Nebulex.Cache,
      otp_app: :nebulex_adapters_horde,
      adapter: Nebulex.Adapters.Multilevel

    defmodule L1 do
      @moduledoc false
      use Nebulex.Cache,
        otp_app: :nebulex_adapters_horde,
        adapter: Nebulex.Adapters.Horde,
        primary_storage_adapter: Nebulex.Adapters.Local
    end

    defmodule L2 do
      @moduledoc false
      use Nebulex.Cache,
        otp_app: :nebulex_adapters_horde,
        adapter: Nebulex.Adapters.Replicated,
        primary_storage_adapter: Nebulex.Adapters.Local
    end

    defmodule L3 do
      @moduledoc false
      use Nebulex.Cache,
        otp_app: :nebulex_adapters_horde,
        adapter: Nebulex.Adapters.Partitioned,
        primary_storage_adapter: Nebulex.Adapters.Local
    end
  end
end
