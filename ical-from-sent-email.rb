require 'rubygems'
require 'highline/import'
require 'icalendar'
require 'date'
require 'net/imap'
require 'trollop'
require 'date'

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int
  opt :year, 'Year to filter results with', :type => :int
  opt :out, 'Output file to put the resulting ics', :type => :string
end

start_date = Date.civil(options[:year], options[:month])
imap_since = start_date.strftime("%d-%B-%Y")
end_date = start_date>>1
imap_before = end_date.strftime("%d-%B-%Y")

# "/Users/scytacki/Documents/CCProjects/Timesheets/june-2010/sent-mail.ics"
ics_file = options[:out]

def get_password(prompt="Enter Password")
   ask(prompt) {|q| q.echo = false}
end

imap = Net::IMAP.new('imap.gmail.com', 993, true, nil, false)
imap.login('scytacki@concord.org', get_password())
imap.examine('[Gmail]/Sent Mail')
msgs = imap.search(["BEFORE", imap_before, "SINCE", imap_since])
headers = imap.fetch(msgs, "BODY[HEADER.FIELDS (TO CC SUBJECT)]")
puts 'downloaded headers'
dates = imap.fetch(msgs, "INTERNALDATE")
puts 'downloaded dates'
bodies = imap.fetch(msgs, "BODY[TEXT]")
puts 'downloaded bodies'

cal = Icalendar::Calendar.new

msgs.each_with_index{|id, idx|
  start_date = DateTime.parse(dates[idx].attr["INTERNALDATE"])
  # without the next line the start_date will be on GMT time 
  # but the end date will be on local time and the ical library
  # doesn't include the timezone when serializing the datetime
  start_date = start_date.to_time.to_datetime  
  end_date = (start_date.to_time + 8*60).to_datetime 
  putc '.'
  # puts "start #{start_date} end   #{end_date}"
  cal.event{
    dtstart start_date
    dtend end_date
    msg_headers = (headers[idx].attr["BODY[HEADER.FIELDS (TO CC SUBJECT)]"]).strip.sub('Subject:', '')
    summary msg_headers
    
    description msg_headers + (bodies[idx].attr["BODY[TEXT]"]).strip
  }    
}

puts "finished"

# Icalendar::Component
# def to_ical
#       print_component do
#         s = ""
#         @components.each_value do |comps|
#           comps.each { |component| s << component.to_ical }
#         end
#         s
#       end
#     end
module Icalendar
  class Component
    def print_component_file(f)
      # Begin a new component
      f << "BEGIN:#{@name.upcase}\r\n"

      # Then the properties
      f <<  print_properties

      # sub components
      yield

      # End of this component
      f << "END:#{@name.upcase}\r\n"
    end
    
    def to_ical_file(f)
      print_component_file(f) do
         @components.each_value do |comps|
           comps.each { |component| component.to_ical_file(f) }
         end
      end
    end
  end
end


File.open(ics_file, 'w') {|f|
  cal.to_ical_file(f)
}