module LeagueOfLegends
  class DamagePerSecondScorer
    def self.title
      'Damage Per Second (DPS)'
    end

    def self.score(components, values, duel)
      scores = components['damage'].map do |damage|
        value = damage['value'].map { |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)

        score = if damage['per_time']
          if damage['duration'].nan?
            value
          else
            value.multiply_by_scalar(damage['duration']).element_wise_divide(components['cooldown'].element_wise_add([damage['duration']] * components['maxrank']))
          end
        else
          duration = damage['duration']
          duration = 0.0 if duration.nan?
          value.element_wise_divide(components['cooldown'].element_wise_add([duration] * components['maxrank']))
        end

        unless duel
          score = score.multiply_by_scalar(damage['targets'])
        end

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
      scores = components['damage'].map do |damage|

        value = damage['value'].map { |key| values[key] or [0.0] * components['maxrank'] }.reduce([0.0] * components['maxrank'], :element_wise_add)

        if components['costType'].match(/^mana$/i)

          flat = [0.0] * components['maxrank']

          if damage['per_time'] and !damage['duration'].nan?
            flat = value.multiply_by_scalar(damage['duration'])
          elsif !damage['per_time']
            flat = value
          end

          flat.element_wise_divide(components['cost'])

        elsif components['costType'].match(/manapersecond/i)

          if damage['per_time']
            value.element_wise_divide(components['cost'])
          end

        end
      end

      scores.reject(&:nil?).reduce([0.0] * components['maxrank'], :element_wise_add)

    end
  end
end