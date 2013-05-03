require 'sequel'
require 'open-uri'
require 'nokogiri'
require 'pdf-reader'

class Journal
  def initialize(code, publisher, url)
    @code = code
    @publisher = publisher
    @url = url
  end

  def check(articles, authors, abstracts)
    case @publisher
    when "informs"
      puts "checking #{@code}"
      check_informs(articles, authors, abstracts)
    when "misq"
      puts "checking #{@code}"
      check_misq(articles, authors, abstracts)
    else
      puts "sorry, i don't know how to check #{@publisher} journals"
    end
  end

  :private
  def check_informs(articles, authors, abstracts)
    doc = Nokogiri::HTML(open(@url))
    doc.search('div[@class="cit is-early-release has-earlier-version"]').each do |p|
      # get article info
      title = ""
      p.xpath('div[@class="cit-metadata"]/span[@class="cit-title"]').each do |t|
	title = t.text.strip
      end
      doi = ""
      p.xpath('div[@class="cit-metadata"]/cite/span[@class="cit-doi"]').each do |cdoi|
	doi = cdoi.text.sub(/^doi: */, '')
      end
      idx = articles.max(:idx)
      articles.insert_ignore.insert(:code => @code, :doi => doi, :title => title)
      if idx == articles.max(:idx)
	next
      end
      idx = articles.max(:idx)
      # get abstract
      abs_url = ""
      p.xpath('div[@class="cit-extra"]/ul/li[@class="first-item"]/a').each do |a|
	abs_url = a["href"]
      end
      abs_url = @url.sub(/([^\/]\/)[^\/].*/, '\1') + abs_url
      abs_doc = Nokogiri::HTML(open(abs_url))
      abs = ""
      abs_doc.search('p[@id="p-1"]').each do |ap|
	abs = ap.text
	abs.gsub!(/\s*\n\s*/, ' ')
	abs.strip!
	break
      end
      abstracts.insert_ignore.insert(:idx => idx, :abstract => abs)
      # get authors
      p.xpath('div[@class="cit-metadata"]/ul/li/span[@class="cit-auth cit-auth-type-author"]').each do |auth|
	auth = auth.text
	authors.insert_ignore.insert(:idx => idx, :author => auth)
      end
    end
  end

  def check_misq(articles, authors, abstracts)
    # get the right portion of the page
    txt = ""
    right_sec = false
    open(@url) do |wp|
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
    # parse papers
    doc = Nokogiri::HTML(txt)
    doc.search('p').each do |p|
      auths = p.children[2].text.strip.gsub(' and ', ', ').gsub(/,\s*,/, ',').split(',').map {|auth| auth.strip}
      title = p.children[0].children[0].text.strip
      abs_url = @url.sub(/([^\/])\/[^\/].*/, '\1') + p.children[0]["href"]
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
      # insert
      idx = articles.max(:idx)
      articles.insert_ignore.insert(:code => @code, :title => title)
      if idx == articles.max(:idx)
	next
      end
      idx = articles.max(:idx)
      abstracts.insert_ignore.insert(:idx => idx, :abstract => abs)
      auths.each do |auth|
	authors.insert_ignore.insert(:idx => idx, :author => auth)
      end
    end
  end
end
