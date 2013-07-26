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
      mappings.to_yaml.should eql(File.read(root.join('spec', 'ruby', 'fixtures', 'mapping.yml')))
    end

    it "should allow the sourceRoot field to override the given root" do
      mappings = Squash::Javascript::SourceMap.from_sourcemap(root.join('spec', 'ruby', 'fixtures', 'mapping.json'), '/another/file.js', root: "/Documents/Projects/SquareSquash")
      mappings.to_yaml.should eql(File.read(root.join('spec', 'ruby', 'fixtures', 'custom_root.yml')))
    end
  end

  describe "#resolve" do
    before :all do
      @map = Squash::Javascript::SourceMap.from_sourcemap(root.join('spec', 'ruby', 'fixtures', 'mapping.json'), '/example/file.js')
    end

    it "should return the closest matching file, line, and column" do
      entry = @map.resolve('/example/file.js', 0, 0)
      entry.source_file.should eql('vendor/assets/foo.js')
      entry.source_line.should eql(16)
      entry.source_column.should eql(1)
      entry.symbol.should eql('src')
    end

    it "should not return an entry with a different route" do
      @map.resolve('/example/file2.js', 0, 5).should be_nil
    end

    it "should not return an entry with a greater column number" do
      entry = @map.resolve('/example/file.js', 0, 8)
      entry.source_file.should eql('vendor/assets/foo.js')
      entry.source_line.should eql(16)
      entry.source_column.should eql(1)
      entry.symbol.should eql('src')
    end

    it "should not return an entry with a different line number" do
      entry = @map.resolve('vendor/assets/foo.js', 1, 0)
      entry.should be_nil
    end
  end
end
