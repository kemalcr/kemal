module Kemal
  # Casts the typed parameters passed in via the URL
  class UrlTypedParamHandler
    FALSEY_VALUES = ["false", "f"]

    def self.cast_as(type : Int32.class, value : String)
      type.new(value)
    end

    def self.cast_as(type : Bool.class, value : String)
      !FALSEY_VALUES.includes?(value)
    end

    def self.cast_as(type : String.class, value : String)
      value.size == 0 ? value : URI.unescape(value) rescue value
    end
  end
end
