require 'rubygems'
require 'net/http'
require 'net/https'
require 'cgi'
require 'date'
require 'optparse'
require 'pathname'

class Downloader
  def initialize(argv)
    @options = {}
        
    OptionParser.new do |opts|
      opts.on( '-u', '--user UID', 'Your Apple ID' ) do |u|
        @options[:user] = u
      end

      opts.on( '-p', '--password PASSWORD', 'Your password' ) do |p|
        @options[:password] = p
      end

      opts.on( '-v', '--vendor VENDOR_ID', 'Your vendor ID' ) do |v|
        @options[:vendor] = v
      end

      opts.on( '-d', '--date DATE', 'Date for downloading report in format mm/dd/yyyy' ) do |d|
        @options[:date] = d
      end
            
      opts.on( '-o', '--output DIR', 'Directory to downlaod report' ) do |o|
        @options[:dir] = o
      end
      
      opts.on('-h', '--help', 'Display this screen') do
        puts opts
        exit
      end
    end.parse!
  end
    
  def download
    if @options[:verbose]
      puts 'Login as ' + @options[:user]
    end
        
    http = Net::HTTP.new('reportingitc.apple.com', 443)
    http.read_timeout = 120
    http.open_timeout = 120
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    headers = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
    
    date = Date.parse(@options[:date]) #yyyyMMdd

    params = ['USERNAME=%s' % CGI::escape(@options[:user]),
              'PASSWORD=%s' % CGI::escape(@options[:password]),
              'VNDNUMBER=%s' % CGI::escape(@options[:vendor]), 
              'TYPEOFREPORT=%s' % 'Sales', 
              'DATETYPE=%s' % 'Daily', 
              'REPORTTYPE=%s' % 'Summary', 
              'REPORTDATE=%s' % CGI::escape(date.strftime('%Y%m%d'))]
      
    response, body = http.post('/autoingestion.tft?', params.join('&'), headers)
    
    if response['errormsg']
      puts response['errormsg']
    else
      puts 'Downloading report for %s' % date.to_s

      file = response['filename']

      if @options[:dir]
        path = Pathname.new(@options[:dir])
        file = path.join(file)
      end
        
      File.open(file, 'w') do |f| 
        f.write(body)
      end

      puts 'Downloaded file: ' + file
    end
  end
end

downloader = Downloader.new(ARGV)
downloader.download