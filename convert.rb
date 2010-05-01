# this is currently based on the rvm 1.9.1%timesheet

require 'rubygems'
require 'sqlite3'
require 'date'
require 'icalendar'

db = SQLite3::Database.new( "places.sqlite" )

year = 2010
month = 4
start_time = Time.local(year, month).to_i * 1000000
end_time = Time.local(year, month + 1).to_i * 1000000

# ["id", "from_visit", "place_id", "visit_date", "visit_type", "session", "id", "url", "title", 
#  "rev_host", "visit_count", "hidden", "typed", "favicon_id", "frecency", "last_visit_date"]
query = "select * from moz_historyvisits, moz_places " +
        "where moz_historyvisits.place_id=moz_places.id " + 
        "and moz_historyvisits.visit_date>#{start_time} " + 
        "and moz_historyvisits.visit_date<#{end_time}"
length = 0
cal = Icalendar::Calendar.new
db.execute(query) {|row|
  event_start = Time.at(row[3].to_i / 1000000)

  cal.event {
    puts event_start
    dtstart event_start.to_datetime
    dtend (event_start + 60).to_datetime
    summary row[8]
    url row[7]
  }
  length += 1
}

puts "length: #{length}"
File.open("history.ics", 'w') {|f|
  f.write cal.to_ical
}