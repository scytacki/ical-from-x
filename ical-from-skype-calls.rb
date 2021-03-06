require 'rubygems'
require 'appscript'
require 'icalendar'
include Appscript
require 'trollop'
require 'date'

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, '(not implemented) Month to filter results with', :type => :int
  opt :year, '(not implemented) Year to filter results with', :type => :int
  opt :out, 'Output file to put the resulting ics', :type => :string
end

# Skype api commands to get info about the history of calls:
# 
# get a list of call ids
# SEARCH CALLS
# GET CALL <id> property
# 
# properties:
# TIMESTAMP
# PARTNER_DISPNAME
# PARTNER_HANDLE 
# TYPE
# STATUS
# DURATION
# CONF_PARTICIPANTS_COUNT
# CONF_PARTICIPANT n



# "/Users/scytacki/Documents/CCProjects/Timesheets/june-2010/skype-calls.ics"
ics_file = options[:out]

@skype = app('Skype')

def skype_send(command)
  @skype.send_(:command => command, :script_name => 'History Searcher')
end

def call_property(call_id, property)
  ret = skype_send("GET CALL #{call_id} #{property}")
  if(!ret)
    raise "get call returned nil. call: #{call_id} #{property}"
  end
  regex = /CALL #{call_id} #{property} (.*)/
  match_data = ret.match(regex)
  if(!match_data)
    raise 'miss matched result: ' + ret + ' regex: ' + regex.to_s + ' match_data: ' + match_data.to_s
  end

  match_data[1]
end

user_status = skype_send("GET USERSTATUS")
puts user_status
calls_string = skype_send("SEARCH CALLS")
abort("Need to start skype and log in") if calls_string.nil?
calls = calls_string.sub('CALLS ', '').split(', ')

cal = Icalendar::Calendar.new
min_duration = 8*60

calls.each do |call_id|
  begin
    timestamp = call_property(call_id, 'TIMESTAMP')
    partner = call_property(call_id, 'PARTNER_HANDLE')
    duration = call_property(call_id, 'DURATION')
    type = call_property(call_id, 'TYPE')
    status = call_property(call_id, 'STATUS')
  rescue => exception
    putc 'X'
    # puts exception.backtrace 
    next
  end
  
  putc '.'
  # puts Time.at(timestamp.to_i).to_s + " #{partner} #{duration}"
  start_time = Time.at(timestamp.to_i)  
  
  cal.event{
    dtstart start_time.to_datetime
    if(duration.to_i > min_duration)
      dtend (start_time + duration.to_i).to_datetime
    else
      dtend (start_time + min_duration).to_datetime
    end
    summary "#{partner} #{duration.to_i/60}m #{duration.to_i%60}s"
  }      
end

puts "finished"

File.open(ics_file, 'w') {|f|
  f.write cal.to_ical
}