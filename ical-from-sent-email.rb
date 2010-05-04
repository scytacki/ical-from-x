require 'rubygems'
require 'highline/import'
require 'icalendar'
require 'date'
require 'net/imap'

def get_password(prompt="Enter Password")
   ask(prompt) {|q| q.echo = false}
end

imap = Net::IMAP.new('imap.gmail.com', 993, true, nil, false)
imap.login('scytacki@concord.org', get_password())
imap.examine('[Gmail]/Sent Mail')
msgs = imap.search(["BEFORE", "1-May-2010", "SINCE", "1-Apr-2010"])
subjects = imap.fetch(msgs, "BODY[HEADER.FIELDS (SUBJECT)]")
dates = imap.fetch(msgs, "INTERNALDATE")

cal = Icalendar::Calendar.new

msgs.each_with_index{|id, idx|
  start_date = DateTime.parse(dates[idx].attr["INTERNALDATE"])
  # without the next line the start_date will be on GMT time 
  # but the end date will be on local time and the ical library
  # doesn't include the timezone when serializing the datetime
  start_date = start_date.to_time.to_datetime  
  end_date = (start_date.to_time + 8*60).to_datetime 
  puts "start #{start_date}"
  puts "end   #{end_date}"
  cal.event{
    dtstart start_date
    dtend end_date
    summary (subjects[idx].attr["BODY[HEADER.FIELDS (SUBJECT)]"]).strip.sub('Subject:', '')
  }    
}

File.open("sent.ics", 'w') {|f|
  f.write cal.to_ical
}