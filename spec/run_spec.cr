require "./spec_helper"

private def run(code)
  code = <<-CR
    require "./src/kemal"

    Kemal.config.env = "test"
    Kemal.config.port = 8000

    #{code}
    CR

  stdout = IO::Memory.new
  stderr = IO::Memory.new
  status = Process.new("crystal", ["eval"], input: IO::Memory.new(code), output: stdout, error: stderr).wait
  fail(stderr.to_s) unless status.success?
  stdout.to_s
end

# `crystal eval` runs the compiled program as a child of the compiler, and a signal
# sent to the compiler is not passed on, so the shutdown specs build the app once
# and start the binary itself - what gets `SIGTERM` has to be the app.
#
# The app listens on an ephemeral port and serves `/slow`, which takes `SLOW_MS` to
# answer. The port goes to stdout as soon as it accepts connections, so a spec can
# start a request before it sends the signal.
SHUTDOWN_APP_SOURCE = <<-'CR'
  require "../src/kemal"

  Kemal.config.env = "development"
  Kemal.config.logging = false
  Kemal.config.shutdown_timeout = ENV["SHUTDOWN_TIMEOUT_MS"].to_i.milliseconds

  get "/slow" do
    sleep ENV["SLOW_MS"].to_i.milliseconds
    "done"
  end

  Kemal.run(args: nil) do |config|
    server = config.server.not_nil!
    server.bind_tcp "127.0.0.1", 0
    puts "port=#{server.addresses.first.as(Socket::IPAddress).port}"
    STDOUT.flush
  end

  puts "run returned with #{Kemal::InitHandler::INSTANCE.in_flight} in flight"
  CR
SHUTDOWN_APP_BINARY = File.tempname("kemal-shutdown-app")
at_exit { File.delete(SHUTDOWN_APP_BINARY) if File.exists?(SHUTDOWN_APP_BINARY) }

private def shutdown_app_binary : String
  return SHUTDOWN_APP_BINARY if File.exists?(SHUTDOWN_APP_BINARY)

  # Crystal resolves `require` relative to the requiring file, not the working
  # directory, so the source has to live next to the specs while it compiles.
  source = File.tempname("shutdown_app", ".cr", dir: __DIR__)
  File.write(source, SHUTDOWN_APP_SOURCE)
  stderr = IO::Memory.new
  begin
    status = Process.run("crystal", ["build", source, "-o", SHUTDOWN_APP_BINARY], error: stderr)
  ensure
    File.delete(source)
  end
  fail("could not build the shutdown app:\n#{stderr}") unless status.success?
  SHUTDOWN_APP_BINARY
end

# Starts the shutdown app with the given `shutdown_timeout` and `/slow` duration,
# yields its port once it accepts connections, and returns the process for the
# caller to signal and wait on. Every read of the process has a deadline, so a
# regression here fails the spec instead of hanging the suite.
private def run_listening(shutdown_timeout : Time::Span, slow : Time::Span, &)
  env = {
    "SHUTDOWN_TIMEOUT_MS" => shutdown_timeout.total_milliseconds.to_i.to_s,
    "SLOW_MS"             => slow.total_milliseconds.to_i.to_s,
  }
  process = Process.new(shutdown_app_binary, env: env, output: :pipe, error: :pipe)

  port = nil
  while line = process.output.gets
    if match = line.match(/^port=(\d+)/)
      port = match[1].to_i
      break
    end
  end
  unless port
    process.terminate rescue nil
    fail("app never reported its port:\n#{process.error.gets_to_end}")
  end

  yield port
  process
end

# Waits for the process to exit, killing it if it takes longer than *limit* so the
# suite never hangs on a shutdown that did not happen. Returns stdout, stderr, and
# whether it exited on its own.
private def finish(process : Process, limit : Time::Span = 15.seconds) : {String, String, Bool}
  stdout = IO::Memory.new
  stderr = IO::Memory.new
  spawn { IO.copy(process.output, stdout) rescue nil }
  spawn { IO.copy(process.error, stderr) rescue nil }

  exited = Channel(Bool).new
  spawn { exited.send(process.wait.success?) }
  select
  when success = exited.receive
    {stdout.to_s, stderr.to_s, success}
  when timeout(limit)
    process.signal(Signal::KILL) rescue nil
    exited.receive
    {stdout.to_s, stderr.to_s, false}
  end
