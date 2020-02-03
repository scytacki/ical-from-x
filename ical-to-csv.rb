#!/usr/bin/env ruby

require 'rubygems'
require 'icalendar'
require 'csv'

dir = "/Volumes/GoogleDrive/My\ Drive/CCProjects/Timesheets/jan-2020"
# dir = "/Users/scytacki/Google Drive/CCProjects/Timesheets/jan-2020"

# Read in the ical file
cal_file = File.open("#{dir}/tasks.ics")

# Parser returns an array of calendars because a single file
# can have multiple calendars.
cals = Icalendar::Calendar.parse(cal_file)
cal = cals.first

#Write a CSV File
out_file = "#{dir}/tasks.csv"
CSV.open(out_file, 'w') do |csv|
  csv << ['start', 'end', 'hours', 'task', 'type', 'project']
  cal.events.each{|event|
    # the returned number is a rational and is the number of seconds difference
    hours = ((event.dtend-event.dtstart)/60/60).to_f
    csv << [event.dtstart.to_s, event.dtend.to_s, hours.to_s, event.summary]
  }
end
puts "Wrote: #{out_file}"
