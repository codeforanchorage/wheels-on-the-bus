#!/usr/bin/env ruby

=begin

TODO: Fix the route that is named differently across the two sites.  It's currently got a stop_id of 0 which is no good for the CSV.
TODO: Figure out which times on the schedule are bold because those are PM times and need to be set as such.

=end

#foreign keys
# trip_id (it's the route id)
# arrival_time
# departure_time
# stop_id
# stop_sequence


require 'nokogiri'
require 'open-uri'
require 'csv'

class Busses
  attr_reader :routeid, :all_stops, :main_stops
  
  def initialize(routenumber)
    @routeid = routenumber.to_s
    @all_stops = Nokogiri::XML(open("http://bustracker.muni.org/InfoPoint/map/GetRouteXml.ashx?routeNumber=#{@routeid}")).css('stop').map{ |s|
      stop = {:id => s['html'], :name => s['label'].force_encoding('UTF-8').gsub(/[[:space:]]+/, ' ').strip}
    }
    @schedules = Nokogiri::HTML(open("http://www.muni.org/Departments/transit/PeopleMover/Route%202012%20Schedules%20HTML/#{@routeid.rjust(3, '0')}.htm"))
    @main_stops = @schedules.css('table tr')[3].css('td').map {|s|
      s.text.force_encoding('UTF-8').gsub(/&/, 'and').gsub(/[[:space:]]+/, ' ').strip
    }
  end
  
  
  
  def find_separating_rows
    separating_rows = []
    @schedules.css('table tr').each_with_index{|r,index|
      if r.css('td')[0].text == "Weekday" or r.css('td')[0].text == "Saturday" or r.css('td')[0].text == "Sunday"
        separating_rows.push(index)
      end
    }
    return separating_rows
  end
  
  def read_stop_times
    stop_times = []
    separating_rows = find_separating_rows()
    if separating_rows.length < 3
      separating_rows.push(@schedules.css('table tr').length-1)
    end
    (separating_rows[0]+1..separating_rows[1]-1).each{|j|
      (0..@main_stops.length-1).each_with_index{|i,index|
        stop_times.push({
          :trip_id => @routeid.to_s + "W",
          :arrival_time => @schedules.css('table tr')[j].css('td')[i].text.force_encoding('UTF-8').gsub(/[[:space:]]+/, ' ').gsub(/\u2014/, '').rjust(5, '0') + ":00",
          :departure_time => @schedules.css('table tr')[j].css('td')[i].text.force_encoding('UTF-8').gsub(/[[:space:]]+/, ' ').gsub(/\u2014/, '').rjust(5, '0') + ":00",
          :stop_id => find_stop_id(index % @main_stops.length),
          :stop_sequence => index+1,
        })
      }
    }
    return stop_times
  end
  
  def find_stop_id(stop_sequence)
    @all_stops.each{|n|
      if n[:name].include? @main_stops[stop_sequence]
        return n[:id]
      end
    }
    return "0"
  end
end