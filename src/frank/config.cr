module Frank
  class Config
    INSTANCE = Config.new
    property ssl
    property port

    def initialize
      @port = 3000
    end

    def scheme
      ssl ? "https" : "http"
    end
  end

  def self.config
    yield Config::INSTANCE
  end

  def self.config
    Config::INSTANCE
  end
end
