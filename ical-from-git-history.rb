#!/usr/bin/env ruby
#
# Man page doc for: git log
#   http://www.kernel.org/pub/software/scm/git/docs/git-log.html
#
require 'rubygems'
require 'trollop'
require 'icalendar'

# commandline option parsing, trollop is much more concise than optparse
options = Trollop::options do
  banner "Usage: #{$0} [options]"
  opt :month, 'Month to filter results with', :type => :int
  opt :year, 'Year to filter results with', :type => :int
  opt :out, 'Output file to put the resulting ics', :type => :string
  opt :author, 'Git author to search for', :type => :string
  opt :repositories, 'Paths to repositories to search', :type => :strings
end

date = Date.civil(options[:year], options[:month])
# git does not include the day itself so we need to go back one day
date -= 1
date_format = '%m/%d/%Y'
month_start = date.strftime(date_format)

class Commit
  attr_accessor :sha, :author_date, :commit_date, :summary, :repositories, :github_site

  def initialize
    @repositories = []
  end

  def self.parse(line)
    commit = Commit.new
    commit.parse(line)
    commit
  end

  def self.find_github_site(remotes)
    # look for github.com
    # could be like this:
    #   git@github.com:concord-consortium/rigse.git
    #   ssh://git@github.com/scytacki/sparkletest
    #   https://github.com/concord-consortium/rigse.git
    matches = /github.com[:\/]([^ .]*)(?:\.git| )/.match(remotes)
    if matches
      matches[1]
    else
      nil
    end
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

  def github_url
    if github_site
      "http://github.com/#{github_site}/commit/#{sha}"
    end
  end
end

commits = {}

options[:repositories].each do |path|
  Dir.chdir(path) do
    github_site = Commit.find_github_site `git remote -v`
    commit_subjects = `git log HEAD --no-merges --reverse --since='#{month_start}' --pretty=format:"%H\t%ad\t%cd\t%s%n" --author=#{options[:author]}`
    commit_lines = commit_subjects.split(/\n+/)
    commit_lines.each{|commit_line|
      current_commit = Commit.parse(commit_line)
      commit = commits[current_commit.sha]
      if commit.nil?
        current_commit.github_site = github_site
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
  cal.event do |e|
    e.dtstart = (commit.author_date.to_time - duration).to_datetime
    e.dtend = commit.author_date
    e.summary = "#{commit.summary}"
    description = "#{commit.summary} #{commit.repositories_str} #{commit.sha}"
    if commit.github_url
      e.url = commit.github_url
    end
  end
end

File.open(options[:out], 'w') {|f|
  f.write cal.to_ical
}
