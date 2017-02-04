require "./spec_helper"

describe "Run" do
  it "runs a code block after starting" do
    Kemal.config.env = "test"
    make_me_true = false
    Kemal.run do
      make_me_true = true
      Kemal.stop
    end
    make_me_true.should eq true
  end

  it "runs without a block being specified" do
    Kemal.config.env = "test"
    Kemal.run
    Kemal.config.running.should eq true
    Kemal.stop
  end

  it "runs with just a block" do
    Kemal.config.env = "test"
    make_me_true = false
    Kemal.run do
      make_me_true = true
      Kemal.stop
    end
    make_me_true.should eq true
  end
end
