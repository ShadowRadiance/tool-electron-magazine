require 'open-uri'
require 'nokogiri'

class Image
  attr_accessor :path
  def initialize(params)
    self.path = params[:path]
  end
  def two_digit_number
    path[/s-p(\d+).jpg/,1]
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
    name[/Vol\.\ (\d+)/,1]
  end
  def iss
    name[/No\. (\d+)/,1]
  end
end

class AcornElectronSite
  BASE = "http://www.acornelectron.co.uk/"
  ISSUES_PATH = "http://www.acornelectron.co.uk/mags/eu/top_lvl.html"
  
  def absolute_url(base, url)
    URI.join(base, url).to_s
  end
  
  def issue_name_from_anchor(anchor)
    (anchor > "img").attribute("alt").to_s
  end
  
  def issues
    issues_html = open(ISSUES_PATH, &:read)
    issues_noko = Nokogiri::HTML(issues_html)
    issues_noko.css("#prof center table tr td a").map do |anchor|      
      Issue.new path: absolute_url(ISSUES_PATH, anchor['href']),
                name: issue_name_from_anchor(anchor)
    end
  end
  
  # def mapped_issues
  #   mapped = {}
  #   issues.each do |issue|
  #     mapped[issue.vol] ||= {}
  #     mapped[issue.vol][issue.iss] = issue
  #   end
  #   mapped
  # end
  
  def images_for_issue(issue)
    issue_html = open(issue.path, &:read)
    issue_noko = Nokogiri::HTML(issue_html)
    issue_noko.css("#prof center table tr td a").map do |anchor|
      Image.new path: absolute_url(issue.path, anchor['href'])
    end
  end
  
  def two_digit(value)
    '%02d' % [value.to_i]
  end
  
  def copy_url_file_to_path(url, path)
    IO.copy_stream(open(url), path)
  rescue OpenURI::HTTPError => e
    "#{e}"
  end
  
  def suck!(into_directory)
    Dir.mkdir into_directory, 0755 unless Dir.exist? into_directory
    issues.each do |issue|
      images_for_issue(issue).each do |image|
        file_path = File.join into_directory, 
          "Electron_User_v#{two_digit(issue.vol)}_i#{two_digit(issue.iss)}_p#{image.two_digit_number}.jpg"
        if File.exists? file_path
          puts "#{file_path} exists... ...skip"
        else
          print "copying #{image.path} to #{file_path}... "
          copy_url_file_to_path(image.path, file_path).tap do |result|
            case result
            when Fixnum
              puts "...done"
            else
              puts result
            end
          end
        end
      end
    end
  end
end

site = AcornElectronSite.new
site.suck! File.join(Dir.home, "electron_user")

