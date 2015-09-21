require 'curses'

class DataHandler
  def initialize shell
    @shell = shell
  end
  
  def event evt
    if evt[:type] == :incoming_data
      @shell.pad.scroll if @shell.pad.curx == @shell.pad.maxx
      @shell.pad << evt[:data].sub("\r\n","\n")
    end
  end
end

class Shell
  attr_reader :id, :pad

  def initialize id, width, height
    @pad = Pad.new width, height
    @id = id
    @pad.scrollok true
    @pad.timeout = 1
    @handlers = [DataHandler.new(self)]
  end

  def id
    return @id
  end

  def pad
    return @pad
  end

  def dispatch evt
    # Only continue if event is meant for us
    if evt[:connection_id] == @id then
      @handlers.each do |handle|
        handle.event evt
      end
    end
  end

  def refresh_view
    @pad.refresh([0,@pad.cury-@pad.maxy].min,[0,@pad.curx-@pad.maxx].min,0,0,@pad.maxy,@pad.maxx)
  end

  def getch
     pad.getch
  end

end
