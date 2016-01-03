require "./spec_helper"

describe "Macros" do
  describe "#basic_auth" do
    it "adds HTTPBasicAuthHandler" do
      basic_auth "serdar", "123"
      Kemal.config.handlers.size.should eq 1
    end
  end

  describe "#public_folder" do
    it "sets public folder" do
      public_folder "/some/path/to/folder"
      Kemal.config.public_folder.should eq("/some/path/to/folder")
    end
  end
end
