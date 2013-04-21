require 'pp'
require 'open-uri'
require 'nokogiri'
require 'pdf-reader'

url = "http://www.misq.org/forthcoming/"

txt = ""
right_sec = false
open(url) do |wp|
  wp.each do |l|
    if right_sec
      if l =~ /hr-red\.gif/
        right_sec = false
      else
        txt += l
      end
    elsif l =~ /<h3>.*Research Articles/
      right_sec = true
    end
  end
end

doc = Nokogiri::HTML(txt)
doc.search('p').each do |p|
  authors = p.children[2].text.strip.gsub(' and ', ', ').gsub(/,\s*,/, ',').split(',').map {|auth| auth.strip}
  title = p.children[0].children[0].text.strip
  abs_url = url.sub(/([^\/])\/[^\/].*/, '\1') + p.children[0]["href"]
  abs = ""
  pdfreader = PDF::Reader.new(open(abs_url))
  pdfreader.pages.each do |page|
    abs = page.text
    abs = (abs.split(/Abstract\s*\n/))[1]
    abs = (abs.split(/\n\s*Keywords/))[0]
    abs.gsub!(/\n/,' ')
    abs.gsub!(/ +/, ' ')
    break
  end
end
