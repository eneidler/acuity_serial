defmodule AcuitySerial do
  #import Circuits.UART
  alias Circuits.UART, as: CU
  @moduledoc """
  Documentation for `AcuitySerial`.
  """
  def list_available_devices(), do: CU.enumerate()

  def connect_device(device_name) do
    {:ok, pid} = CU.start_link
    CU.open(pid, device_name, active: false)
    pid
  end

  def disconnect_device(pid), do: CU.stop(pid)

  def configure_separator(pid, separator \\ "\r\n"), do: CU.configure(pid, framing: {CU.Framing.Line, separator: separator})

  def generate_read_list(pid), do: generate_read_list(pid, 0)

  def read_loop(acc \\ 0)
  def read_loop(acc) when acc >= 5, do: :complete
  def read_loop(acc) when acc < 5 do
    
    IO.puts(acc)
    Process.sleep(1000)
    read_loop(acc + 1)
  end

  defp generate_read_list(pid, acc) when acc == 0 do
    extract_float(pid) 
    |> add_to_list([])
    |> generate_read_list(pid, acc + 1)
  end

  defp generate_read_list([h | t], pid, acc) when acc >= 10, do: [h | t]

  defp generate_read_list([h | t], pid, acc) when acc < 10 do
    extract_float(pid) 
    |> add_to_list([h | t])
    |> generate_read_list(pid, acc + 1)
  end

  defp extract_float(pid) do
    {_, message} = CU.read(pid)
    {_, value} = String.split_at(message, -5)
    String.to_float(value)
  end

  defp add_to_list(value, list) do
    [value | list]
  end

end
