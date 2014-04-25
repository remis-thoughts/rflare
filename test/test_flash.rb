require 'minitest/autorun'
require 'flash'

class Hash
  def <=> other
    k = keys.sort <=> other.keys.sort
    return k if k != 0
    keys.sort.each {|key|
      k = self[key] <=> other[key]
      return k if k != 0
    }
    0
  end
end

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

class FlashSpecTest < Minitest::Test
  def setup
    @bounds = 0..10
  end

  def test_single_relativeconst
    assert_equal (4..4), Spec.new('+1').range(3, @bounds)
  end 

  def test_single_plusstar
    assert_equal (4..@bounds.max), Spec.new('+*').range(3, @bounds)
  end 

  def test_single_plusstar2
    assert_equal (4..@bounds.max), Spec.new('*').range(3, @bounds)
  end 

  def test_minusone
    assert_equal (2..2), Spec.new('-1').range(3, @bounds)
  end 

  def test_minusstar
    assert_equal (@bounds.min..2), Spec.new('-*').range(3, @bounds)
  end 

  def test_abs
    assert_equal (1..1), Spec.new('1').range(3, @bounds)
  end 

  def test_range_relativeconst
    assert_equal (4..6), Spec.new('+1:+3').range(3, @bounds)
  end 

  def test_range_star
    assert_equal (5..@bounds.max), Spec.new('+2:+*').range(3, @bounds)
  end 

  def test_invalid
    assert_raises(RuntimeError) { Spec.new 'hat' }
  end 

end

class FlashNodeTest < Minitest::Test
  def setup
    @ss = Spreadsheet.new [[0,1,2],['a','b','c']]
  end

  def test_match
    n = Node.new ({:rows => 0}), @ss.row_bounds, @ss.col_bounds
    assert_equal Square.new(0..0, 0...3), n.valid
    assert n.matches @ss, 0, 0
    assert n.matches @ss, 0, 1
    assert n.matches @ss, 0, 2
    refute n.matches @ss, 1, 0
    refute n.matches @ss, 1, 1
    refute n.matches @ss, 1, 2
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

