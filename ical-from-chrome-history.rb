# this is currently based on the rvm 1.9.1%timesheet

require 'rubygems'
require 'sqlite3'
require 'date'
require 'icalendar'
require 'trollop'
require 'uri'
require 'cgi'
require 'fileutils'

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

db = SQLite3::Database.new( sqlite_file )

def googleTime(time)
  1000000*time + 11644488003600000
end

def unixTime(gtime)
  gtime/1000000 - 11644488003.6
end

start_time = googleTime(Time.local(year, month).to_i)
end_time = googleTime((Time.local(year, month).to_datetime >> 1).to_time.to_i)


# ["id", "from_visit", "place_id", "visit_date", "visit_type", "session", "id", "url", "title",
#  "rev_host", "visit_count", "hidden", "typed", "favicon_id", "frecency", "last_visit_date"]
query = "select * from visits, urls " +
        "where visits.url=urls.id " +
        "and visits.visit_time>#{start_time} " +
        "and visits.visit_time<#{end_time}"
puts query
length = 0
cal = Icalendar::Calendar.new

class VisitEvent
  attr_accessor :visit_date, :from_visit, :url, :title, :session, :computed_title

  def initialize(row)
    @from_visit = row[3].to_i
    @visit_date = row[2].to_i
    @url = row[8]
    @title = row[9]

    if(@url =~ %r{https://mail.google.com/.*#inbox$})
      # in this case the title will just be the most recent email
      @computed_title = "GMail Inbox"
    elsif(@url =~ %r{https://mail.google.com/.*#inbox/(\w*)$})
      # in this case the title will just be the most recent email
      @computed_title = "GMail Thread #{$1}"
    elsif(@url =~ %r{https://plus.google.com})
      @computed_title = "Google Plus"
    end
  end

  def visit_time
    # needs to be fixed for the timezone
    Time.at(unixTime(self.visit_date)) + 4*60*60
  end
  
  def short_description
    description = visit_time.strftime("%I:%M:%S") + ": "
    if computed_title
      description += computed_title
    else
      description += "#{title} -- #{url}"
    end
    description
  end

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

db.execute(query) {|row|
  last_event = visit_events.last
  # puts row
  event = VisitEvent.new(row)
  visit_events.push(event)

  # puts event.visit_time

  # look for overlaping events
  if (last_event and (last_event.visit_time + 180) > event.visit_time)
    visit_trails.last.add event
    next
  end

  visit_trail = VisitEventTrail.new
  visit_trail.add event
  visit_trails.push visit_trail
}

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
  f.write cal.to_ical
}