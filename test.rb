require 'minitest/unit'

require './league_of_legends.rb'
include LeagueOfLegends

class LeagueOfLegendsTest < MiniTest::Unit::TestCase

  def test_api_calls
    api_key
    img_endpoint
  end

  def test_include_sequence
    assert ['a', 'b', 'c', 'd', 'e'].include_sequence?('b', /c/, 'd')
  end

  def test_array_scalar_operations
    assert_equal [1, 2, 3].multiply_by_scalar(3), [3, 6, 9]
    assert_equal [3, 6, 9].divide_by_scalar(3), [1, 2, 3]
    assert_equal [1, 2, 3].add_scalar(4), [5, 6, 7]
  end

  def test_array_element_wise_operations
    assert_equal [1, 2, 3].element_wise_multiply([2, 4, 6]), [2, 8, 18]
    assert_equal [1, 2, 3].element_wise_add([3, 2, 1]), [4, 4, 4]
    assert_equal [3, 6, 9].element_wise_divide([3, 2, 1]), [1, 3, 9]
  end

end

MiniTest::Unit.autorun