class FlashResultsTest < Minitest::Test
  def setup
    @ss = Spreadsheet.new [
      [      nil, 'value', 'year', 'value', 'year', 'Comments'],
      [ 'Albania',  1000,   1950,     930,   1981,     'FRA 1'],
      [ 'Austria',  3139,   1951,    3177,   1955,     'FRA 3'],
      [ 'Belgium',   541,   1947,     601,   1950,        nil ],
      ['Bulgaria',  2964,   1947,    3259,   1958,     'FRA 1'],
      [   'Czech',  2416,   1950,    2503,   1960,        'NC']
    ] 
  end

  def node id, match, rows = nil, columns = nil
    hash = {
      :id => id,
      :match => match,
      :columns => columns,
      :rows => rows
    }
    Node.new hash, @ss.row_bounds, @ss.col_bounds
  end

  def edge from, to, vert, horiz
    hash = {:from => from, :to => to, :vert => vert, :horiz => horiz}
    Edge.new hash
  end

  def assert_matches edges, nodes, expected
    actual = Results.new(edges, nodes, @ss, nodes[0]).to_a
    assert_equal expected.sort, actual.sort
  end

  # the tests:

  def test_simplecell
    nodes = [node(3, '^value$')]
    edges = []
    expected = [{3 => 'value'}, {3 => 'value'}]
    assert_matches edges, nodes, expected
  end

  def test_header
    nodes = [node(3, '^value$', 0, nil)]
    edges = []
    expected = [{3 => 'value'}, {3 => 'value'}]
    assert_matches edges, nodes, expected
  end

  def test_oneedge
    nodes = [node(4,'^[0-9]+$'), node(3, '^value$')]
    edges = [edge(4, 3, '-*', nil)]
    expected = [
      {3 => 'value', 4 => 1000},
      {3 => 'value', 4 => 3139},
      {3 => 'value', 4 =>  541},
      {3 => 'value', 4 => 2964},
      {3 => 'value', 4 => 2416},
      {3 => 'value', 4 =>  930},
      {3 => 'value', 4 => 3177},
      {3 => 'value', 4 =>  601},
      {3 => 'value', 4 => 3259},
      {3 => 'value', 4 => 2503}
    ]
    assert_matches edges, nodes, expected
  end

  def test_twoedges
    nodes = [
      node('v','^[0-9]+$'), 
      node('vcol', '^value$'),
      node('y','^19[0-9]{2}$'), 
    ]
    edges = [
      edge('v', 'vcol', '-*', nil),
      edge('v', 'y', nil, '+1')
    ]
    expected = [
      {'vcol' => 'value', 'v' => 1000, 'y' => 1950},
      {'vcol' => 'value', 'v' => 3139, 'y' => 1951},
      {'vcol' => 'value', 'v' =>  541, 'y' => 1947},
      {'vcol' => 'value', 'v' => 2964, 'y' => 1947},
      {'vcol' => 'value', 'v' => 2416, 'y' => 1950},
      {'vcol' => 'value', 'v' =>  930, 'y' => 1981},
      {'vcol' => 'value', 'v' => 3177, 'y' => 1955},
      {'vcol' => 'value', 'v' =>  601, 'y' => 1950},
      {'vcol' => 'value', 'v' => 3259, 'y' => 1958},
      {'vcol' => 'value', 'v' => 2503, 'y' => 1960}
    ]
    assert_matches edges, nodes, expected
  end

  def test_twolevelrecursion
    nodes = [
      node('v','^[0-9]+$'), 
      node('vcol', '^value$'),
      node('y','^19[0-9]{2}$'), 
      node('ycol', '^year$'),
    ]
    edges = [
      edge('v', 'vcol', '-*', nil),
      edge('y', 'ycol', '-*', nil),
      edge('v', 'y', nil, '+1'),
    ]
    expected = [
      {'vcol' => 'value', 'v' => 1000, 'y' => 1950, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 3139, 'y' => 1951, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' =>  541, 'y' => 1947, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 2964, 'y' => 1947, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 2416, 'y' => 1950, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' =>  930, 'y' => 1981, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 3177, 'y' => 1955, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' =>  601, 'y' => 1950, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 3259, 'y' => 1958, 'ycol' => 'year'},
      {'vcol' => 'value', 'v' => 2503, 'y' => 1960, 'ycol' => 'year'},
    ]
    assert_matches edges, nodes, expected
  end

  def test_withrowlimit
    nodes = [node(3, '^[A-Za-z]+$', [1, nil], 0)]
    edges = []
    expected = [
      {3 => 'Albania'},
      {3 => 'Austria'},
      {3 => 'Belgium'},
      {3 => 'Bulgaria'},
      {3 => 'Czech'},
    ]
    assert_matches edges, nodes, expected
  end

  def test_frompaper
    nodes = [
      node('c', '^[A-Za-z]+$', [1,nil], 0),
      node('v','^[0-9]+$', [1,nil], nil), 
      node('vcol', '^value$', 0, nil),
      node('y','^19[0-9]{2}$', [1,nil], nil), 
      node('ycol', '^year$', 0, nil),
      node('m','^[A-Za-z 0-9]*$', [1,nil], nil), 
      node('mcol', '^Comments$', 0, nil),
    ]
    edges = [
      edge('v', 'vcol', '-*', nil),
      edge('y', 'ycol', '-*', nil),
      edge('m', 'mcol', '-*', nil),
      edge('c', 'v', nil, '+*'),
      edge('v', 'y', nil, '+1'),
      edge('y', 'm', nil, '+*'),
    ]
    expected = [
      {'vcol' => 'value', 'v' => 1000, 'y' => 1950, 'ycol' => 'year', 'c' => 'Albania', 'mcol' => 'Comments', 'm' => 'FRA 1'},
      {'vcol' => 'value', 'v' => 3139, 'y' => 1951, 'ycol' => 'year', 'c' => 'Austria', 'mcol' => 'Comments', 'm' => 'FRA 3'},
      {'vcol' => 'value', 'v' =>  541, 'y' => 1947, 'ycol' => 'year', 'c' => 'Belgium', 'mcol' => 'Comments', 'm' => nil},
      {'vcol' => 'value', 'v' => 2964, 'y' => 1947, 'ycol' => 'year', 'c' => 'Bulgaria', 'mcol' => 'Comments', 'm' => 'FRA 1'},
      {'vcol' => 'value', 'v' => 2416, 'y' => 1950, 'ycol' => 'year', 'c' => 'Czech', 'mcol' => 'Comments', 'm' => 'NC'},
      {'vcol' => 'value', 'v' =>  930, 'y' => 1981, 'ycol' => 'year', 'c' => 'Albania', 'mcol' => 'Comments', 'm' => 'FRA 1'},
      {'vcol' => 'value', 'v' => 3177, 'y' => 1955, 'ycol' => 'year', 'c' => 'Austria', 'mcol' => 'Comments', 'm' => 'FRA 3'},
      {'vcol' => 'value', 'v' =>  601, 'y' => 1950, 'ycol' => 'year', 'c' => 'Belgium', 'mcol' => 'Comments', 'm' => nil},
      {'vcol' => 'value', 'v' => 3259, 'y' => 1958, 'ycol' => 'year', 'c' => 'Bulgaria', 'mcol' => 'Comments', 'm' => 'FRA 1'},
      {'vcol' => 'value', 'v' => 2503, 'y' => 1960, 'ycol' => 'year', 'c' => 'Czech', 'mcol' => 'Comments', 'm' => 'NC'},
    ]
    assert_matches edges, nodes, expected
  end
end

