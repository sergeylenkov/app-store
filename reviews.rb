# encoding: utf-8
require 'rubygems'
require 'net/http'
require 'cgi'
require 'optparse'
require 'pathname'
require 'date'

class ReviewsParser
  def initialize(argv)
    @options = {}
        
    OptionParser.new do |opts|    
      opts.on('-v', '--verbose', 'Verbose output') do |v|
        @options[:verbose] = v
      end

      opts.on( '-a', '--application ID', 'Application ID' ) do |u|
        @options[:application] = u
      end
          
      opts.on( '-o', '--output PATH', 'File to save reviews' ) do |o|
        @options[:file] = o
      end
            
      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
    end.parse!
  end
    
  def parse
    stores = {
      143441 => "United States",
      143505 => "Argentina",
      143460 => "Australia",
      143446 => "België/Belgique",
      143503 => "Brazil",
      143455 => "Canada",
      143483 => "Chile",
      143465 => "China",
      143501 => "Colombia",
      143495 => "Costa Rica",
      143494 => "Croatia",
      143489 => "Czech Republic",
      143458 => "Denmark",
      143443 => "Deutschland",
      143508 => "Dominican Republic",
      143509 => "Ecuador",
      143516 => "Egypt",
      143506 => "El Salvador",
      143454 => "España",
      143518 => "Estonia",
      143447 => "Finland",
      143442 => "France",
      143448 => "Greece",
      143504 => "Guatemala",
      143510 => "Honduras",
      143463 => "Hong Kong",
      143482 => "Hungary",
      143467 => "India",
      143476 => "Indonesia",
      143449 => "Ireland",
      143491 => "Israel",
      143450 => "Italia",
      143511 => "Jamaica",
      143517 => "Kazakhstan",
      143466 => "Korea",
      143493 => "Kuwait",
      143519 => "Latvia",
      143497 => "Lebanon",
      143520 => "Lithuania",
      143451 => "Luxembourg",
      143515 => "Macau",
      143473 => "Malaysia",
      143468 => "México",
      143452 => "Nederland",
      143461 => "New Zealand",
      143512 => "Nicaragua",
      143457 => "Norway",
      143445 => "Österreich",
      143477 => "Pakistan",
      143485 => "Panamá",
      143513 => "Paraguay",
      143507 => "Perú",
      143474 => "Philippines",
      143478 => "Poland",
      143453 => "Portugal",
      143498 => "Qatar",
      143521 => "Republic of Malta",
      143523 => "Republic of Moldova",
      143487 => "Romania",
      143469 => "Russia",
      143479 => "Saudi Arabia",
      143459 => "Schweiz/Suisse",
      143464 => "Singapore",
      143496 => "Slovakia",
      143499 => "Slovenia",
      143472 => "South Africa",
      143486 => "Sri Lanka",
      143456 => "Sweden",
      143470 => "Taiwan",
      143475 => "Thailand",
      143480 => "Turkey",
      143481 => "United Arab Emirates",
      143444 => "United Kingdom",
      143514 => "Uruguay",
      143502 => "Venezuela",
      143471 => "Vietnam",
      143462 => "Japan",
      143524 => "Armenia",
      143525 => "Botswana",
      143526 => "Bulgaria",
      143528 => "Jordan",
      143529 => "Kenya",
      143530 => "Macedonia",
      143531 => "Madagascar",
      143532 => "Mali",
      143533 => "Mauritius",
      143534 => "Niger",
      143535 => "Senegal",
      143536 => "Tunisia",
      143537 => "Uganda"
    }
    
    reviews = []
          
    stores.each do |key, value|
      if @options[:verbose]
        puts 'Get reviews from %s' % value
      end
      
      http = Net::HTTP.new('itunes.apple.com', 80)
      http.read_timeout = 120
      http.open_timeout = 120

      headers = {
        'User-Agent' => 'iTunes/10.1.1 (Macintosh; Intel Mac OS X 10.6.6) AppleWebKit/533.19.4',
        'X-Apple-Store-Front' => '%s,12' % key,
        'X-Apple-Partner' => 'origin.0',
        'X-Apple-Connection-Type' => 'WiFi'
      }
        
      response, body = http.get2('/WebObjects/MZStore.woa/wa/customerReviews?update=1&id=%s&displayable-kind=11' % @options[:application], headers)

      pages = Integer(/total-number-of-pages='(.*)?'/.match(body)[1])
      
      if @options[:verbose]
        puts 'Pages count: %d' % pages
      end
        
      pages.times do |i|
        if @options[:verbose]
          puts 'Get page %d' % (i + 1)
        end
        
        page = download_reviews(@options[:application], key, i + 1)
        items = page.split('class="customer-review">')

        items.each do |item|
          clear_item = ''

          item.each_line do |line|
            line = line.strip

            if line.length > 0 
              clear_item = clear_item + line
            end
          end

          item = clear_item.strip;
                
          begin
            title = /<span class="customerReviewTitle">(.*?)<\/span>/.match(item)[1]
            text = /<p class="content.*?">(.*?)<\/p>/.match(item)[1]
            name = /<a href='.*' class="reviewer">(.*?)<\/a>/.match(item)[1]
            #rating = /<div class='rating' role='.*?' aria-label='.*?([0-9]).*?'>/.match(item)[1]
            rating = item.scan('"rating-star"').size

            temp = /<span class="user-info">.*?<\/a>(.*?)<\/span>/.match(item)[1]

            fields = temp.split("-")
            version = /([0-9].*)/.match(fields[1])[1]
                    
            fields.delete_at(0)
            fields.delete_at(0)
                    
            begin
              date = Date.parse(fields.join('-'))
            rescue => error            
              date = Time.now
            end
          
            reviews << '"%s";"%s";"%s";%s;%d;%s;"%s"' % [title, name, text, date.to_s, rating, version, value]
            
            if @options[:verbose]
              puts title + ' at ' + date.to_s
              puts text
              puts rating
              puts ''
            end
          rescue => error
            if @options[:verbose]
              puts error
            end
          end
        end
      end
      
      if @options[:verbose]
        puts ""
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
        puts "Reviews saved to #{file}"
      end
    else
      puts "No reviews"
    end
  end

  def download_reviews(application, store, page) 
    http = Net::HTTP.new('itunes.apple.com', 80)
    http.read_timeout = 120
    http.open_timeout = 120

    headers = {
            'User-Agent' => 'iTunes/10.1.1 (Macintosh; Intel Mac OS X 10.6.6) AppleWebKit/533.19.4',
            'X-Apple-Store-Front' => '%s,12' % store,
            'X-Apple-Partner' => 'origin.0',
            'X-Apple-Connection-Type' => 'WiFi'
    }

    response, body = http.get2('/WebObjects/MZStore.woa/wa/customerReviews?update=1&id=%s&displayable-kind=11&page=%d&sort=1' % [application, page], headers)
        
    return body
  end
end

parser = ReviewsParser.new(ARGV)
parser.parse
