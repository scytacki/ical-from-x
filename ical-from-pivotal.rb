require 'rubygems'
require "JSON"
require 'highline/import'
require 'icalendar'
require 'date'
require 'trollop'
require 'date'
require 'tzinfo'
require_relative 'lib/ical-patch'

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int, :required => true
  opt :year, 'Year to filter results with', :type => :int, :required => true
  opt :out, 'Output file to put the resulting ics', :type => :string
end

# This is using version 5 of the pivotal API

abort("Need to set PIVOTAL_TOKEN env variable") if !ENV['PIVOTAL_TOKEN'] || ENV['PIVOTAL_TOKEN'].empty?

first_of_month = Time.local(options[:year],options[:month]).to_datetime.iso8601
end_of_month = Time.local(options[:year],(options[:month]+1)%12).to_datetime.iso8601

PT_QUERY = "envelope=true&limit=100&occurred_after=#{first_of_month}&occurred_before=#{end_of_month}"
PT_URL = "https://www.pivotaltracker.com/services/v5/my/activity?#{PT_QUERY}"
def get_data(url)
	`curl -X GET -H "X-TrackerToken: #{ENV['PIVOTAL_TOKEN']}" "#{url}"`
end

total = 1
loaded = 0
month_activity = []
while loaded < total do
  response = get_data(PT_URL + "&offset=#{loaded}")
  envelope = JSON.parse(response)
  total = envelope["pagination"]["total"]
  loaded += envelope["pagination"]["limit"]
  month_activity.push(*envelope["data"])
end


def event_time(event)
  DateTime.parse(event['occurred_at']).to_time
end

class VisitEventTrail
  attr_accessor :events

  def initialize()
    @events = []
  end

  def add(event)
    events.push event
  end


  def dtstart
  	event_time(events.first).to_datetime
  end

  def dtend
    first_time = event_time(events.first)
    # use a 8 minute minimun event size
    end_time = first_time + 8*60
    if event_time(events.last) > end_time
      end_time = event_time(events.last)
    end
    end_time.to_datetime
  end

  def description
  	output = "#{events.first['project']['name']}\n"
    output += events.collect{|event|
      "- #{event_time(event).to_datetime..strftime('%R')} #{event['message'].gsub("Scott Cytacki ","")[0...200]}"
    }.join("\n")
  end

  def summary
  	"#{events.first['project']['name']}: #{events.size} events"
  end
end


pt_events = []
trails = []

month_activity.reverse.each { |activity|
  puts "- #{activity['occurred_at']}: #{activity['message'].gsub("Scott Cytacki ","").gsub("\n"," ")[0...100]}"
  last_event = pt_events.last

  pt_events.push(activity)

  # look for overlaping events
  if (last_event and
  	  activity['project']['name'] == last_event['project']['name'] and
  	  (event_time(last_event) + 180) > event_time(activity))
    trails.last.add activity
    next
  end

  trail = VisitEventTrail.new
  trail.add activity
  trails.push trail
}


cal = Icalendar::Calendar.new

trails.each {|trail|
  cal.event{
    dtstart trail.dtstart
    dtend trail.dtend
    summary trail.summary
    description trail.description
  }
}

File.open(options[:out], 'w') {|f|
  cal.to_ical_file(f)
}
