defmodule Utils do
  defmacro current_module_function() do
    quote do
      {:current_function, {mod, func, arity}} = :erlang.process_info(self(), :current_function)
      "#{mod}.#{func}/#{arity}"
    end
  end
end
