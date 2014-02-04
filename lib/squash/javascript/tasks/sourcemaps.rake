require 'squash/uploader'

# @private
class Sprockets::Asset
  def sourcemap
    relative_path = if pathname.to_s.include?(Rails.root.to_s)
                      pathname.relative_path_from(Rails.root)
                    else
                      pathname
                    end.to_s
    # any extensions after the ".js" can be removed, because they will have
    # already been processed
    relative_path.gsub! /(?<=\.js)\..*$/, ''
    resource_path = [Rails.application.config.assets.prefix, logical_path].join('/')

    mappings = Array.new
    to_s.lines.each_with_index do |_, index|
      offset = SourceMap::Offset.new(index, 0)
      mappings << SourceMap::Mapping.new(relative_path, offset, offset)
    end
    SourceMap::Map.new(mappings, resource_path)
  end
end

# @private
class Sprockets::BundledAsset < Sprockets::Asset
  def sourcemap
    to_a.inject(SourceMap::Map.new) do |map, asset|
      map + asset.sourcemap
    end
  end
end

namespace :sourcemaps do
  namespace :upload do
    task all: [:minified, :concatenated, :compiled]

    task minified: :environment do
      manifest_path = Rails.root.join('public',
                                      Rails.application.config.assets.prefix.sub(/^\//, ''),
                                      'manifest-*.json')
      manifest_path = Dir.glob(manifest_path.to_s).first
      raise "You must precompile your static assets before running this task." unless manifest_path

      manifest = JSON.parse(File.read(manifest_path))
      manifest['files'].each do |path, metadata|
        sourcemap_path = Rails.root.join('tmp', 'sourcemaps', 'minified', "#{metadata['digest']}.json")
        if sourcemap_path.exist?
          Squash::Uploader.new(Squash::Ruby.configuration(:api_host),
                               skip_verification: Squash::Ruby.configuration(:skip_verification)
          ).transmit '/api/1.0/sourcemap.json',
                     {
                         'api_key'     => Squash::Ruby.configuration(:api_key),
                         'environment' => Rails.env,
                         'revision'    => Squash::Ruby.current_revision,
                         'sourcemap'   => Base64.encode64(Zlib::Deflate.deflate(File.read(sourcemap_path))),
                         'from'        => 'hosted',
                         'to'          => 'concatenated'
                     }
        end
      end
    end

    task concatenated: :environment do
      Rails.application.assets.each_logical_path(Rails.application.config.assets.precompile) do |path|
        next unless path.end_with?('.js')
        asset = Rails.application.assets.find_asset(path)
        next unless asset.kind_of?(Sprockets::BundledAsset)
        map = asset.sourcemap
        Squash::Uploader.new(Squash::Ruby.configuration(:api_host),
                             skip_verification: Squash::Ruby.configuration(:skip_verification)
        ).transmit '/api/1.0/sourcemap.json',
                   {
                       'api_key'     => Squash::Ruby.configuration(:api_key),
                       'environment' => Rails.env,
                       'revision'    => Squash::Ruby.current_revision,
                       'sourcemap'   => Base64.encode64(Zlib::Deflate.deflate(map.as_json.to_json)),
                       'from'        => 'concatenated',
                       'to'          => 'compiled',
                   }
      end
    end

    task compiled: :environment do
      Dir.glob(Rails.root.join('tmp', 'sourcemaps', 'compiled', '*.json')).each do |file|
        Squash::Uploader.new(Squash::Ruby.configuration(:api_host),
                             skip_verification: Squash::Ruby.configuration(:skip_verification)
        ).transmit '/api/1.0/sourcemap.json',
                   {
                       'api_key'     => Squash::Ruby.configuration(:api_key),
                       'environment' => Rails.env,
                       'revision'    => Squash::Ruby.current_revision,
                       'sourcemap'   => Base64.encode64(Zlib::Deflate.deflate(File.read(file))),
                       'from'        => 'compiled',
                       'to'          => 'original'
                   }
      end
    end
  end

  task :clean do
    system 'rm', '-rf', 'tmp/sourcemaps/*'
  end
end
