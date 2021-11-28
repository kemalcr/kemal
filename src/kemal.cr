require "http"
require "json"
require "uri"
require "./kemal/*"
require "./kemal/ext/*"
require "./kemal/helpers/*"

module Kemal
  GLOBAL_APPLICATION = Kemal::Application
  CONFIG             = GLOBAL_APPLICATION.config

  def self.config
    yield CONFIG
  end

  def self.config : Kemal::Config
    CONFIG
  end

  def self.run(port : Int32?, args = ARGV)
    GLOBAL_APPLICATION.run(port, args)
  end

  def self.run(args = ARGV)
    GLOBAL_APPLICATION.run(args)
  end

  def self.run(args = ARGV)
    GLOBAL_APPLICATION.run(args) do |config|
      yield config
    end
  end

  def self.run(port : Int32? = nil, args = ARGV)
    GLOBAL_APPLICATION.run(port, args) do |config|
      yield config
    end
  end

  def self.stop
    GLOBAL_APPLICATION.stop
  end
end

include Kemal::Helpers::Global
include Kemal::Helpers::DSL::Global
include Kemal::Helpers::Macros
include Kemal::Helpers::Templates::Global
