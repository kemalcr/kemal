require "./dsl_helper"

private def run(code)
  code = <<-CR
    require "./src/kemal"
    #{code}
    CR
  String.build do |stdout|
    stderr = String.build do |stderr|
      Process.new("crystal", ["eval"], input: IO::Memory.new(code), output: stdout, error: stderr).wait
    end
    unless stderr.empty?
      fail(stderr)
    end
  end
end

describe "Run" do
  it "runs a code block after starting" do
    Kemal.config.env = "test"
    make_me_true = false
    Kemal.run do
      make_me_true = true
      Kemal.stop
    end
    make_me_true.should be_true
  end

  it "runs without a block being specified" do
    Kemal.config.env = "test"
    Kemal.run
    Kemal.application.running?.should be_true
    Kemal.stop
  end
end
