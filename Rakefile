# encoding: utf-8

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

require 'fileutils'

#################################### BUNDLER ###################################

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

#################################### JEWELER ###################################

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name        = "squash_javascript"
  gem.homepage    = "http://github.com/SquareSquash/javascript"
  gem.license     = "Apache 2.0"
  gem.summary     = %Q{Squash client for JavaScript projects}
  gem.description = %Q{This client library records exceptions in front-end JavaScript code to Squash.}
  gem.email       = "tim@squareup.com"
  gem.authors     = ["Tim Morgan"]
  gem.files       = %w( README.md LICENSE.txt lib/**/* bin/* vendor/**/* )
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

##################################### YARD #####################################

require 'yard'

# bring sexy back (sexy == tables)
module YARD::Templates::Helpers::HtmlHelper
  def html_markup_markdown(text)
    markup_class(:markdown).new(text, :gh_blockcode, :fenced_code, :autolink, :tables).to_html
  end
end

YARD::Rake::YardocTask.new do |doc|
  doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
  doc.options << '--protected' << '--no-private'
  doc.options << '-r' << 'README.md'
  doc.options << '-o' << 'doc'
  doc.options << '--title' << "Squash Ruby Client Library Documentation"

  doc.files = %w( lib/**/*.rb README.md )
end

################################# COFFEESCRIPT #################################

desc "Install the CoffeeScript compiler and Closure minifier"
task :setup do
  # compiling
  system 'npm', 'install', 'coffee-script'

  # minifying
  system 'curl', '-O', 'http://closure-compiler.googlecode.com/files/compiler-latest.zip'
  system 'unzip', '-o', 'compiler-latest.zip', '-d', 'closure'
  system 'rm', 'compiler-latest.zip'

  # docs
  system 'npm', 'install', 'codo'
end

desc "Compile the CoffeeScript code into JavaScript"
task :compile do
  compiler_path = File.join(File.dirname(__FILE__), 'node_modules', '.bin', 'coffee')
  output_path   = File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts')
  input_file    = File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'squash_javascript', 'client.js.coffee')

  if File.exist?(compiler_path)
    system compiler_path, '-c', '-o', output_path, input_file
  else
    system 'coffee', '-c', '-o', output_path, input_file
  end

  FileUtils.mv File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'client.js.js'),
               File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'squash_javascript.orig.js')
end

################################# MINIFICATION #################################

desc "Minify the JavaScript code for distribution"
task minify: :compile do
  input_file  = File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'squash_javascript.orig.js')
  input_file2 = File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'squash_javascript', 'tracekit.js')
  output_file = File.join(File.dirname(__FILE__), 'vendor', 'assets', 'javascripts', 'squash_javascript.min.js')
  map_file    = File.join(File.dirname(__FILE__), 'mapping.json')

  system 'rm', '-f', output_file
  system 'java', '-jar', 'closure/compiler.jar',
         '--js', input_file, '--js', input_file2,
         '--create_source_map', map_file,
         '--source_map_format=V3',
         '--js_output_file', output_file
end

##################################### SPECS ####################################
namespace :spec do
  desc "Run Jasmine specs against SquashJavascript"
  task js: :minify do
    spec_file = File.join(File.dirname(__FILE__), 'spec', 'js', 'SpecRunner.html')
    system 'open', spec_file
  end
end

##################################### DOCS #####################################

namespace :doc do
  desc "Generate HTML API documentation for the Ruby client"
  YARD::Rake::YardocTask.new(:ruby) do |doc|
    doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
    doc.options << '--protected' << '--no-private'
    doc.options << '-r' << 'README.md'
    doc.options << '-o' << 'doc/ruby'
    doc.options << '--title' << "Squash Ruby Client Library Documentation"

    doc.files = %w( lib/**/*.rb README.md )
  end

  desc "Generate HTML API documentation for the JavaScript client"
  task :js do
    codo_path = File.join(File.dirname(__FILE__), 'node_modules', '.bin', 'codo')

    if File.exist?(codo_path)
      system codo_path
    else
      system 'codo'
    end
  end
end
