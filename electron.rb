# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'nokogiri'

class Image
  attr_accessor :path

  def initialize(params)
    self.path = params[:path]
  end

  def two_digit_number
    path[/s-p(\d+).jpg/, 1]
  end
end

class Issue
  attr_accessor :path, :name

  def initialize(params)
    self.path = params[:path]
    self.name = params[:name]
  end

  def to_s
    "#{name} (#{path})"
  end

  def vol
    name[/Vol\.\ (\d+)/, 1]
  end

  def iss
    name[/No\. (\d+)/, 1]
  end
end

class AcornElectronSite
  BASE = 'https://www.acornelectron.co.uk/'
  ISSUES_PATH = 'https://www.acornelectron.co.uk/mags/electron/cats/eu.html'

  def issues
    puts "SCANNING #{ISSUES_PATH} FOR ISSUES"
    issues_html = Net::HTTP.get(URI.parse(ISSUES_PATH))
    issues_noko = Nokogiri::HTML(issues_html)

    issues_noko.css('.prof section div a + a').map do |anchor|
      Issue.new(path: URI.join(ISSUES_PATH, anchor['href']), name: anchor.content)
    end
  end

  def images_for_issue(issue)
    puts "SCANNING ISSUE #{issue.path} FOR IMAGES"
    issue_html = Net::HTTP.get(URI(issue.path))
    puts issue_html
    raise 'Stop'

    issue_noko = Nokogiri::HTML(issue_html)
    issue_noko.css('#prof center table tr td a').map do |anchor|
      Image.new path: URI.join(issue.path, anchor['href'])
    end
  end

  def two_digit(value)
    '%02d' % [value.to_i]
  end

  def copy_url_file_to_path(url, path)
    print "copying #{url} to #{path}... "
    IO.copy_stream(
      Net::HTTP.get(URI.parse(url)),
      path
    )
  rescue RuntimeError => e
    e.to_s
  end

  def suck!(into_directory)
    Dir.mkdir into_directory, 0o0755 unless Dir.exist? into_directory
    issues.each { |issue| process_issue(issue, into_directory) }
  end

  def process_issue(issue, into_directory)
    images_for_issue(issue).each { |image| process_image(image, into_directory) }
  end

  def process_image(image, into_directory)
    file_path = File.join into_directory,
                          "Electron_User_v#{two_digit(issue.vol)}_i#{two_digit(issue.iss)}_p#{image.two_digit_number}.jpg"
    if File.exist? file_path
      puts "#{file_path} exists... ...skip"
      continue
    end

    result = copy_url_file_to_path(image.path, file_path)
    puts result.is_a? Integer ? '...done' : result
  end
end

site = AcornElectronSite.new
site.suck! File.join(Dir.home, 'electron_user')
