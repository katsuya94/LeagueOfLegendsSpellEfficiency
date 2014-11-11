require 'typhoeus'
require 'json'

ENDPOINT = 'na.api.pvp.net/api/lol'

file = File.open('riot-games-api-key', 'r')
API_KEY = file.gets.chomp
file.close

class Counter
  def initialize
    @data = {}
  end

  def increment(key)
    if @data[key].nil?
      @data[key] = 0
    end
    @data[key] += 1
  end

  def to_s
    @data.sort_by{|_, value| value}.reverse.map {|key, value| "#{key}: #{value}"}.join(', ')
  end
end

class Cache
  def initialize
    @memory = {}
  end

  def get(request)
    @memory[request]
  end

  def set(request, response)
    @memory[request] = response
  end
end

Typhoeus::Config.cache = Cache.new

def get(path, params = {})
  res = Typhoeus.get(
    ENDPOINT + path,
    params: params.merge({api_key: API_KEY})
  )

  if res.success?
    JSON.parse(res.body)
  else
    raise "#{res.code} failed to GET #{res.request.url}"
  end
end

realm = get('/static-data/na/v1.2/realm')
img_endpoint = realm['cdn'] + '/' + realm['v'] + '/img'

before_frequency = Counter.new
after_frequency = Counter.new
link_frequency = Counter.new

data = get('/static-data/na/v1.2/champion', champData: 'spells')['data']
data.each_value do |champion|
  spells = champion['spells']
  spells.each do |spell|
    puts spell['name']
    puts "cost = #{spell['cost']}"
    puts "costType = #{spell['costType']}"
    puts "cooldown = #{spell['cooldown']}"

    image = spell['image']['full']

    maxrank = spell['maxrank']
    vars = spell['vars']
    effect = spell['effect']
    text = spell['sanitizedTooltip']

    puts "vars = #{vars}"
    puts "effect = #{effect}"
    puts text

    unless vars.nil?
      vars.each do |var|
        link_frequency.increment(var['link'])
      end
    end

    effect.each_index do |ex|
      unless effect[ex].nil?
        re = /\{\{ ?e#{ex.to_s} ?\}\}/
        match = re.match(text)
        unless match.nil?
          first, last = match.offset(0)

          percentage = text[last] == '%'

          remaining = text[last..-1]
          associated_match = []

          while true
            puts remaining
            matches = remaining.match(/^(\s*\(?\s*\+?\s*\{\{\s*[a-z0-9]+\s*\}\}\s*\)?)(.*)/)
            if matches.nil?
              break
            end

            clause = matches[1]
            p clause
            remaining = matches[2]
            p remaining

            associated_match << clause
          end

          associated = associated_match.map do |clause|
            clause[/(?<=\{\{)\s*[a-z0-9]+\s*(?=\}\})/].strip
          end

          puts "e#{ex.to_s}: #{associated}"

          before = text[0...first]
            .downcase
            .gsub(/(\{\{.+?\}\})|(\(.*?\))/, '')
            .gsub(/[^\w']/, ' ')
            .split
          after = text[last..-1]
            .downcase
            .gsub(/(\{\{.+?\}\})|(\(.*?\))/, '')
            .gsub(/[^\w']/, ' ')
            .split

          before_frequency.increment(before.last(2).join(' '))
          after_frequency.increment(after.first(2).join(' '))
        end
      end
    end
    puts
  end
end

puts before_frequency
puts
puts after_frequency
puts
puts link_frequency
puts
