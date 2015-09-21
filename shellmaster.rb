require 'curses'
require_relative './server.rb'
require_relative './shell.rb'

include Curses

$server = Server.new '', 5556

Curses.init_screen

$command_events = Queue.new
$event_handlers = []
$key_handlers = []
$shells = []
$active = nil

def get_ip shell
  return $server.address shell.id
end

class ConnectHandler
  def event evt
    if evt[:type] == :connect then
      connection_id = evt[:connection_id]
      shell = Shell.new(connection_id, Curses.lines, Curses.cols)
      $shells << shell
      $active = shell # Newest connection is the active one
    end
  end
end
$event_handlers << ConnectHandler.new

class CommandHandler
  def initialize
    @prep_arrow = 0
  end

  def key c
    if (@prep_arrow == 0) and (c == 27) then
      @prep_arrow = 1
      return true
    end

    if (@prep_arrow == 1) and (c == '[') then
      @prep_arrow = 2
      return true
    end

    if (@prep_arrow == 2) then
      @prep_arrow = 0
      case c
      when 'A'
        $command_events << {:type => :key, :key => :UP}
      when 'B'
        $command_events << {:type => :key, :key => :DOWN}
      when 'C'
        $command_events << {:type => :key, :key => :RIGHT}
      when 'D'
        $command_events << {:type => :key, :key => :LEFT}
      end

      return true
    end

    return false
  end
end
$key_handlers << CommandHandler.new

class InputHandler
  def key c
    case c
    when nil
      return false
    when Key::ENTER, 10
      $server.write $active.id, "\n"
    when Key::BACKSPACE, 127
      $server.write $active.id, "\b"
    else
      $server.write $active.id, c
    end
    return true
  end
end
$key_handlers << InputHandler.new

loop do

  # Handle command events
  while not $command_events.empty? do
    evt = $command_events.pop
    if evt[:type] == :key then
      if (evt[:key] == :RIGHT) and ($active != nil) then
        id = ($active.id + 1) % $shells.size
        $active = $shells[id]
        $active.refresh_view
      end
      if (evt[:key] == :LEFT) and ($active != nil) then
        n = $active.id - 1
        n = ((n == -1) ? $shells.size - 1 : n)
        id = n % $shells.size
        $active = $shells[id]
        $active.refresh_view
      end
    end
  end

  while $server.has_event? do

    # Local event handlers
    evt = $server.pop_event
    $event_handlers.each do |handle|
      handle.event evt
    end

    # Dispatch to local event handlers for shells
    $shells.each do |shell|
      shell.dispatch evt
      shell.refresh_view
    end
  end

  # Only for the active shell
  # Read keyboard input and send it off
  if $active != nil then
    c = $active.getch
    $key_handlers.each do |handle|
      # Breakes if handler returns true
      if handle.key(c) then
        break
      end
    end

  end

end
