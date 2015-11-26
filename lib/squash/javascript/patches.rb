require 'source_map'
require 'sprockets'

# @private
class Sprockets::Asset
  def sourcemap
    if included
      return included.inject(SourceMap::Map.new) do |map, path|
        asset = @environment.load(path)
        map + asset.sourcemap
      end
    end

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
