module LeagueOfLegends
  class DamagePerSecondScorer
    def self.title
      'Damage Per Second (DPS)'
    end

    def self.score(components, values, duel)
      unmapped_duration = components['unmapped_duration'].map do |duration|
        duration.map{ |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)
      end.reduce([0.0] * components['maxrank'], :element_wise_add)

      # Calculate multiplier based on percentages

      multiplier = components['unmapped_percentage'].map do |percentage|
        percentage.map{ |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)
      end.reduce([1.0] * components['maxrank']) { |memo, percentage| memo.element_wise_multiply(percentage.divide_by_scalar(100.0).add_scalar(1.0)) }

      scores = components['damage'].map do |damage|

        # Parse value keys

        value = damage['value'].map { |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)

        score = if damage['per_time']

          if damage['duration'].nan? and unmapped_duration.reduce(:+) == 0.0
            # Use raw DPS for toggle type spells
            value
          else
            # Calculate flat damage from damage per time and duration then balance with duration/cooldown
            duration = damage['duration']
            duration = [duration] * components['maxrank']

            duration = duration.element_wise_add(unmapped_duration)

            value.multiply_by_scalar(damage['duration']).element_wise_divide(components['cooldown'].element_wise_add([damage['duration']] * components['maxrank']))
          end

        else
          # Take as flat damage balance using duration/cooldown
          duration = damage['duration']
          duration = 0.0 if duration.nan?
          duration = [duration] * components['maxrank']

          duration = duration.element_wise_add(unmapped_duration)

          value.element_wise_divide(components['cooldown'].element_wise_add(duration))

        end

        unless duel
          score = score.multiply_by_scalar(damage['targets'])
        end

        score = score.element_wise_multiply(multiplier)

        score

      end

      scores.reduce([0.0] * components['maxrank'], :element_wise_add)
    end
  end

  class DamagePerManaScorer
    def self.title
      'Damage Per Unit Mana'
    end

    def self.score(components, values, duel)
      unmapped_duration = components['unmapped_duration'].map do |duration|
        duration.map{ |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)
      end.reduce([0.0] * components['maxrank'], :element_wise_add)

      # Calculate multiplier based on percentages

      multiplier = components['unmapped_percentage'].map do |percentage|
        percentage.map{ |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)
      end.reduce([1.0] * components['maxrank']) { |memo, percentage| memo.element_wise_multiply(percentage.divide_by_scalar(100.0).add_scalar(1.0)) }

      scores = components['damage'].map do |damage|

        # Parse value keys

        value = damage['value'].map { |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)

        score = if components['costType'].match(/^mana$/i)

          flat = [0.0] * components['maxrank']

          # Calculate the flat damage of a single spell cast

          if damage['per_time']
            duration = damage['duration']
            duration = 0.0 if duration.nan?
            duration = [duration] * components['maxrank']

            duration = duration.element_wise_add(unmapped_duration)

            flat = value.element_wise_multiply(duration)
          else
            flat = value
          end

          # Divide by the mana cost of single spell cast

          flat.element_wise_divide(components['cost'])

        elsif components['costType'].match(/manapersecond/i)

          if damage['per_time']
            # Damage per second divided by mana per second
            value.element_wise_divide(components['cost'])
          end

        end

        unless duel or score.nil?
          score = score.multiply_by_scalar(damage['targets'])
        end

        unless score.nil?
          score = score.element_wise_multiply(multiplier)
        end

        score

      end

      scores.reject(&:nil?).reduce([0.0] * components['maxrank'], :element_wise_add)

    end
  end
end