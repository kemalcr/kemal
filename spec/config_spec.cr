require "./spec_helper"

describe "Config" do
  it "sets default port to 3000" do
    config = Kemal::Config.new
    config.port.should eq 3000
  end

  it "sets default environment to development" do
    config = Kemal::Config.new
    config.env.should eq "development"
  end

  it "sets environment to production" do
    config = Kemal::Config.new
    config.env = "production"
    config.env.should eq "production"
  end

  it "sets host binding" do
    config = Kemal::Config.new
    config.host_binding = "127.0.0.1"
    config.host_binding.should eq "127.0.0.1"
  end

  it "adds a custom handler" do
    application = Kemal::Base.new
    application.add_handler CustomTestHandler.new
    application.setup
    application.handlers.size.should eq(8)
  end

  it "toggles the shutdown message" do
    config = Kemal::Config.new
    config.shutdown_message = false
    config.shutdown_message?.should be_false
    config.shutdown_message = true
    config.shutdown_message?.should be_true
  end

  it "adds custom options" do
    config = Kemal::Config.new
    ARGV.push("--test")
    ARGV.push("FOOBAR")
    test_option = nil

    config.extra_options do |parser|
      parser.on("--test TEST_OPTION", "Test an option") do |opt|
        test_option = opt
      end
    end
    Kemal::CLI.new(config)
    test_option.should eq("FOOBAR")
  end
end
