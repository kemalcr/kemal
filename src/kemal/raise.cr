module Kemal

  @@exceptions_raised = [] of Exception
  def self.exceptions_raised?
    @@exceptions_raised.size > 0
  end

  def self.raise(e : Exception)
    @@exceptions_raised << e
  end

  def self.log_exceptions(logger)
    @@exceptions_raised.each do |e|
      logger.write(e.to_s + "\n")
    end
  end

end
