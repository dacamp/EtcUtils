# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "test/unit"
require "etcutils"

# Platform detection
MACOS = RUBY_PLATFORM =~ /darwin/
LINUX = RUBY_PLATFORM =~ /linux/
WINDOWS = RUBY_PLATFORM =~ /mswin|mingw|cygwin/

class Test::Unit::TestCase
  def setup
    EtcUtils.reset!
  end

  def skip_on_macos(reason = "Not supported on macOS")
    omit(reason) if MACOS
  end

  def skip_on_linux(reason = "Not supported on Linux")
    omit(reason) if LINUX
  end

  def skip_on_windows(reason = "Not supported on Windows")
    omit(reason) if WINDOWS
  end

  def skip_unless_linux(reason = "Only available on Linux")
    omit(reason) unless LINUX
  end

  def skip_unless_macos(reason = "Only available on macOS")
    omit(reason) unless MACOS
  end
end
