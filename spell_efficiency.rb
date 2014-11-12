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
  def include_sequence?(*sequence)
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
after0_frequency = Counter.new
after1_frequency = Counter.new
after2_frequency = Counter.new
before_duration_frequency = Counter.new

duel = false

base_attack_damage = 150
bonus_attack_damage = 100
spell_damage = 250

total_effects = 0
interpreted_effects = 0
total_multi_target = 0

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
    puts "cost = #{cost}; costtype = #{costtype}; cooldown = #{cooldown}"
    puts text

    values = Hash.new

    # Calculate the values of the various variables

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

    effect.each_index do |ex|
      values["e#{ex.to_s}"] = effect[ex]
    end

    components = Hash.new

    # Attempt to infer what each effect does

    effect.each_index do |ex|
      unless effect[ex].nil?
        re = /\{\{ ?e#{ex.to_s} ?\}\}/
        match = re.match(text)
        unless match.nil?
          # Find the containing sentence

          period_positions = [-1] + (text.chars.to_a.each_index.select { |index| text[index] == '.' }) + [text.length]

          first, last = match.offset(0)

          first_index = period_positions.length - 1
          first_index -= 1 while period_positions[first_index] > first

          last_index = 0
          last_index += 1 while period_positions[last_index] < last

          sentence = text[(period_positions[first_index] + 1)...period_positions[last_index]]
          sentence.downcase!

          first -= period_positions[first_index] + 1
          last -= period_positions[first_index] + 1

          percentage = sentence[last] == '%'

          # Find the associated variables

          remaining = sentence[last..-1]
          associated = []

          while true
            matches = remaining.match(/^(\s?\(?\s?\+?\s?\{\{\s?[a-z0-9]+\s?\}\}\s?\)?)(.*)/)
            if matches.nil?
              break
            end

            clause = matches[1]
            remaining = matches[2]

            associated << clause
          end

          # Exclude the associated variables from the sentence text

          last += associated.map(&:length).reduce(0, :+)

          # Create a list of the variable names

          associated.map! do |clause|
            clause[/(?<=\{\{)\s*[a-z0-9]+\s*(?=\}\})/].strip
          end
          associated << "e#{ex.to_s}"

          # Divide into words

          before = sentence[0...first].scan(/(?:\w+)|(?:(?:\(\s?\+?\s?)?\{\{\s?[a-z0-9]+\s?\}\}(?:\s?\))?)/)
          after = sentence[last..-1].scan(/(?:\w+)|(?:(?:\(\s?\+?\s?)?\{\{\s?[a-z0-9]+\s?\}\}(?:\s?\))?)/)

          before_frequency.increment(before.last)
          after0_frequency.increment(after[0])
          after1_frequency.increment(after[1])
          after2_frequency.increment(after[2])

          total_effects += 1

          # "for/over _ second(s)" interpret as a duration

          if !before.last.nil? and before.last.match(/for|over/) and !after.first.nil? and after.first.match(/seconds?/)
            before.last(4).take(3).each { |word| before_duration_frequency.increment(word) }
            if before.last(4).take(3).include_sequence?(/damages?/)
              components['unmapped_durations'] = Array.new if components['unmapped_durations'].nil?
              components['unmapped_durations'] << associated
              interpreted_effects += 1
            end
          end

          duration = []

          # "for/over num seconds" interpret as a static duration

          after.each_cons(6) do |pre3, pre2, pre1, prefix, num, suffix|
            if prefix.match(/for|over/) and num.match(/^[0-9]+\.?[0-9]*$/) and suffix.match(/seconds?/)
              if [pre3, pre2, pre1].include_sequence?(/damages?/)
                duration << num.to_f
                break
              end
            end
          end

          duration = duration.reduce(0, :+) / duration.length.to_f

          per_time = false

          # "_ ... per second" interpret as over time

          if after.take(5).include_sequence?('per', 'second')
            per_time = true
          end

          multiplier = 1.0

          damage = false

          # "deals/dealing _" interpret as damage

          if !before.last.nil? and before.last.match(/deal(s|ing)/)
            damage = true
          end

          # "_ ... damage" interpret as damage

          if after.take(3).include?('damage')
            damage = true
          end

          multi_target = false

          if before.include_sequence?(/champions|units|enemies/) or before.include_sequence?('each', /champion|unit|enemy/) or after.include_sequence?(/champions|units|enemies/) or after.include_sequence?('each', /champion|unit|enemy/)
            multi_target = true
            total_multi_target += 1
          end

          unless duel
            if multi_target
              multiplier *= 5.0
            end
          end

          if damage
            components['damage'] = Array.new if components['damage'].nil?
            components['damage'] << { 'value' => associated, 'duration' => duration, 'per_time' => per_time, 'multiplier' => multiplier }
            interpreted_effects += 1
          end
        end
      end
    end

    puts "components = #{components}"
    puts "values = #{values}"

    # damage per second

    

    # damage per mana

    puts
  end
end

puts before_duration_frequency
puts

puts "#{interpreted_effects}/#{total_effects}"
puts "#{total_multi_target} multi target"
