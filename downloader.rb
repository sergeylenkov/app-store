require 'rubygems'
require 'net/http'
require 'net/https'
require 'cgi'
require 'hpricot'
require 'optparse'
require 'pathname'

class Downloader
    def initialize(argv)
        @options = {}
        
        OptionParser.new do |opts|    
            opts.on('-v', '--verbose', 'Verbose output') do |v|
                @options[:verbose] = v
            end

            opts.on( '-u', '--user UID', 'Your Apple ID' ) do |u|
                @options[:user] = u
            end

            opts.on( '-p', '--password PASSWORD', 'Your password' ) do |p|
                @options[:password] = p
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
        
        http = Net::HTTP.new('itunesconnect.apple.com', 443)
        http.read_timeout = 120
        http.open_timeout = 120
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        headers = {
            'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
        }

        response, body = http.get2('/WebObjects/iTunesConnect.woa', headers)
        
        page = Hpricot(body)
        action = ''

        (page/'form').each do |item|
            if item.attributes['method'] == 'post'
                action = item.attributes['action']
            end
        end

        params = 'theAccountName=%s&theAccountPW=%s&1.Continue.x=45&1.Continue.y=17' % [@options[:user], @options[:password]]
        response, body = http.post(action, params)
        
        page = Hpricot(body)
        action = ''

        (page/'a').each do |item|
            if item.inner_html.include? 'Sales and Trends'
                action = item.attributes['href']
            end
        end

        cookies = []

        response.response.get_fields('Set-Cookie').each do |cookie|
            cookies << cookie.split(';')[0]
        end

        headers = {
          'Cookie' => cookies.join('; '),
          'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
        }

        if @options[:verbose]
            puts 'Open iTunes Connect'
        end
        
        response, body = http.get2(action, headers)
        
        http = Net::HTTP.new('reportingitc.apple.com', 443)
        http.read_timeout = 120
        http.open_timeout = 120
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        headers = {
            'Cookie' => cookies.join('; '),
            'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
        }

        response, body = http.get2('/', headers)

        response.response.get_fields('Set-Cookie').each do |cookie|
            cookies << cookie.split(';')[0]
        end
        
        if @options[:verbose]
            puts 'Downloading report for ' + @options[:date];
        end
        
        http = Net::HTTP.new('reportingitc.apple.com', 443)
        http.read_timeout = 120
        http.open_timeout = 120
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        headers = {
            'Cookie' => cookies.join('; '),
            'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
        }

        response, body = http.get2('/sales.faces', headers)

        viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
        ajaxName = /theForm:j_id_jsp_[0-9]*_2/.match(body).to_s
        dailyName = /theForm:j_id_jsp_[0-9]*_21/.match(body).to_s
        selectName = /theForm:j_id_jsp_[0-9]*_30/.match(body).to_s

        if @options[:verbose]
            puts 'viewState: ' + viewState
            puts 'ajaxName: ' + ajaxName
            puts 'dailyName: ' + dailyName
            puts 'selectName: ' + selectName
        end

        headers = {
            'Cookie' => cookies.join('; '),
            'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
        }

        params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
                  'theForm=theForm', 
                  '%s=notnormal' % CGI::escape('theForm:xyz'), 
                  '%s=Y' % CGI::escape('theForm:vendorType'),
                  'javax.faces.ViewState=%s' % CGI::escape(viewState),
                  '%s=%s' % [CGI::escape(dailyName), CGI::escape(dailyName)],
                  '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
                  '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('09/12/2010')]]

        if @options[:verbose]
            puts params
        end

        response, body = http.post('/sales.faces', params.join('&'), headers)

        viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
        
        if @options[:verbose]
            puts 'viewState: ' + viewState
        end

        params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
                  'theForm=theForm', 
                  '%s=notnormal' % CGI::escape('theForm:xyz'), 
                  '%s=Y' % CGI::escape('theForm:vendorType'),
                  'javax.faces.ViewState=%s' % CGI::escape(viewState),
                  '%s=%s' % [CGI::escape(selectName), CGI::escape(selectName)],
                  '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
                  '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
                  '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('09/12/2010')]]

        if @options[:verbose]
            puts params
        end

        response, body = http.post('/sales.faces', params.join('&'), headers)

        viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
        
        if @options[:verbose]
            puts 'viewState: ' + viewState
        end

        params = ['theForm=theForm', 
                  '%s=notnormal' % CGI::escape('theForm:xyz'), 
                  '%s=Y' % CGI::escape('theForm:vendorType'),
                  'javax.faces.ViewState=%s' % CGI::escape(viewState),
                  '%s=%s' % [CGI::escape('theForm:downloadLabel2'), CGI::escape('theForm:downloadLabel2')],
                  '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
                  '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
                  '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('09/12/2010')]]

        if @options[:verbose]
            puts params
        end

        response, body = http.post('/sales.faces', params.join('&'), headers)
        
        file = response.response['content-disposition'].split('=')[1]

        if @options[:dir]
            path = Pathname.new(@options[:dir])
            file = path.join(file)
        end
        
        if @options[:verbose]
            puts 'Downloaded file: ' + file
        end
        
        f = File.new(file, 'w')
        f.write(body)
    end
end

parser = Downloader.new(ARGV)
parser.download