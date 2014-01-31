require 'digest/sha2'

class Squash::Javascript::SourceMappingCoffeescriptTemplate < Tilt::CoffeeScriptTemplate
  def evaluate(scope, locals, &block)
    @output ||= begin
      result = CoffeeScript.compile(data, options.merge(sourceMap: true))

      relative_path = if file.include?(Rails.root.to_s)
                        Pathname.new(file).relative_path_from(Rails.root)
                      else
                        Pathname.new(file)
                      end

      map            = JSON.parse(result['v3SourceMap'])
      map['file']    = relative_path.to_s.sub(/\.coffee$/, '')
      map['sources'] = [relative_path.to_s]

      map_path = Rails.root.join('tmp', 'sourcemaps', 'compiled', Digest::SHA2.hexdigest(relative_path.to_s) + '.json')
      FileUtils.mkdir_p map_path.dirname
      Rails.root.join('tmp', 'sourcemaps', map_path).open('w') do |f|
        f.puts map.to_json
      end

      result['js']
    end
  end
end
