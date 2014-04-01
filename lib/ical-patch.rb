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
