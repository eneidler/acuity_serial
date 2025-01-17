defmodule AcuitySerial do

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
  def available_devices() do
    no_devices = %{}
    case CU.enumerate do
       ^no_devices -> {:error, "No devices available. Check that device is connected."}
        _  -> {:ok, CU.enumerate}
    end
  end

  @doc """
  Connects to the device specified by the string 'device_name'.

    Suggested use is to use assignment when calling so the 'pid' can be used elsewhere. See example.

    Returns pid of device.

    ## Examples
      iex> pid = AcuitySerial.connect_device("COM4")
      #PID<0.210.0>

      iex> AcuitySerial.connect_device(pid)
      {:error,
      "Argument must be a string containing a valid device name. Use 'AcuitySerial.available_devices/0' to find devices."}

  """
  @spec connect_device(String.t(), boolean())::pid()
  def connect_device(device_name, mode \\ :passive)
  def connect_device(_device_name, mode) when is_boolean(mode), do: {:error, "Input must be the atom :active or :passive"}
  def connect_device(_device_name, mode) when not is_atom(mode), do: {:error, "Input must be the atom :active or :passive"}
  def connect_device(device_name, _mode) when not is_bitstring(device_name), do: {:error,
    "Argument must be a string containing a valid device name. Use 'AcuitySerial.available_devices/0' to find devices."}
  def connect_device(device_name, mode) do
    {:ok, pid} = CU.start_link
    case mode do
      :active -> CU.open(pid, device_name, active: true)
      :passive -> CU.open(pid, device_name, active: false)
    end
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

  # TODO: Loop function currently not functional. Do not use. Declared as private to prevent accidental calling from programs.
    # defp read_loop(pid, acc \\ 0)
    # defp read_loop(_pid, acc) when acc >= 5, do: :complete
    # defp read_loop(pid, acc) when acc < 5 do
    #   IO.puts(acc)
    #   IO.inspect(passive_read(pid))
    #   #Process.sleep(1000)
    #   read_loop(pid, acc + 1)
    # end
  #

  @doc """
  Displays the configuration for the selected 'pid'.

    Returns a tuple with the device name as the first element, and a list of config settings as the second element.

    ## Example
      iex> AcuitySerial.get_config(pid)
      {"COM4",
      [
        speed: 9600,
        data_bits: 8,
        stop_bits: 1,
        parity: :none,
        flow_control: :none,
        active: false,
        id: :name,
        rx_framing_timeout: 0,
        framing: Circuits.UART.Framing.Line
      ]}

  """
  @spec get_config(pid())::tuple()
  def get_config(pid), do: CU.configuration(pid)

  @doc """
  Sets the read mode for the device at the selected 'pid' either :active or :passive.

    Will return an error is anything but two valid atoms (:active | :passive) are passed as arguments.

    Returns :ok if valid arguments are give.

    ## Examples
        iex> AcuitySerial.set_read_mode(pid, :active)
        :ok

        iex> AcuitySerial.set_read_mode(pid, :passive)
        :ok

        iex> AcuitySerial.set_read_mode(pid, pid)
        {:error, "Input must be :active or :passive"}

        iex> AcuitySerial.set_read_mode(pid, true)
        {:error, "Input must be :active or :passive"}

  """
  @spec set_read_mode(pid(), atom())::none()
  def set_read_mode(_pid, mode) when not is_atom(mode), do: {:error, "Input must be the atom :active or :passive"}
  def set_read_mode(pid, mode) when mode == :active, do: CU.configure(pid, active: true)
  def set_read_mode(pid, mode) when mode == :passive, do: CU.configure(pid, active: false)
  def set_read_mode(_pid, _), do: {:error, "Input must be the atom :active or :passive"}

  @doc """
  Receives a single message from connected device in active read mode and prints to the screen.
  """
  @spec active_read(String.t())::String.t()
  def active_read(device_name), do: active_read(device_name, 0)
  defp active_read(device_name, acc) do
    receive do
      {:circuits_uart, ^device_name, msg} -> IO.puts(msg)
      _other -> IO.puts("No data to report.")
    after 1500 -> IO.puts("1500ms with no data.")
    end
    if acc < 50 do
      active_read(device_name, acc + 1)
    end
  end

  @doc """
  This function generates a list containing ten separate keyvalue lists, read from the serial connection.

    Automatically formats the incoming data using private functions 'read_to_float_list/1' and 'to_key_value/0'

    Returns tuple(nonempty_list(nonempty_list(tuples())), :complete) when called using passive_read/1.

    ## Example
      iex> AcuitySerial.passive_read(pid)
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
  @spec passive_read(pid())::fun(pid(), non_neg_integer())
  def passive_read(pid), do: passive_read(pid, 0)
  defp passive_read(pid, acc) when acc == 0 do
    keylist = []
    result = read_to_float_list(pid)
    |> to_key_value()

    List.insert_at(keylist, acc, result)
    |> passive_read(pid, acc + 1)
  end
  defp passive_read(keylist, _pid, acc) when acc >= 10, do: {keylist, :complete}
  defp passive_read(keylist, pid, acc) when acc < 10 do
    result = read_to_float_list(pid)
    |> to_key_value()
    List.insert_at(keylist, acc, result)
    |> passive_read(pid, acc + 1)
  end

  # Used to check whether process is still alive
  @spec alive?(pid())::atom()
  def alive?(pid) do
    Process.alive?(pid)
  end

  # Used internally to configure the separtor for the incoming serial data.

    # Uses the windows representation of a carriage return ("\r\n") by default, but accepts others.

    # Returns none()
  @spec configure_separator(pid(), String.t())::none()
  defp configure_separator(pid, separator \\ "\r\n"), do: CU.configure(pid, framing: {CU.Framing.Line, separator: separator})


  # Reads the incoming serial data, splits it, and converts it to a list of floats.

    # This is a private function that is only called by passive_read/2 and passive_read/3

    # Returns list(float())
  @spec read_to_float_list(pid())::list(float())
  defp read_to_float_list(pid) do
    {_, message} = CU.read(pid)
    String.split(message, "\t")
    |> Enum.map(fn x -> String.to_float(x) end)
  end


  # Takes a list of three float values, and outputs a key value list of tuples using ':west', ':center', and ':east' as keys.

    # This is a private function that is only called by passive_read/2 and passive_read/3

    # Returns list(tuple())
  @spec to_key_value(list(float()))::nonempty_list(tuple())
  defp to_key_value(list) do
    tuple = List.to_tuple(list)
    {west, center, east} = tuple
    [west: west, center: center, east: east]
  end

end
