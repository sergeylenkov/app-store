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
            
      opts.on('-D', '--debug', 'Output debug info') do |v|
        @options[:debug] = D
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
      'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20',
      'Referer' => 'https://itunesconnect.apple.com%s' % action
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

    response, body = http.get2('/vendor_default.faces', headers)
        
    viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
    vendorName = /defaultVendorPage:j_id_jsp_[0-9]*_2/.match(body).to_s
    ajaxName = /j_id_jsp_[0-9]*_0/.match(body).to_s
        
    if @options[:debug]
      puts 'viewState: ' + viewState
      puts 'ajaxName: ' + ajaxName
      puts 'vendorName: ' + vendorName
      puts ''
    end
        
    headers = {
      'Cookie' => cookies.join('; '),
      'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
    }

    params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
                  'defaultVendorPage=defaultVendorPage', 
                  'javax.faces.ViewState=%s' % CGI::escape(viewState),
                  '%s=%s' % [CGI::escape(vendorName), CGI::escape(vendorName)]]

    if @options[:debug]
      puts params
      puts ''
    end

    response, body = http.post('/vendor_default.faces', params.join('&'), headers)
        
    http = Net::HTTP.new('reportingitc.apple.com', 443)
    http.read_timeout = 120
    http.open_timeout = 120
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    headers = {
      'Cookie' => cookies.join('; '),
      'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
    }

    response, body = http.get2('/dashboard.faces', headers)

    viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
    ajaxName = /theForm:j_id_jsp_[0-9]*_2/.match(body).to_s
    dailyName = /theForm:j_id_jsp_[0-9]*_23/.match(body).to_s
    selectName = /theForm:j_id_jsp_[0-9]*_31/.match(body).to_s
    formName = /theForm:j_id_jsp_[0-9]*_12/.match(body).to_s

    if @options[:debug]
      puts 'viewState: ' + viewState
      puts 'ajaxName: ' + ajaxName
      puts 'dailyName: ' + dailyName
      puts 'selectName: ' + selectName
      puts ''
    end

    headers = {
      'Cookie' => cookies.join('; '),
      'User-Agent' => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_3; en-us) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.1 Safari/525.20'
    }
    
    params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
              'theForm=theForm', 
              '%s=notnormal' % CGI::escape('theForm:xyz'),
              '%s=' % CGI::escape('theForm:hideval1'),
              '%s=true' % CGI::escape('theForm:loadIssueFlag'), 
              '%s=Music' % CGI::escape('theForm:prodtypesel'), 
              '%s=daily' % CGI::escape('theForm:selperiodId'), 
              '%s=Songs' % CGI::escape('theForm:subprodsel'), 
              '%s=songLabel' % CGI::escape('theForm:subprodlabel'), 
              '%s=' % CGI::escape('theForm:vendorLogin'), 
              'javax.faces.ViewState=%s' % CGI::escape(viewState),
              '%s=%s' % [CGI::escape(formName), CGI::escape(formName)],
              '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
              '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('08/14/2011')]]

    if @options[:debug]
      puts params
      puts ''
    end
    
    response, body = http.post('/dashboard.faces', params.join('&'), headers)
    
    params = ['dateType=daily', 
              'dtValue=%s' %CGI::escape(@options[:date])]
    
    response, body = http.post('/jsp/json_holder.faces', params.join('&'), headers)

    params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
              'theForm=theForm', 
              '%s=notnormal' % CGI::escape('theForm:xyz'),
              '%s=' % CGI::escape('theForm:hideval1'),
              '%s=true' % CGI::escape('theForm:loadIssueFlag'), 
              '%s=iOS' % CGI::escape('theForm:prodtypesel'), 
              '%s=daily' % CGI::escape('theForm:selperiodId'), 
              '%s=%s' % [CGI::escape('theForm:subprodsel'), CGI::escape('Free Apps')], 
              '%s=freeAppLabel' % CGI::escape('theForm:subprodlabel'), 
              '%s=' % CGI::escape('theForm:vendorLogin'),
              '%s=%s' % [CGI::escape('theForm:saletestid'), CGI::escape('theForm:saletestid')], 
              'javax.faces.ViewState=%s' % CGI::escape(viewState),
              '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
              '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('08/14/2011')]]
                
    response, body = http.post('/dashboard.faces', params.join('&'), headers)
    
    viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
    formName = /theForm:j_id_jsp_[0-9]*_32/.match(body).to_s

    params = ['theForm=theForm', 
              '%s=notnormal' % CGI::escape('theForm:xyz'), 
              '%s=Y' % CGI::escape('theForm:vendorType'),
              '%s=false' % CGI::escape('theForm:wklyBool'),
              '%s=A' % CGI::escape('theForm:optInVar'),
              '%s=D' % CGI::escape('theForm:dateType'),
              '%s=false' % CGI::escape('theForm:optInVarRender'),
              'javax.faces.ViewState=%s' % CGI::escape(viewState),
              '%s=%s' % [CGI::escape(formName), CGI::escape(formName)],
              '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
              '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('08/14/2011')]]

    if @options[:debug]
      puts params
      puts ''
    end

    response, body = http.post('/sales.faces', params.join('&'), headers)

    viewState = /"javax.faces.ViewState" value="(.*?)"/.match(body)[1]
    
    if @options[:debug]
      puts 'viewState: ' + viewState
      puts ''
    end
 
    ajaxName = /theForm:j_id_jsp_[0-9]*_2/.match(body).to_s
    formName = /theForm:j_id_jsp_[0-9]*_6/.match(body).to_s
 
    params = ['AJAXREQUEST=%s' % CGI::escape(ajaxName), 
              'theForm=theForm', 
              '%s=notnormal' % CGI::escape('theForm:xyz'), 
              '%s=Y' % CGI::escape('theForm:vendorType'),
              '%s=false' % CGI::escape('theForm:wklyBool'),
              '%s=A' % CGI::escape('theForm:optInVar'),
              '%s=D' % CGI::escape('theForm:dateType'),
              '%s=false' % CGI::escape('theForm:optInVarRender'),
              'javax.faces.ViewState=%s' % CGI::escape(viewState),
              '%s=%s' % [CGI::escape(formName), CGI::escape(formName)],
              '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
              '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('08/14/2011')]]

    if @options[:debug]
      puts params
      puts ''
    end

    response, body = http.post('/sales.faces', params.join('&'), headers)
    
    if @options[:debug]
      puts 'viewState: ' + viewState
      puts ''
    end

    params = ['theForm=theForm', 
              '%s=notnormal' % CGI::escape('theForm:xyz'), 
              '%s=Y' % CGI::escape('theForm:vendorType'),
              '%s=A' % CGI::escape('theForm:optInVar'),
              '%s=D' % CGI::escape('theForm:dateType'),
              '%s=false' % CGI::escape('theForm:optInVarRender'),
              '%s=false' % CGI::escape('theForm:wklyBool'),
              'javax.faces.ViewState=%s' % CGI::escape(viewState),
              '%s=%s' % [CGI::escape('theForm:downloadLabel2'), CGI::escape('theForm:downloadLabel2')],
              '%s=%s' % [CGI::escape('theForm:datePickerSourceSelectElementSales'), CGI::escape(@options[:date])],
              '%s=%s' % [CGI::escape('theForm:weekPickerSourceSelectElement'), CGI::escape('08/14/2011')]]

    if @options[:debug]
      puts params
      puts ''
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
        
    File.open(file, 'w') do |f| 
      f.write(body)
    end
  end
end

downloader = Downloader.new(ARGV)
downloader.download