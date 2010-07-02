require 'rubygems'
require 'appscript'
require 'icalendar'
include Appscript

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

ics_file = "/Users/scytacki/Documents/CCProjects/Timesheets/june-2010/skype-calls.ics"

@skype = app('Skype')

def skype_send(command)
  @skype.send_(:command => command, :script_name => 'History Searcher')
end

def call_property(call_id, property)
  ret = skype_send("GET CALL #{call_id} #{property}")
  regex = /CALL #{call_id} #{property} (.*)/
  match_data = ret.match(regex)
  if(!match_data)
    raise 'miss matched result: ' + ret + ' regex: ' + regex.to_s + ' match_data: ' + match_data.to_s
  end

  match_data[1]
end

calls_string = skype_send("SEARCH CALLS")
calls = calls_string.sub('CALLS ', '').split(', ')

cal = Icalendar::Calendar.new
min_duration = 8*60

calls.each do |call_id|
  timestamp = call_property(call_id, 'TIMESTAMP')
  partner = call_property(call_id, 'PARTNER_HANDLE')
  duration = call_property(call_id, 'DURATION')
  type = call_property(call_id, 'TYPE')
  status = call_property(call_id, 'STATUS')
  puts Time.at(timestamp.to_i).to_s + " #{partner} #{duration}"
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

File.open(ics_file, 'w') {|f|
  f.write cal.to_ical
}