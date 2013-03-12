# encoding: utf-8
require 'rubygems'
require 'net/http'
require "net/https"
require "uri"
require 'cgi'
require 'optparse'
require 'pathname'
require 'date'
require 'hpricot'

class ReviewsParser
  def initialize(argv)
    @options = {}
        
    OptionParser.new do |opts|
      opts.on('-a', '--application ID', 'Application ID' ) do |u|
        @options[:application] = u
      end
          
      opts.on('-o', '--output PATH', 'File to save reviews' ) do |o|
        @options[:file] = o
      end
            
      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
    end.parse!
  end
    
  def parse
    countries = {
      "us" => "United States",
      "ar" => "Argentina",
      "au" => "Australia",
      "be" => "België/Belgique",
      "br" => "Brazil",
      "ca" => "Canada",
      "cl" => "Chile",
      "cn" => "China",
      "co" => "Colombia",
      "cr" => "Costa Rica",
      "hr" => "Croatia",
      "cz" => "Czech Republic",
      "dk" => "Denmark",
      "de" => "Deutschland",
      "do" => "Dominican Republic",
      "ec" => "Ecuador",
      "eg" => "Egypt",
      "sv" => "El Salvador",
      "es" => "España",
      "ee" => "Estonia",
      "fi" => "Finland",
      "fr" => "France",
      "gr" => "Greece",
      "gt" => "Guatemala",
      "hn" => "Honduras",
      "hk" => "Hong Kong",
      "hu" => "Hungary",
      "in" => "India",
      "id" => "Indonesia",
      "ie" => "Ireland",
      "il" => "Israel",
      "it" => "Italia",
      "jm" => "Jamaica",
      "kz" => "Kazakhstan",
      "kr" => "Korea",
      "kw" => "Kuwait",
      "lv" => "Latvia",
      "" => "Lebanon",
      "" => "Lithuania",
      "" => "Luxembourg",
      "" => "Macau",
      "" => "Malaysia",
      "" => "México",
      "" => "Nederland",
      "" => "New Zealand",
      "" => "Nicaragua",
      "" => "Norway",
      "" => "Österreich",
      "" => "Pakistan",
      "" => "Panamá",
      "" => "Paraguay",
      "" => "Perú",
      "" => "Philippines",
      "" => "Poland",
      "" => "Portugal",
      "" => "Qatar",
      "" => "Republic of Malta",
      "" => "Republic of Moldova",
      "" => "Romania",
      "ru" => "Russia",
      "" => "Saudi Arabia",
      "sz" => "Schweiz/Suisse",
      "" => "Singapore",
      "" => "Slovakia",
      "" => "Slovenia",
      "" => "South Africa",
      "" => "Sri Lanka",
      "se" => "Sweden",
      "" => "Taiwan",
      "" => "Thailand",
      "" => "Turkey",
      "" => "United Arab Emirates",
      "uk" => "United Kingdom",
      "" => "Uruguay",
      "" => "Venezuela",
      "" => "Vietnam",
      "jp" => "Japan",
      "" => "Armenia",
      "" => "Botswana",
      "" => "Bulgaria",
      "" => "Jordan",
      "" => "Kenya",
      "" => "Macedonia",
      "" => "Madagascar",
      "" => "Mali",
      "" => "Mauritius",
      "" => "Niger",
      "" => "Senegal",
      "" => "Tunisia",
      "" => "Uganda"
    }
    
    reviews = []
          
    countries.each do |key, value|
      puts 'Get reviews from %s' % value
    
      http = Net::HTTP.new("itunes.apple.com", 80)
      http.read_timeout = 120
      http.open_timeout = 120
      
      response, body = http.get2('/rss/customerreviews/page=1/id=%d/sortby=mostrecent/xml?cc=%s' % [@options[:application], key])
      
      last_page = 0

      doc = Hpricot::XML(body)
      
      (doc/:link).each do |link|
        url = link.attributes["href"].sub("http://itunes.apple.com/rss/customerreviews/", "").gsub("/", "&")
        params = CGI::parse(url)

        if link.attributes["rel"] == "last"
          if params['page'].empty?
            puts 'No reviews'
            last_page = 0
          else
            last_page = params['page'].first
          end
        end
      end

      if last_page == 0
        next
      end

      puts "Pages count %d" % last_page

      last_page.to_i.times do |i|
        response, body = http.get2('/rss/customerreviews/page=%d/id=%d/sortby=mostrecent/xml?cc=%s' % [i + 1, @options[:application], key])
        puts "  Get reviews from page %d" % (i + 1)
        doc = Hpricot::XML(body)
        
        (doc/:entry).each do |entry|
          if (entry/"id").first.attributes["im:id"].empty?
            id = (entry/"id").inner_html
            title = (entry/"title").inner_html
            name = (entry/"author/name").inner_html
            rating = (entry/"im:rating").inner_html
            version = (entry/"im:version").inner_html
            date = Date.parse((entry/"updated").inner_html)
            text = (entry/"content[@type='text']").inner_html
            html = (entry/"content[@type='html']").inner_html

            reviews << '%s;"%s";"%s";"%s";"%s";%d;%s' % [id, date.to_s, name, title, text, rating, version]
          end
        end
      end
    end
    
    if reviews.count > 0    
      if @options[:dir]
        file = Pathname.new(@options[:file])
      else
        file = Pathname.new(Time.now.to_s + '.txt')
      end
        
      File.open(file, 'w') do |f|        
        reviews.each do |review|
          f.write(review + "\r\n")
        end
      end
        
      if @options[:verbose]
        puts "Reviews saved to " + file
      end
    else
      puts "No reviews"
    end
  end
end

parser = ReviewsParser.new(ARGV)
parser.parse
