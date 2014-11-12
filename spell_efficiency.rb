module LeagueOfLegends
  def spell_efficiency(base_attack_damage, bonus_attack_damage, spell_damage, duel, scorer)
    scorer_class = nil
    scorer_class = DamagePerSecondScorer if scorer.match(/damage.?per.?second|dps/i)
    scorer_class = DamagePerManaScorer if scorer.match(/damage.?per.?mana|dpm|mana/i)

    ranks = []

    data = get('/static-data/na/v1.2/champion', champData: 'spells')['data']
    data.each_value do |champion|
      champion['spells'].each do |spell|
        vars = spell['vars']
        effect = spell['effect']
        text = spell['sanitizedTooltip']

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

            values[var['key']] = [value] * spell['maxrank']
          end
        end

        effect.each_index do |ex|
          values["e#{ex.to_s}"] = effect[ex]
        end

        components = Hash.new
        components['damage'] = Array.new

        # Attempt to infer what each effect does

        manual = MANUAL[spell['name']]

        if manual.nil?
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

                # "for/over _ second(s)" interpret as a duration

                if !before.last.nil? and before.last.match(/for|over/) and !after.first.nil? and after.first.match(/seconds?/)
                  if before.last(4).take(3).include_sequence?(/damages?/)
                    components['unmapped_durations'] = Array.new if components['unmapped_durations'].nil?
                    components['unmapped_durations'] << associated
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

                targets = 1

                if before.include_sequence?(/champions|units|enemies/) or before.include_sequence?('each', /champion|unit|enemy/) or after.include_sequence?(/champions|units|enemies/) or after.include_sequence?('each', /champion|unit|enemy/)
                  targets = 5
                end

                if damage
                  components['damage'] << { 'value' => associated, 'duration' => duration, 'per_time' => per_time, 'multiplier' => multiplier, 'targets' => targets }
                end
              end
            end
          end
        else
          components.merge!(manual)
        end

        components['cost'] = spell['cost']
        components['costType'] = spell['costType']
        components['cooldown'] = spell['cooldown']
        components['maxrank'] = spell['maxrank']

        score = nil
        unless scorer_class.nil?
          score = scorer_class.score(components, values, duel)
        end

        output = nil

        unless score.nil?
          ranks << { 'score' => score, 'name' => spell['name'], 'image' => spell['image']['full'], 'champion' => champion['name'] }
        end
      end
    end

    ranks.sort_by! { |el| el['score'].reduce(0.0, :+) / el['score'].length.to_f }.reverse!
    
    { 'ranks' => ranks, 'scorer' => scorer_class }
  end
end
