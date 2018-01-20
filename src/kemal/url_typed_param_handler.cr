module Kemal
  # Casts the typed parameters passed in via the URL
  class UrlTypedParamHandler
    FALSEY_VALUES = ["false", "f"]

    def self.cast_as(type : Int64.class, value : String) : Int64
      type.new(value)
    end

    def self.cast_as(type : Bool.class, value : String) : Bool
      !FALSEY_VALUES.includes?(value)
    end

    def self.cast_as(type : String.class, value : String) : String
      value.size == 0 ? value : URI.unescape(value) rescue value
    end

    def self.cast_as(type : Float64.class, value : String) : Float64
      type.new(value)
    end
  end
end
