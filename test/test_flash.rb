require 'minitest/autorun'
require 'flash'

class FlashRangeTest < Minitest::Test
  def test_in
    assert_equal 4, (2..5).cap(4)
  end

  def test_after
    assert_equal 5, (2..5).cap(7)
  end

  def test_before
    assert_equal 2, (2..5).cap(1)
  end
end

class FlashSquareTest < Minitest::Test
  def test_include_in
    assert Square.new(2..4, 3..5).include? 3, 4
  end

  def test_include_out
    refute Square.new(2..4, 3..5).include? 1, 4
  end

  def test_enumerate
    assert_equal [[2,3], [2,4], [2,5], [3,3], [3,4], [3,5]], Square.new(2..3, 3..5).to_a
  end

  def test_equals
    assert_equal Square.new(2..3, 4..5), Square.new(2..3, 4..5)
  end
end

class FlashEdgeTest < Minitest::Test
  def setup
    @row_bounds, @col_bounds = 0..10, 0..10
  end

 def test_row_plusone
   e = Edge.new :from => 'f', :to => 't', :horiz => '+1'
   actual = e.get_square 5, 3, @row_bounds, @col_bounds
   assert_equal Square.new(5..5, 4..4), actual
 end 

 def test_row_plusstar
   e = Edge.new :from => 'f', :to => 't', :horiz => '+*'
   actual = e.get_square 5, 3, @row_bounds, @col_bounds
   assert_equal Square.new(5..5, 4..@col_bounds.max), actual
 end 

 def test_row_minusone
   e = Edge.new :from => 'f', :to => 't', :horiz => '-1'
   actual = e.get_square 5, 3, @row_bounds, @col_bounds
   assert_equal Square.new(5..5, 2..2), actual
 end 

 def test_row_minusstar
   e = Edge.new :from => 'f', :to => 't', :horiz => '-*'
   actual = e.get_square 5, 3, @row_bounds, @col_bounds
   assert_equal Square.new(5..5, @col_bounds.min...3), actual
 end 
end

class FlashSpreadsheetTest < Minitest::Test
  def test_empty
    ss = Spreadsheet.new []
    assert_equal 0...0, ss.row_bounds
    assert_equal 0...0, ss.col_bounds
    assert_nil ss[0,0]
  end

  def test_full
    ss = Spreadsheet.new [[1,2,3],['a','b','c']]
    assert_equal 0...2, ss.row_bounds
    assert_equal 0...3, ss.col_bounds
    assert_equal 1, ss[0,0]
    assert_equal 'b', ss[1,1]
  end
end

