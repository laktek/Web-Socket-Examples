require "rubygems"
require "eventmachine"
require "request"
require "headers"

  module ServerMethods
    def post_init
      puts "Received a new connection"
      @request = Request.new
      @msg_buffer = BufferedTokenizer.new("\377") 
      @state = :handshake
    end

    def receive_data(data)
     process if @request.parse(data)
 #    puts @request.env.inspect
 #    puts @request.body

     rescue InvalidRequest => e
       log "!! Invalid request"
       log_error e
       close_connection
    end

    def process
      case @state
      when :handshake
        send_handshake
        @state = :message
      when :message
        #assign a single thread to process of the messages of the given user
        EventMachine.defer(method(:process_message), method(:post_process))
      end
    end

    def send_handshake
      headers = Headers.new
      headers['Upgrade'] = "WebSocket"
      headers['Connection'] = "Upgrade"
      headers['WebSocket-Origin'] = @request.env["HTTP_ORIGIN"]
      headers['WebSocket-Location'] = "ws://#{@request.env["HTTP_HOST"]}/"

      result = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n#{headers.to_s}\r\n"
      puts "sending handshake..."
      send_data(result)
    end

    def process_message
      puts "processing messages"
      output = []

      #this will go thru all messages in stack
      @msg_buffer.extract(@request.messages).each do |msg|
        puts "received #{msg}"
        output << msg  
      end

      output
    end

    def post_process(result)
      puts "sending #{result.join}"
      result.each {|msg| send_data("\000#{msg}\377") }

      #clears the body after processing messages
      @request.messages = ""
    end

  end

  EventMachine::run {
    EventMachine::start_server "localhost", 2200, ServerMethods 
  }
