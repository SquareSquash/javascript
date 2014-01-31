require 'digest/md5'

class Squash::Javascript::SourceMappingJavascriptMinifier < Tilt::Template
  def prepare() end

  def evaluate(context, locals)
    source_map_file = Tempfile.new('sourcemap')
    compressor      = Closure::Compiler.new(create_source_map: source_map_file.path)
    minified        = compressor.compress(data)

    minified_file = Tempfile.new('minified')
    minified_file.write minified

    map                   = JSON.parse(source_map_file.read)
    minified_filename     = [Rails.application.config.assets.prefix, "#{context.logical_path}-#{digest(minified)}.js"].join('/')
    concatenated_filename = [Rails.application.config.assets.prefix, "#{context.logical_path}.js"].join('/')
    map['file']           = minified_filename
    map['sources']        = [concatenated_filename]

    path = source_map_path(digest(minified))
    FileUtils.mkdir_p path.dirname
    File.open(path, 'w') { |f| f.puts map.to_json }

    return minified
  end

  private

  def digest(io)
    Rails.application.assets.digest.update(io).hexdigest
  end

  def source_map_path(digest)
    Rails.root.join 'tmp', 'sourcemaps', 'minified', "#{digest}.json"
  end
end
