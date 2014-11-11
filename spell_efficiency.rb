require 'typhoeus'
require 'json'

ENDPOINT = 'na.api.pvp.net/api/lol'

file = File.open('riot-games-api-key', 'r')
API_KEY = file.gets.chomp
file.close

def multiply_by_scalar(array, scalar)
  array.map { |el| el * scalar }
end

def divide_by_scalar(array, scalar)
  array.map { |el| el / scalar }
end

def element_wise_multiply(array, *others)
  array.zip(*others).map { |el| el.reduce(:*) }
end

def element_wise_divide(numerators, denominators)
  numerators.zip(denominators).map { |numerator, denominator| numerator / denominator }
end

class Array
  def include_sequence?(sequence)
    self.each_cons(sequence.length) do |candidate|
      equality = sequence.zip(candidate).map do |pattern, word|
        if pattern.class == Regexp
          pattern.match(word)
        else
          pattern == word
        end
      end
      if equality.all?
        return true
      end
    end
    false
  end
end

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

base_attack_damage = 150
bonus_attack_damage = 100
spell_damage = 250

data = get('/static-data/na/v1.2/champion', champData: 'spells')['data']
data.each_value do |champion|
  spells = champion['spells']
  spells.each do |spell|
    image = spell['image']['full']

    cost = spell['cost']
    costtype = spell['costType']
    cooldown = spell['cooldown']
    maxrank = spell['maxrank']
    vars = spell['vars']
    effect = spell['effect']
    text = spell['sanitizedTooltip']

    puts spell['name']
    puts "cost = #{cost}"
    puts "costtype = #{costtype}"
    puts "cooldown = #{cooldown}"
    puts "vars = #{vars}"
    puts "effect = #{effect}"
    puts text

    unless vars.nil?
      vars.each do |var|
        link_frequency.increment(var['link'])
      end
    end

    values = {}
    components = Hash.new

    # Attempt to infer what each effect does

    effect.each_index do |ex|
      unless effect[ex].nil?
        values["e#{ex.to_s}"] = effect[ex]
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
            remaining = matches[2]

            associated_match << clause
          end

          associated = associated_match.map do |clause|
            clause[/(?<=\{\{)\s*[a-z0-9]+\s*(?=\}\})/].strip
          end

          associated << "e#{ex.to_s}"

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

          if after.first == 'seconds'
            components['duration'] = associated
          else
            multiplier = 1.0
            denominator = nil # assume flat (not over time)

            per_index = after.take(3).index('per')
            second_index = after.take(5).index { |word| word.match(/seconds?/) }

            if !per_index.nil? and !second_index.nil? and second_index > per_index
              denominator = 1.0

              after[(per_index + 1)...second_index].each do |word|
                if word.to_i.to_s == word
                  denominator = word.to_i.to_f
                end
              end

              if components['duration'].nil?
                after.each_index do |pos|
                  if after[pos] == 'for' and after[pos + 2].match(/seconds?/)
                    if after[pos + 1].to_f.to_s == after[pos + 1]
                      components['duration'] = after[pos + 1].to_f
                    end
                  end
                end
              end
            end

            if after.take(2).include?('area') or
               after.include?('champions') or
               after.include?('enemies') or
               after.include?('allies') or
               after.include_sequence?(['for', 'each', /enemy|ally|allied|unit/]) or
               before.take(2).include?('area') or
               before.include?('champions') or
               before.include?('enemies') or
               before.include?('allies') or
               before.include_sequence?(['for', 'each', /enemy|ally|allied|unit/])
              multiplier *= 5
            end

            if (!before.last.nil? and before.last.match(/deal(s|ing)/)) or
               (!after.first.nil? and after.first.match(/physical|attack|magic/)) or
               after.take(3).include?('damage')
              unless after.take(2).include?('less')
                if denominator.nil?
                  components['damage' + ex.to_s] = associated
                  components['multiplier' + ex.to_s] = multiplier
                else
                  components['dot' + ex.to_s] = associated
                  components['multiplier' + ex.to_s] = multiplier / denominator
                end
              end
            end
          end
        end
      end
    end

    unless vars.nil?
      vars.each do |var|
        value = 0.0

        if var['link'] == 'spelldamage'
          value += spell_damage * var['coeff'].reduce(:+) / var['coeff'].length
        elsif var['link'] == 'attackdamage'
          value += (base_attack_damage + bonus_attack_damage) * var['coeff'].reduce(:+) / var['coeff'].length
        elsif var['link'] == 'bonusattackdamage'
          value += bonus_attack_damage * var['coeff'].reduce(:+) / var['coeff'].length
        end

        values[var['key']] = [value] * maxrank
      end
    end

    puts components
    puts values

    # damage per second

    dps = [0.0] * maxrank

    components.each_key do |component|
      if component.start_with?('dot')
        ex = component[-1]
        dot_dps = components[component]
          .map { |key| values[key] }
          .transpose
          .map { |summands| summands.reduce(:+) }
          .map { |rank_dps| rank_dps * components['multiplier' + ex] }

        # TODO

        unless components['duration'].nil?
          durations = components['duration']
          durations = durations.each_index { |index| [durations[index], index] }.map do |duration, index|
            if duration.class == String
              puts duration, index
              values[duration][index]
            else
              duration
            end
          end

          dot_dps = dot_dps
            .zip(
              durations,
              durations.zip(cooldown).reduce(:+))
            .map { |rank_dps, rank_duration, rank_cycle|
              puts rank_dps, rank_duration, rank_cycle;
              rank_dps * rank_duration / rank_cycle}
        end

        dps = dps.zip(dot_dps).map { |summands| summands.reduce(:+) }
      end
    end

    # damage per mana


    puts components
    puts values
    puts
  end
end

puts before_frequency
puts
puts after_frequency
puts
puts link_frequency
puts
