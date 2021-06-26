require "clip"

require "./blocker"
require "./chromecast"
require "./sponsorblock"

module Castblock
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Command
    include Clip::Mapper

    @debug : Bool? = nil
    @[Clip::Option("--offset")]
    @[Clip::Doc("When skipping a sponsor segment, jump to this number of seconds before " \
                "the end of the segment.")]
    @seek_to_offset = 0
    @[Clip::Option("--category")]
    @[Clip::Doc("The category of segments to block. It can be repeated to block multiple categories.")]
    @categories = ["sponsor"]

    def read_env
      # If a config option equals its default value, we try to read it from the env.
      # This is a temporary hack while waiting for Clip to handle it in a better way.
      if @debug.nil? && (debug = ENV["DEBUG"]?)
        @debug = debug.downcase == "true"
      end

      if @seek_to_offset == 0 && (seek_to_offset = ENV["OFFSET"]?)
        @seek_to_offset == seek_to_offset.to_i
      end

      if @categories == ["sponsor"] && (categories = ENV["CATEGORIES"]?)
        @categories = categories.split(',')
      end
    end

    def run : Nil
      read_env

      if @debug
        ::Log.setup(:debug)
      end

      begin
        sponsorblock = Sponsorblock.new(@categories.to_set)
      rescue Sponsorblock::CategoryError
        return
      end

      chromecast = Chromecast.new
      blocker = Blocker.new(chromecast, sponsorblock, @seek_to_offset)

      blocker.run
    end
  end

  def self.run
    begin
      command = Command.parse
    rescue ex : Clip::Error
      puts ex
      return
    end

    case command
    when Clip::Mapper::Help
      puts command.help
    else
      command.run
    end
  end
end

Castblock.run
