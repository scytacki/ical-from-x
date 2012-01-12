require 'rubygems'
require 'date'
require 'icalendar'
require 'trollop'
require 'bzip2'

# commandline option parsing
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int
  opt :year, 'Year to filter results with', :type => :int
  opt :out, 'Output file to put the resulting ics', :type => :string
end

# Jan 21 21:51:41 scotts-macbook kernel[0]: System SafeSleep (this happens a little bit before sleep while it is writing hiberation file)
def get_log_time(line)
  data_string = line.match(/[\w]*[\s]*[\w]*[\s]*[^\s]*/)[0]
  DateTime.parse(data_string)
end

class LoggedEvent
  attr_accessor :date_time, :line, :type

  def initialize(line, type)
    @line = line
    @date_time = get_log_time(line)
    @type = type
  end

  def location
    if(line =~ /dhcp/)
      "work"
    else
      "home"
    end
  end
end

events = []

sys_logs = Dir.glob('/private/var/log/kernel.log*')
sys_logs.each { |log|
  if (log.end_with? 'bz2')
    file = Bzip2::Reader.open(log, :encoding => "US-ASCII")
  elsif
    file = File.open(log, :encoding => "US-ASCII")
  end

  while (line = file.gets)
    begin
      if (line =~ /.*System.*Wake/)
        # This is a wakup it could be "System Wake" or "System SafeSleep Wake"
        events.push(LoggedEvent.new(line, :wake))
      elsif (line =~ /.*System SafeSleep$/)
        # This is a sleep
        # need to find the cooresponding wake event and close it
        events.push(LoggedEvent.new(line, :sleep))
      end
    rescue
      puts "Error compairing string: #{line}"
    end
  end

  file.close
}

year = options[:year]
month = options[:month]

start_time = Time.local(year, month).to_datetime
end_time = Time.local(year, month).to_datetime >> 1

events = events.select { |event| event.date_time > start_time and event.date_time < end_time}

events = events.sort_by {|event| event.date_time}

#consolidate them
last_event = nil
new_events = []
events.each { |event|
  if (event.type == :wake and last_event and last_event.type == :sleep and (last_event.date_time + (4.0/(60*24))) > event.date_time)
    # remove last event
    new_events.pop
    # skip the current wake
    next
  end
  last_event = event
  new_events.push event
}

events = new_events

cal = Icalendar::Calendar.new

last_wake = nil
events.each{ |event|
  if event.type == :wake
    last_wake = event
    next
  end

  if last_wake == nil
    puts "Got a sleep without a preceeding wake"
    next
  end

  cal.event {
    dtstart last_wake.date_time
    dtend event.date_time
    description event.line
    summary "Laptop at #{event.location}"
  }
  last_wake = nil
}

File.open(options[:out], 'w') {|f|
  f.write cal.to_ical
}

