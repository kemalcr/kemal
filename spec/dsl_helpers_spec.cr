require "./dsl_helper"

describe "Macros" do
  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end

  describe "#logging" do
    it "sets logging status" do
      logging false
      Kemal.config.logging?.should be_false
    end

    it "sets a custom logger" do
      logger CustomLogHandler.new
      Kemal.application.logger.should be_a(CustomLogHandler)
    end
  end

  describe "#gzip" do
    it "adds HTTP::CompressHandler to handlers" do
      gzip true
      Kemal.application.setup
      Kemal.application.handlers[4].should be_a(HTTP::CompressHandler)
    end
  end

  describe "#serve_static" do
    it "should disable static file hosting" do
      serve_static false
      Kemal.config.serve_static.should be_false
    end

    it "should disble enable gzip and dir_listing" do
      serve_static({"gzip" => true, "dir_listing" => true})
      conf = Kemal.config.serve_static
      conf.is_a?(Hash).should be_true
      if conf.is_a?(Hash)
        conf["gzip"].should be_true
        conf["dir_listing"].should be_true
      end
    end
  end
end