end

# Asks for `/slow` in the background; the channel delivers the response, or the
# error the client saw instead.
private def slow_request(port : Int32) : Channel(HTTP::Client::Response | Exception)
  result = Channel(HTTP::Client::Response | Exception).new
  spawn do
    result.send(HTTP::Client.get("http://127.0.0.1:#{port}/slow"))
  rescue ex
    result.send(ex)
  end
  result
end

describe "Run" do
  it "runs a code block after starting" do
    run(<<-CR).should contain("started")
      Kemal.run do
        log "started"
      end
      CR
  end

  it "runs a code block after stopping" do
    run(<<-CR).should contain("stopped")
      Kemal.run do
        Kemal.stop
        log "stopped"
      end
      CR
  end

  it "runs without a block being specified" do
    run(<<-CR).should contain "[test] Kemal is running in test mode."
      Kemal.run
      Kemal.config.running
      CR
  end

  it "returns from a stop at once when nothing is in flight" do
    output = run(<<-'CRYSTAL')
      Kemal.config.shutdown_timeout = 5.seconds

      elapsed = Time.measure do
        Kemal.run do
          Kemal.stop
        end
      end

      puts "elapsed_ms=#{elapsed.total_milliseconds}"
      CRYSTAL

    match = output.match!(/elapsed_ms=([0-9]+(?:\.[0-9]+)?)/)
    match[1].to_f.should be < 1000.0
  end

  {% unless flag?(:windows) %}
    it "finishes the requests in flight before exiting on SIGTERM" do
      result = nil
      process = run_listening(shutdown_timeout: 5.seconds, slow: 500.milliseconds) do |port|
        result = slow_request(port)
        sleep 100.milliseconds
      end
      process.signal(Signal::TERM)
      stdout, stderr, exited = finish(process)

      exited.should be_true
      response = result.not_nil!.receive
      response.should be_a(HTTP::Client::Response)
      response = response.as(HTTP::Client::Response)
      response.status_code.should eq(200)
      response.body.should eq("done")
      stdout.should contain("run returned with 0 in flight")
      stdout.should_not contain("still in flight")
    end

    it "gives up on requests still in flight when shutdown_timeout is over" do
      result = nil
      process = run_listening(shutdown_timeout: 300.milliseconds, slow: 10.seconds) do |port|
        result = slow_request(port)
        sleep 100.milliseconds
      end
      process.signal(Signal::TERM)
      stdout = stderr = ""
      exited = false
      elapsed = Time.measure { stdout, stderr, exited = finish(process) }

      exited.should be_true
      elapsed.should be < 5.seconds
      stdout.should contain("run returned with 1 in flight")
      stdout.should contain("1 request(s) still in flight after")
      result.not_nil!.receive.should be_a(Exception)
    end

    it "exits at once on a second SIGTERM during the drain" do
      result = nil
      process = run_listening(shutdown_timeout: 10.seconds, slow: 10.seconds) do |port|
        result = slow_request(port)
        sleep 100.milliseconds
      end
      process.signal(Signal::TERM)
      sleep 200.milliseconds
      process.signal(Signal::TERM)
      exited = false
      elapsed = Time.measure { _, _, exited = finish(process) }

      exited.should be_true
      elapsed.should be < 5.seconds
      result.not_nil!.receive.should be_a(Exception)
    end
  {% end %}

  it "allows custom HTTP::Server bind" do
    run(<<-CR).should contain "[test] Kemal is running in test mode."
      Kemal.run do |config|
        server = config.server.not_nil!

        {% if flag?(:windows) %}
          server.bind_tcp "127.0.0.1", 8000
        {% else %}
          server.bind_tcp "127.0.0.1", 8000, reuse_port: true
          server.bind_tcp "0.0.0.0", 8001, reuse_port: true
        {% end %}
      end
      CR
  end
end
