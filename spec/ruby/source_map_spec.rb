# Copyright 2013 Square Inc.
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

require 'ruby/spec_helper'
require 'yaml'

root = File.expand_path(File.join(File.basename(__FILE__), '..'))
root = Pathname(root)

describe Squash::Javascript::SourceMap do
  describe ".from_sourcemap" do
    it "should return an array of Mapping objects" do
      mappings = Squash::Javascript::SourceMap.from_sourcemap(root.join('spec', 'ruby', 'fixtures', 'mapping.json'), '/example/file.js')
      expect(mappings.to_yaml).to eql(File.read(root.join('spec', 'ruby', 'fixtures', 'mapping.yml')))
    end

    it "should allow the sourceRoot field to override the given root" do
      mappings = Squash::Javascript::SourceMap.from_sourcemap(root.join('spec', 'ruby', 'fixtures', 'mapping.json'), '/another/file.js', root: "/Documents/Projects/SquareSquash")
      expect(mappings.to_yaml).to eql(File.read(root.join('spec', 'ruby', 'fixtures', 'custom_root.yml')))
    end
  end

  describe "#resolve" do
    before :all do
      @map = Squash::Javascript::SourceMap.from_sourcemap(root.join('spec', 'ruby', 'fixtures', 'mapping.json'), '/example/file.js')
    end

    it "should return the closest matching file, line, and column" do
      entry = @map.resolve('/example/file.js', 0, 0)
      expect(entry.source_file).to eql('vendor/assets/foo.js')
      expect(entry.source_line).to eql(16)
      expect(entry.source_column).to eql(1)
      expect(entry.symbol).to eql('src')
    end

    it "should not return an entry with a different route" do
      expect(@map.resolve('/example/file2.js', 0, 5)).to be_nil
    end

    it "should not return an entry with a greater column number" do
      entry = @map.resolve('/example/file.js', 0, 8)
      expect(entry.source_file).to eql('vendor/assets/foo.js')
      expect(entry.source_line).to eql(16)
      expect(entry.source_column).to eql(1)
      expect(entry.symbol).to eql('src')
    end

    it "should not return an entry with a different line number" do
      entry = @map.resolve('vendor/assets/foo.js', 1, 0)
      expect(entry).to be_nil
    end

    it "should not abort early" do
      map = Squash::Javascript::SourceMap.new
      map << Squash::Javascript::SourceMap::Mapping.new('http://test.host/example/url.js', 3, 140, 'app/assets/javascripts/example/url.coffee', 2, 1, 'foobar')
      map << Squash::Javascript::SourceMap::Mapping.new('/example/path.js', 3, 140, 'app/assets/javascripts/example/path.coffee', 2, 1, 'foobar')
      map << Squash::Javascript::SourceMap::Mapping.new('http://test2.host/example/customhost.js', 5, 20, 'app/assets/javascripts/example/customhost.coffee', 25, 1, 'bazbar')
      map << Squash::Javascript::SourceMap::Mapping.new('/example/customhost.js', 5, 20, 'app/assets/javascripts/example/customhost-path.coffee', 25, 1, 'bazbar')

      entry = map.resolve('http://test.host/example/url.js', 3, 144)
      expect(entry.source_file).to eql('app/assets/javascripts/example/url.coffee')
      expect(entry.source_line).to eql(2)
      expect(entry.symbol).to eql('foobar')
    end
  end
end
