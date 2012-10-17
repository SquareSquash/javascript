# Copyright 2012 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'json'

# An in-memory representation of a JavaScript source map.

class Squash::Javascript::SourceMap
  # @private
  VLQ_CONTINUATION_BIT = 1 << 5

  # @return [Array<Squash::Javascript::SourceMap::Mapping>] The individual
  #   mappings in this source map.
  attr_reader :mappings

  # @private
  def initialize(entries=[])
    @mappings = entries
    sort!
  end

  # Parses a JSON version-3 source map file and generates a SourceMap from it.
  #
  # @param [String] source_file A path to a source map file.
  # @param [String] route The URL where the compiled JavaScript asset is
  #   accessed.
  # @param [Hash] options Additional options.
  # @option options [String] :root If set, overrides the project root specified
  #   in the `sourceRoot` field with this root. Absolute paths will be converted
  #   into project-local paths (suitable for Git-blaming) using this root.

  def self.from_sourcemap(source_file, route, options={})
    fields = JSON.parse(File.read(source_file))
    raise "Only version 3 source maps are supported" unless fields['version'] == 3

    project_root = options[:root] || fields['sourceRoot'] or raise("Must specify a project root in the source map or method options")
    project_root << '/' unless project_root[-2..-1] == '/'

    route   = route
    sources = fields['sources'].map { |source| source.sub(/^#{Regexp.escape project_root}/, '') }
    names   = fields['names']

    mappings = fields['mappings'].split(';').map { |group| group.split ',' }
    entries  = Array.new

    source_file_counter   = 0
    source_line_counter   = 0
    source_column_counter = 0
    symbol_counter        = 0
    mappings.each_with_index do |group, compiled_line_number|
      compiled_column_counter = 0
      group.each do |segment|
        values                  = decode64vlq(segment)
        compiled_column_counter += values[0]
        source_file_counter += values[1] if values[1]
        source_line_counter += values[2] if values[2]
        source_column_counter += values[3] if values[3]
        symbol_counter += values[4] if values[4]
        entries << Mapping.new(
            route, compiled_line_number, compiled_column_counter,
            sources[source_file_counter], source_line_counter, source_column_counter,
            names[symbol_counter]
        )
      end
    end

    return new(entries)
  end

  # @private
  def <<(obj)
    @mappings << obj
    sort!
  end

  # Given the URL of a minified JavaScript asset, and a line and column number,
  # attempts to locate the original source file and line number.
  #
  # @param [String] route The URL of the JavaScript file.
  # @param [Fixnum] line The line number.
  # @param [Fixnum] column The character number within the line.

  def resolve(route, line, column)
    index   = 0
    mapping = nil
    while index < mappings.length
      entry = mappings[index]
      mapping = entry if entry.route == route && entry.compiled_line == line && entry.compiled_column <= column
      break if entry.route > route || entry.compiled_line > line
      index += 1
    end

    return mapping
  end

  private

  def sort!
    @mappings.sort_by! { |m| [m.route, m.compiled_line, m.compiled_column] }
  end

  def self.decode64vlq(string)
    bytes      = string.bytes.to_a
    byte_index = 0
    result     = []

    begin
      raise "Base-64 VLQ-encoded string unexpectedly terminated" if byte_index >= string.bytesize

      number       = 0
      continuation = false
      shift        = 0
      begin
        # each character corresponds to a 6-bit word
        digit        = decode64(bytes[byte_index])
        byte_index   += 1
        # the most significant bit is the continuation bit
        continuation = (digit & VLQ_CONTINUATION_BIT) != 0
        # the remaining bits are the number
        digit        = digit & (VLQ_CONTINUATION_BIT - 1)
        # continuations are little-endian
        number       += (digit << shift)
        shift        += 5
      end while continuation

      # the LSB is the sign bit
      number = (number & 1 > 0) ? -(number >> 1) : (number >> 1)
      result << number
    end while byte_index < string.bytesize

    return result
  end

  def self.decode64(byte)
    case byte
      when 65..90  then byte - 65 # A..Z => 0..25
      when 97..122 then byte - 71 # a..z => 26..51
      when 48..57  then byte + 4  # 0..9 => 52..61
      when 43      then 62        # + => 62
      when 47      then 63        # / => 63
      else raise "Invalid byte #{byte} in base-64 VLQ string"
    end
  end

  class Mapping
    attr_accessor :route, :compiled_line, :compiled_column, :source_file, :source_line, :source_column, :symbol

    def self.from_json(obj)
      new *obj
    end

    def initialize(route, compiled_line, compiled_column, source_file, source_line, source_column, symbol)
      @route           = route
      @compiled_line   = compiled_line
      @compiled_column = compiled_column
      @source_file     = source_file
      @source_line     = source_line
      @source_column   = source_column
      @symbol          = symbol
    end

    def as_json(options=nil)
      [route, compiled_line, compiled_column, source_file, source_line, source_column, symbol]
    end

    def to_json(options=nil)
      as_json.to_json
    end
  end
end
