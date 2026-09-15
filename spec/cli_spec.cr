require "./spec_helper"

# Every way `Kemal::CLI` refuses an argument ends in `abort`, so it can only be
# observed from another process. Building the app once and running it with
# different arguments keeps the whole file to a single compile.
CLI_APP_SOURCE = <<-'CR'
  require "../src/kemal"

  Kemal::CLI.new(ARGV)
  puts "port=#{Kemal.config.port}"
  puts "host=#{Kemal.config.host_binding}"
  CR

CLI_APP_BINARY = File.tempname("kemal-cli-app")
at_exit { File.delete(CLI_APP_BINARY) if File.exists?(CLI_APP_BINARY) }

private def cli_app_binary : String
  return CLI_APP_BINARY if File.exists?(CLI_APP_BINARY)

  # Crystal resolves `require` relative to the requiring file, not the working
  # directory, so the source has to live next to the specs while it compiles.
  source = File.tempname("cli_app", ".cr", dir: __DIR__)
  File.write(source, CLI_APP_SOURCE)
  args = ["build", source, "-o", CLI_APP_BINARY]
  # The child has to be built the way this spec was, or a `without_openssl` run
  # would quietly exercise the OpenSSL path it is meant to exclude.
  {% if flag?(:without_openssl) %}
    args << "-Dwithout_openssl"
  {% end %}
  stderr = IO::Memory.new
  begin
    status = Process.run("crystal", args, error: stderr)
  ensure
    File.delete(source)
  end
  fail("could not build the cli app:\n#{stderr}") unless status.success?
  CLI_APP_BINARY
end

private def run_cli(args : Array(String))
  output = IO::Memory.new
  error = IO::Memory.new
  status = Process.run(cli_app_binary, args, output: output, error: error)

  {status, output.to_s, error.to_s}
end

describe "Kemal::CLI" do
  it "parses host binding with long option" do
    Kemal::CLI.new(["--bind", "127.0.0.1"])
    Kemal.config.host_binding.should eq("127.0.0.1")
  end

  it "parses host binding with short option" do
    Kemal::CLI.new(["-b", "192.168.1.10"])
    Kemal.config.host_binding.should eq("192.168.1.10")
  end

  # `Kemal.config` is global and nothing restores it between examples, so this
  # runs before the example that leaves a conventional port behind.
  it "parses port 0, which asks the operating system for a free port" do
    Kemal::CLI.new(["--port", "0"])
    Kemal.config.port.should eq(0)
  end

  it "parses port with long and short options" do
    Kemal::CLI.new(["--port", "4001"])
    Kemal.config.port.should eq(4001)

    Kemal::CLI.new(["-p", "5002"])
    Kemal.config.port.should eq(5002)
  end

  it "lets extra_options replace the invalid option handler" do
    seen = nil
    Kemal.config.extra_options do |parser|
      parser.invalid_option { |flag| seen = flag }
    end

    begin
      Kemal::CLI.new(["--bogus"])
      seen.should eq("--bogus")
    ensure
      Kemal.config.extra_options { }
    end
  end

  it "accepts the highest port bind_tcp takes" do
    status, stdout, _ = run_cli(["--port", "65535"])

    status.success?.should be_true
    stdout.should contain("port=65535")
  end

  it "rejects a port that is not an integer" do
    status, _, stderr = run_cli(["--port", "abc"])

    status.success?.should be_false
    stderr.should contain(%(Invalid port "abc": must be an integer between 0 and 65535.))
    stderr.should_not contain("Unhandled exception")
  end

  it "rejects a port above the range bind_tcp accepts" do
    status, _, stderr = run_cli(["--port", "70000"])

    status.success?.should be_false
    stderr.should contain(%(Invalid port "70000": must be an integer between 0 and 65535.))
    stderr.should_not contain("Unhandled exception")
  end

  it "rejects a negative port" do
    status, _, stderr = run_cli(["--port", "-1"])

    status.success?.should be_false
    stderr.should contain(%(Invalid port "-1": must be an integer between 0 and 65535.))
    stderr.should_not contain("Unhandled exception")
  end

  it "rejects a port padded with whitespace" do
    status, _, stderr = run_cli(["--port", " 8080"])

    status.success?.should be_false
    stderr.should contain(%(Invalid port " 8080": must be an integer between 0 and 65535.))
    stderr.should_not contain("Unhandled exception")
  end

  it "reports an unknown option with the usage banner" do
    status, _, stderr = run_cli(["--bogus"])

    status.success?.should be_false
    stderr.should contain("Invalid option: --bogus")
    stderr.should contain("-p PORT, --port PORT")
    stderr.should_not contain("Unhandled exception")
  end

  it "reports an option whose argument is missing with the usage banner" do
    status, _, stderr = run_cli(["-p"])

    status.success?.should be_false
    stderr.should contain("Missing argument for option: -p")
    stderr.should contain("-p PORT, --port PORT")
    stderr.should_not contain("Unhandled exception")
  end

  {% if !flag?(:without_openssl) %}
    it "fails when ssl is enabled but key file is missing" do
      status, _, stderr = run_cli(["--ssl", "--ssl-cert-file", "cert.pem"])

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when ssl is enabled but certificate file is missing" do
      status, _, stderr = run_cli(["--ssl", "--ssl-key-file", "key.pem"])

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL certificate file not specified")
    end

    it "fails when short ssl flag is used without key file" do
      status, _, stderr = run_cli(["-s", "--ssl-cert-file", "cert.pem"])

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when key file argument is empty" do
      status, _, stderr = run_cli(["--ssl", "--ssl-key-file", "", "--ssl-cert-file", "cert.pem"])

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when cert file argument is empty" do
      status, _, stderr = run_cli(["--ssl", "--ssl-key-file", "key.pem", "--ssl-cert-file", ""])

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL certificate file not specified")
    end

    it "does not hit missing-file validation when both flags are present" do
      status, _, stderr = run_cli(["--ssl", "--ssl-key-file", "key.pem", "--ssl-cert-file", "cert.pem"])

      status.success?.should be_false
      stderr.should_not contain("SSL configuration error: SSL key file not specified")
      stderr.should_not contain("SSL configuration error: SSL certificate file not specified")
    end
  {% end %}
end
