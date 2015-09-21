require 'socket'
require 'observer'
require 'pry'

class Connection
  include Observable
  attr_reader :socket

  def initialize(connection_id, socket)
    @socket = socket
    @connection_id = connection_id
    @alive = true
  end

  def write(s)
    @socket.write s
  end

  def update()
    data = @socket.recv(1024)
    @alive = !data.empty?
    changed
    notify_observers @connection_id, data
  end

  def alive?
    return @alive
  end

  def socket
    return @socket
  end
end

class Server

  def initialize(ip, port)
    @server = TCPServer.open(ip, port)

    @connections = []
    @mutex_c     = Mutex.new # Access to @connections

    @evt_queue   = Queue.new
    @mutex_q     = Mutex.new # Access to @evt_queue

    @thread      = Thread.new do run end
  end

  def has_event?
    @mutex_q.synchronize do
      return @evt_queue.size > 0
    end
  end

  def pop_event
    @mutex_q.synchronize do
      return @evt_queue.pop
    end
  end

  def write connection_id, s
    @mutex_c.synchronize do
      @connections[connection_id].write s
    end
  end

  def address connection_id
    @mutex_c.synchronize do
      _,_,hostname,_ = @connections[connection_id].socket.addr
      return hostname
    end
  end

  def incoming_data connection_id, data
    if not data.empty? then
      @mutex_q.synchronize do
        @evt_queue << {
          :type => :incoming_data,
          :connection_id => connection_id,
          :data => data
        }
      end
    else
      @mutex_q.synchronize do
        @evt_queue << {
          :type => :disconnect, 
          :connection_id => connection_id
        }
      end
    end
  end

  private

  def run
    loop do
      Thread.start(@server.accept) do |socket|
        connection    = nil
        connection_id = -1

        @mutex_c.synchronize do
          connection_id = @connections.size
          @connections << Connection.new(connection_id, socket)
          connection    = @connections[-1]
          connection.add_observer(self, :incoming_data)
        end

        @mutex_q.synchronize do
          @evt_queue << {
            :type => :connect,
            :connection_id => connection_id
          }
        end

        while connection.alive? do
          connection.update
        end
      end
    end
  end

end
