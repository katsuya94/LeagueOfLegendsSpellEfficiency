module LeagueOfLegends
  class DamagePerSecondScorer
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
end