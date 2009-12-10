require "thin_parser"
require "stringio"

class InvalidRequest < IOError; end
 
  # A request sent by the client to the server.
class Request
  # Maximum request body size before it is moved out of memory
  # and into a tempfile for reading.
  MAX_BODY = 1024 * (80 + 32)
  BODY_TMPFILE = 'thin-body'.freeze
  MAX_HEADER = 1024 * (80 + 32)
  
  INITIAL_BODY = ''
  # Force external_encoding of request's body to ASCII_8BIT
  INITIAL_BODY.encode!(Encoding::ASCII_8BIT) if INITIAL_BODY.respond_to?(:encode)
  
  # Freeze some HTTP header names & values
  SERVER_SOFTWARE = 'SERVER_SOFTWARE'.freeze
  SERVER_NAME = 'SERVER_NAME'.freeze
  LOCALHOST = 'localhost'.freeze
  HTTP_VERSION = 'HTTP_VERSION'.freeze
  HTTP_1_0 = 'HTTP/1.0'.freeze
  REMOTE_ADDR = 'REMOTE_ADDR'.freeze
  CONTENT_LENGTH = 'CONTENT_LENGTH'.freeze
  CONNECTION = 'HTTP_CONNECTION'.freeze
  KEEP_ALIVE_REGEXP = /\bkeep-alive\b/i.freeze
  CLOSE_REGEXP = /\bclose\b/i.freeze
  
  # Freeze some Rack header names
  RACK_INPUT = 'rack.input'.freeze
  RACK_VERSION = 'rack.version'.freeze
  RACK_ERRORS = 'rack.errors'.freeze
  RACK_MULTITHREAD = 'rack.multithread'.freeze
  RACK_MULTIPROCESS = 'rack.multiprocess'.freeze
  RACK_RUN_ONCE = 'rack.run_once'.freeze
  ASYNC_CALLBACK = 'async.callback'.freeze
  ASYNC_CLOSE = 'async.close'.freeze

  # CGI-like request environment variables
  attr_reader :env

  # Unparsed data of the request
  attr_reader :data

  # Request body
  # attr_reader :body
  attr_accessor :messages

  def initialize
    @parser = Thin::HttpParser.new
    @data = ''
    @nparsed = 0
    @messages = "" #StringIO.new(INITIAL_BODY.dup)
    @env = {
      SERVER_SOFTWARE => "WebSocketThin",
      SERVER_NAME => LOCALHOST,

      # Rack stuff
      RACK_INPUT => @messages,

      RACK_VERSION =>  [1, 0].freeze, #VERSION::RACK,
      RACK_ERRORS => STDERR,

      RACK_MULTITHREAD => false,
      RACK_MULTIPROCESS => false,
      RACK_RUN_ONCE => false
    }
  end

  # Parse a chunk of data into the request environment
  # Raises a +InvalidRequest+ if invalid.
  # Returns +true+ if the parsing is complete.
  def parse(data)
    if @parser.finished? # Header finished, can only be some more body
      @messages << data
    else # Parse more header using the super parser
      @data << data
      raise InvalidRequest, 'Header longer than allowed' if @data.size > MAX_HEADER

      @nparsed = @parser.execute(@env, @data, @nparsed)

      # Transfert to a tempfile if body is very big
      # move_body_to_tempfile if @parser.finished? && content_length > MAX_BODY
    end

    if finished? # Check if header and body are complete
      @data = nil
      #@body.rewind
      true # Request is fully parsed
    else
      false # Not finished, need more data
    end
  end

  # +true+ if headers and body are finished parsing
  def finished?
    @parser.finished? && @messages.size >= content_length
  end

  # Expected size of the body
  def content_length
    @env[CONTENT_LENGTH].to_i
  end
end
