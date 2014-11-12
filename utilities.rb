require 'typhoeus'
require 'json'

module LeagueOfLegends
  ENDPOINT = 'na.api.pvp.net/api/lol'

  def api_key
    file = File.open('riot-games-api-key', 'r')
    key = file.gets.chomp
    file.close
    key
  end

  def get(path, params = {})
    res = Typhoeus.get(
      ENDPOINT + path,
      params: params.merge({api_key: api_key})
    )

    if res.success?
      JSON.parse(res.body)
    else
      raise "#{res.code} failed to GET #{res.request.url}"
    end
  end

  @img_endpoint_memo = nil

  def img_endpoint
    if @img_endpoint_memo.nil?
      realm = self.get('/static-data/na/v1.2/realm')
      @img_endpoint_memo = realm['cdn'] + '/' + realm['v'] + '/img'
    end
    @img_endpoint_memo
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

  def multiply_by_scalar(scalar)
    self.map { |el| el * scalar }
  end

  def divide_by_scalar(scalar)
    self.map { |el| el / scalar }
  end

  def add_scalar(scalar)
    self.map { |el| el + scalar }
  end

  def element_wise_multiply(*others)
    self.zip(*others).map { |el| el.reduce(:*) }
  end

  def element_wise_add(*others)
    self.zip(*others).map { |el| el.reduce(:+) }
  end

  def element_wise_divide(denominators)
    self.zip(denominators).map { |numerator, denominator| numerator / denominator }
  end
end