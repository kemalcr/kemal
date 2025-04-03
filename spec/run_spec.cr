require "./spec_helper"

private def run(code)
  code = <<-CR
    require "./src/kemal"
    #{code}
    CR

  stdout = IO::Memory.new
  stderr = IO::Memory.new
  status = Process.new("crystal", ["eval"], input: IO::Memory.new(code), output: stdout, error: stderr).wait
  fail(stderr.to_s) unless status.success?
  stdout.to_s
end

describe "Run" do
  it "runs a code block after starting" do
    run(<<-CR).should contain("started")
      Kemal.config.env = "test"
      Kemal.run do
        log "started"
      end
      CR
  end

  it "runs a code block after stopping" do
    run(<<-CR).should contain("stopped")
      Kemal.config.env = "test"
      Kemal.run do
        Kemal.stop
        log "stopped"
      end
      CR
  end

  it "runs without a block being specified" do
    run(<<-CR).should contain "[test] Kemal is running in test mode."
      Kemal.config.env = "test"
      Kemal.run
      Kemal.config.running
      CR
  end

  it "allows custom HTTP::Server bind" do
    run(<<-CR).should contain "[test] Kemal is running in test mode."
      Kemal.config.env = "test"
      Kemal.run do |config|
        server = config.server.not_nil!

        {% if flag?(:windows) %}
          server.bind_tcp "127.0.0.1", 3000
        {% else %}
          server.bind_tcp "127.0.0.1", 3000, reuse_port: true
          server.bind_tcp "0.0.0.0", 3001, reuse_port: true
        {% end %}
      end
      CR
  end
end
