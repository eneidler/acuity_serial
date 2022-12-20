defmodule AcuitySerial do
  #import Circuits.UART
  alias Circuits.UART, as: CU
  @moduledoc """
  Documentation for `AcuitySerial`.

    This module is used for interfacing via serial communication with the Acuity laser gauging HMI.

  """

  @doc """
  Lists all available serial devices currently connected.

    Returns a map with device name as the key. Each key contains another map with additional info in key-value pairs.

    ## Example

    iex> AcuitySerial.available_devices()
    %{
      "COM3" => %{
        description: "Intel(R) Active Management Technology - SOL",
        manufacturer: "Intel",
        product_id: 17379,
        vendor_id: 32902
      },
      "COM4" => %{
        description: "Arduino Uno",
        manufacturer: "Arduino LLC (www.arduino.cc)",
        product_id: 67,
        vendor_id: 9025
      }
    }
  """
  @spec available_devices()::none()
  def available_devices(), do: CU.enumerate()

  @doc """
  Connects to the device specified by the string 'device_name'.
    
    Suggested use is to use assignment when calling so the 'pid' can be used elsewhere. See example.

    Returns pid of device.

    ## Example
    iex> pid = AcuitySerial.connect_device("COM4")
    #PID<0.210.0>
  """
  @spec connect_device(String.t())::pid()
  def connect_device(device_name) do
    {:ok, pid} = CU.start_link
    CU.open(pid, device_name, active: false)
    configure_separator(pid)
    pid
  end

  @doc """
  Disconnects the device. This kills the process the device was connected in.

    Returns ':ok'.

    ## Example
      iex> pid = AcuitySerial.connect_device("COM4")
      #PID<0.210.0>
      iex> AcuitySerial.disconnect_device(pid)
      :ok
  """
  @spec disconnect_device(pid())::none()
  def disconnect_device(pid), do: CU.stop(pid)

  def read_loop(acc \\ 0)
  def read_loop(acc) when acc >= 5, do: :complete
  def read_loop(acc) when acc < 5 do
    IO.puts(acc)
    Process.sleep(1000)
    read_loop(acc + 1)
  end

  @doc """
  This function generates a list containing ten separate keyvalue lists, read from the serial connection.

    Automatically formats the incoming data using private functions 'read_to_float_list/1' and 'to_key_value/0'

    Returns tuple(nonempty_list(nonempty_list(tuples())), :complete) when called using generate_read_list/1.

    ## Example
      iex> AcuitySerial.generate_read_list(pid)
      {[
        [west: 0.369, center: 0.398, east: 0.392],
        [west: 0.368, center: 0.371, east: 0.352],
        [west: 0.352, center: 0.37, east: 0.357],
        [west: 0.379, center: 0.383, east: 0.359],
        [west: 0.366, center: 0.356, east: 0.356],
        [west: 0.367, center: 0.385, east: 0.395],
        [west: 0.372, center: 0.383, east: 0.382],
        [west: 0.355, center: 0.373, east: 0.388],
        [west: 0.353, center: 0.382, east: 0.384],
        [west: 0.384, center: 0.39, east: 0.36]
      ], :complete}

  """
  @spec generate_read_list(pid())::fun(pid(), non_neg_integer())
  def generate_read_list(pid), do: generate_read_list(pid, 0)

  defp generate_read_list(pid, acc) when acc == 0 do
    keylist = []
    result = read_to_float_list(pid) 
    |> to_key_value()

    List.insert_at(keylist, acc, result)
    |> generate_read_list(pid, acc + 1)
  end

  defp generate_read_list(keylist, _pid, acc) when acc >= 10, do: {keylist, :complete}

  defp generate_read_list(keylist, pid, acc) when acc < 10 do
    result = read_to_float_list(pid) 
    |> to_key_value()

    List.insert_at(keylist, acc, result)
    |> generate_read_list(pid, acc + 1)
  end

 
  # Used internally to configure the separtor for the incoming serial data.
  
    # Uses the windows representation of a carriage return ("\r\n") by default, but accepts others.

    # Returns none()
  @spec configure_separator(pid(), String.t())::none()
  defp configure_separator(pid, separator \\ "\r\n"), do: CU.configure(pid, framing: {CU.Framing.Line, separator: separator})


  # Reads the incoming serial data, splits it, and converts it to a list of floats.

    # This is a private function that is only called by generate_read_list/2 and generate_read_list/3

    # Returns list(float())
  @spec read_to_float_list(pid())::list(float())
  defp read_to_float_list(pid) do
    {_, message} = CU.read(pid)
    String.split(message, "\t")
    |> Enum.map(fn x -> String.to_float(x) end)
  end



  # Takes a list of three float values, and outputs a key value list of tuples using ':west', ':center', and ':east' as keys.

    # This is a private function that is only called by generate_read_list/2 and generate_read_list/3

    # Returns list(tuple())
  @spec to_key_value(list(float()))::nonempty_list(tuple())
  defp to_key_value(list) do
    tuple = List.to_tuple(list)
    {west, center, east} = tuple
    [west: west, center: center, east: east]
  end

end
