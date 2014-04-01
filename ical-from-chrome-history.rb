require "rubygems"
require "bundler/setup"

require 'sqlite3'
require 'date'
require 'icalendar'
require 'trollop'
require 'uri'
require 'cgi'
require 'fileutils'
require 'active_record'
require 'debugger'
require_relative 'lib/ical-patch'

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int
  opt :year, 'Year to filter results with', :type => :int
  opt :database, 'Database file to process', :type => :string
  opt :out, 'Output file to put the resulting ics', :type => :string
end



# "june-2010/chrome-history.sqlite"
sqlite_file = options[:database]
# "/Users/scytacki/Documents/CCProjects/Timesheets/june-2010/ch-history.ics"
ics_file = options[:out]
# 2010
year = options[:year]
# 6
month = options[:month]

# copy the current chrome history file
unless sqlite_file
  out_dir = File.dirname ics_file
  sqlite_file="#{out_dir}/ch-history.sqlite"
  FileUtils.copy "#{ENV['HOME']}/Library/Application Support/Google/Chrome/Default/History", sqlite_file
end

def googleTime(time)
  1000000*time + 11644488003600000
end

def unixTime(gtime)
  gtime/1000000 - 11644488003.6
end

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => sqlite_file)

class Visit < ActiveRecord::Base
  belongs_to :chrome_url, foreign_key: :url

  attr_accessor :session, :computed_title

  def url
    chrome_url.url
  end

  def title
    chrome_url.title
  end

  def computed_title
    case url
    when %r{https://mail.google.com/.*#inbox$}
      # in this case the title will just be the most recent email
      "GMail Inbox"
    when %r{https://mail.google.com/.*#inbox/(\w*)$}
       # in this case the title will just be the most recent email
      "GMail Thread #{$1}"
    when %r{https://github.com/(.*)}
      "Google Plus"
    when %r{https://github.com/(.*)}
      "GH: #{$1}"
    when %r{https?://(.*)}
      "#{title} -- #{$1}"
    else
      "#{title} -- #{url}"
    end
  end

  def visit_time
    # needs to be fixed for the timezone
    Time.at(unixTime(super)) + 4*60*60
  end

  def short_description
    description = visit_time.strftime("%I:%M:%S") + ": "
    description += computed_title
    description
  end

end

class ChromeUrl < ActiveRecord::Base
  self.table_name = :urls
end

start_time = googleTime(Time.local(year, month).to_i)
end_time = googleTime((Time.local(year, month).to_datetime >> 1).to_time.to_i)

class VisitEventTrail
  attr_accessor :events

  def initialize()
    @events = []
  end

  def add(event)
    events.push event
  end

  def dtstart
    events.first.visit_time.to_datetime
  end

  def dtend
    first_time = events.first.visit_time
    # use a 8 minute minimun event size
    end_time = first_time + 8*60
    if events.last.visit_time > end_time
      end_time = events.last.visit_time
    end
    end_time.to_datetime
  end

  def description
    events.collect{|event|
      event.short_description
    }.join("\n")
  end
  
  def summary
    if events.first.computed_title
      events.first.computed_title
    else
      events.first.title
    end
  end
end

visit_events = []
visit_trails = []

visits = Visit.where("visits.visit_time>#{start_time} and visits.visit_time<#{end_time}")
visits.each { |event|
  last_event = visit_events.last

  # check if we want to keep this event
  if event.url =~ %r{https://rpm.newrelic.com/accounts/.*/servers/.*} ||
     event.url =~ %r{.*www.leftronic.com/share/g/.*/#dashboard.*} ||
     event.url =~ %r{.*concord-consortium.github.com/concord-dashboard/}
    next
  end

  visit_events.push(event)

  # look for overlaping events
  if (last_event and (last_event.visit_time + 180) > event.visit_time)
    visit_trails.last.add event
    next
  end

  visit_trail = VisitEventTrail.new
  visit_trail.add event
  visit_trails.push visit_trail
}

cal = Icalendar::Calendar.new

visit_trails.each {|trail|
  cal.event {
    dtstart trail.dtstart
    dtend trail.dtend
    description trail.description
    summary trail.summary
    url trail.events.first.url
  }
}

puts "length: #{visit_trails.length}"
File.open(ics_file, 'w') {|f|
  cal.to_ical_file(f)
}