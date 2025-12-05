# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "test/unit"
require "etcutils"

# Platform detection
MACOS = RUBY_PLATFORM =~ /darwin/
LINUX = RUBY_PLATFORM =~ /linux/
WINDOWS = RUBY_PLATFORM =~ /mswin|mingw|cygwin/

# Check if C extension is loaded (v1 classes vs v2 Struct-based classes)
V2_STRUCTS_AVAILABLE = !defined?(V1_EXTENSION_LOADED) || !V1_EXTENSION_LOADED

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

  def skip_if_v1_extension(reason = "Test requires v2 Struct-based classes")
    omit(reason) unless V2_STRUCTS_AVAILABLE
  end
end
