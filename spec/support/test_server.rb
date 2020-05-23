require "webrick"

class TestServer
  def initialize(port:)
    logger = new_logger

    @server = WEBrick::HTTPServer.new(
      Port: port,
      Logger: logger,
      AccessLog: [
        [logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT]
      ],
    )
  end

  def start
    @thread = Thread.new { @server.start }
    @thread.abort_on_exception = true
    self
  end

  def stop
    @server.stop
    @thread.join
  end

  def handle(path, &block)
    @server.mount_proc(path, &block)
    self
  end

  private

  def new_logger
    level = ENV.key?("DEBUG") ? WEBrick::BasicLog::DEBUG : WEBrick::BasicLog::FATAL
    WEBrick::Log::new(nil, level)
  end
end
