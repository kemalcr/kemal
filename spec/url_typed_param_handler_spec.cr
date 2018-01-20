require "./spec_helper"

describe "UrlTypedParamHandler" do
  describe "#cast_as" do
    context "boolean values" do
      it "handles truthy values" do
        test1 = Kemal::UrlTypedParamHandler.cast_as(Bool, "true")
        test2 = Kemal::UrlTypedParamHandler.cast_as(Bool, "hey there")

        test1.should eq(true)
        test2.should eq(true)
      end

      it "handles falsey values" do
        test1 = Kemal::UrlTypedParamHandler.cast_as(Bool, "false")
        test2 = Kemal::UrlTypedParamHandler.cast_as(Bool, "f")

        test1.should eq(false)
        test2.should eq(false)
      end
    end

    context "integer values" do
      it "handles Int32 values" do
        test = Kemal::UrlTypedParamHandler.cast_as(Int32, "42")

        test.should eq(42)
      end
    end

    context "string values" do
      it "handles escaped values" do
        test = Kemal::UrlTypedParamHandler.cast_as(String, "lollar%2Bspec%40gmail.com")

        test.should eq("lollar+spec@gmail.com")
      end

      it "handles unescaped values" do
        test = Kemal::UrlTypedParamHandler.cast_as(String, "codalus")

        test.should eq("codalus")
      end
    end
  end
end
