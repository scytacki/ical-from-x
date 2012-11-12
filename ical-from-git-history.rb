#!/usr/bin/env ruby
#
# Man page doc for: git log
#   http://www.kernel.org/pub/software/scm/git/docs/git-log.html
#
require 'rubygems'
require 'trollop'
require 'icalendar'

devroot = '/Users/scytacki/Development/'
author = 'scytacki'

repositories = Dir.glob('/Users/scytacki/Development/*/.git').map{|dir| File.dirname dir}

# repositories = [
#   ['XPP', 'rigse'],
#   ['XPP', 'rails-ref-tree'],
#   ['XPP', 'rigse-rails3'],
#   ['XPP', 'rigse-1.9.3'],
#   ['XPP', 'sensors-hobo'],
#   ['ITSISU', 'rigse-itsisu'],
#   ['ITSISU', 'video-paper-builder'],
#   ['CLEAR', 'mysystem_sc'],
#   ['CLEAR', 'wise4-vagrant'],
#   ['CLEAR', 'MySystem-Wise-Integration-WIP'],
#   ['SG', 'hobo'],
#   ['SG', 'hobo-matrix'],
#   ['SG', 'hobo-polymorphic-list'],
#   ['SG', 'Smartgraphs'],
#   ['SG', 'smartgraphs-authoring'],
#   ['SG', 'smartgraphs-generator'],
#   ['GG', 'genigames-lc']
# ]

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int
  opt :year, 'Year to filter results with', :type => :int
  opt :out, 'Output file to put the resulting ics', :type => :string
end

date = Date.civil(options[:year], options[:month])
# git does not include the day itself so we need to go back one day
date -= 1
date_format = '%m/%d/%Y'
month_start = date.strftime(date_format)

class Commit
  attr_accessor :sha, :author_date, :commit_date, :summary, :repositories

  def initialize
    @repositories = []
  end

  def self.parse(line)
    commit = Commit.new
    commit.parse(line)
    commit
  end

  def parse(line)
    @sha, author_date_str, commit_date_str, @summary = line.split("\t");
    # Tue May 8 11:00:01 2012 -0400
    @author_date = DateTime.strptime(author_date_str, "%a %b %d %T %Y %z")
    @commit_date = DateTime.strptime(commit_date_str, "%a %b %d %T %Y %z")
  end

  def line
    "#{author_date} #{repositories} #{summary}"
  end

  def repositories_str
    repositories.map{|repo| File.basename repo}.join (" ,");
  end
end

commits = {}

repositories.each do |path|
  Dir.chdir(path) do
    commit_subjects = `git log HEAD --no-merges --reverse --since='#{month_start}' --pretty=format:"%H\t%ad\t%cd\t%s%n" --author=#{author}`
    commit_lines = commit_subjects.split(/\n+/)
    commit_lines.each{|commit_line|
      current_commit = Commit.parse(commit_line)
      commit = commits[current_commit.sha]
      if commit.nil?
        commit = current_commit
        commits[commit.sha] = commit
      end

      commit.repositories << path
    }
  end
end

cal = Icalendar::Calendar.new
duration = 10*60

commits.values.each do |commit|
  cal.event{
    dtstart (commit.author_date.to_time - duration).to_datetime
    dtend commit.author_date
    summary "#{commit.summary}"
    description "#{commit.summary} #{commit.repositories_str} #{commit.sha}"
  }
end

File.open(options[:out], 'w') {|f|
  f.write cal.to_ical
}