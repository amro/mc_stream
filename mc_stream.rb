require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'gibbon'
require 'json'
require 'cgi'

class StreamHandlers
  @@handlers = []

  def self.handlers
    @@handlers
  end
end

class McStream < EM::Connection
  def post_init
    StreamHandlers.handlers << self
  end
    
  def receive_data(data)
    # begin
      parsed_data = JSON.parse(data)
      puts "Parsed Data: #{parsed_data}"
      
      case parsed_data["command"]
      when "reg"
        # api_key = parsed_data["api_key"]
        # list_id = parsed_data["list_id"]
        # 
        # Gibbon.new(api_key).list_webhook_add({:id => list_id, :url => "...", :sources => {:api => true}})
        # send_data({:status => "registered"}.to_json)
      when "quit"
        close_connection_after_writing
      else
        send_data(invalid_command)
      end
      
    # rescue
    #   send_data(invalid_command)
    # end
  end
  
  def invalid_command
    {:status => "invalid_command"}.to_json
  end
end

class WebhookServer < EventMachine::Connection
  include EventMachine::HttpServer

  def process_http_request
    resp = EventMachine::DelegatedHttpResponse.new( self )

    data = CGI::parse(@http_post_content)
    type = data["type"][0]
    email = data["data[email]"][0]

    # puts "Post body: #{data}"
    puts "Email #{email} has #{type}d"

    # Block which fulfills the request
    operation = proc do
      resp.status = 200
      resp.content = {:status => "weeee"}.to_json
    end

    # Callback block to execute once the request is fulfilled
    callback = proc do |res|
      StreamHandlers.handlers.each do |handler|
        handler.send_data({:action => type, :email => email}.to_json)
      end
      
      resp.send_response
    end

    # Let the thread pool (20 Ruby threads) handle request
    EM.defer(operation, callback)
  end
end

EventMachine.run do
  # hit Control + C to stop
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  EventMachine.start_server("0.0.0.0", 8888, McStream)
  EventMachine::start_server("0.0.0.0", 8081, WebhookServer)
  puts "Listening for Stream and Webhook Connections..."
end