require "./spec_helper"

{% if !flag?(:without_openssl) %}
  private def run_cli_eval(cli_args : String)
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(
      "crystal",
      [
        "eval",
        %(require "./src/kemal"; Kemal::CLI.new(#{cli_args})),
      ],
      output: output,
      error: error,
    )

    {status, output.to_s, error.to_s}
  end
{% end %}

describe "Kemal::CLI" do
  it "parses host binding with long option" do
    Kemal::CLI.new(["--bind", "127.0.0.1"])
    Kemal.config.host_binding.should eq("127.0.0.1")
  end

  it "parses host binding with short option" do
    Kemal::CLI.new(["-b", "192.168.1.10"])
    Kemal.config.host_binding.should eq("192.168.1.10")
  end

  it "parses port with long and short options" do
    Kemal::CLI.new(["--port", "4001"])
    Kemal.config.port.should eq(4001)

    Kemal::CLI.new(["-p", "5002"])
    Kemal.config.port.should eq(5002)
  end

  it "raises for non-numeric port values" do
    expect_raises(ArgumentError) do
      Kemal::CLI.new(["--port", "abc"])
    end
  end

  {% if !flag?(:without_openssl) %}
    it "fails when ssl is enabled but key file is missing" do
      status, _, stderr = run_cli_eval(%(["--ssl", "--ssl-cert-file", "cert.pem"]))

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when ssl is enabled but certificate file is missing" do
      status, _, stderr = run_cli_eval(%(["--ssl", "--ssl-key-file", "key.pem"]))

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL certificate file not specified")
    end

    it "fails when short ssl flag is used without key file" do
      status, _, stderr = run_cli_eval(%(["-s", "--ssl-cert-file", "cert.pem"]))

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when key file argument is empty" do
      status, _, stderr = run_cli_eval(%(["--ssl", "--ssl-key-file", "", "--ssl-cert-file", "cert.pem"]))

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL key file not specified")
    end

    it "fails when cert file argument is empty" do
      status, _, stderr = run_cli_eval(%(["--ssl", "--ssl-key-file", "key.pem", "--ssl-cert-file", ""]))

      status.success?.should be_false
      stderr.should contain("SSL configuration error: SSL certificate file not specified")
    end

    it "does not hit missing-file validation when both flags are present" do
      status, _, stderr = run_cli_eval(%(["--ssl", "--ssl-key-file", "key.pem", "--ssl-cert-file", "cert.pem"]))

      status.success?.should be_false
      stderr.should_not contain("SSL configuration error: SSL key file not specified")
      stderr.should_not contain("SSL configuration error: SSL certificate file not specified")
    end
  {% end %}
end
