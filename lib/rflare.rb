
class Array
  def bounds; 0 ... size; end
end

class Range
  def cap num
    num < min ? min : (num > max ? max : num)
  end
end

module RFlare

  class Square
    def initialize rows, columns
      @rows, @columns = rows, columns
    end

    attr_reader :rows, :columns
    include Enumerable

    def each
      @rows.each {|row|
        @columns.each {|col|
          yield row, col
        }
      }
    end

    def include? row, col
      @rows.include? row and @columns.include? col
    end

    def == other
      @rows == other.rows and @columns == other.columns
    end
  end

  class Node
    def initialize id, match, rows, columns, row_bounds, col_bounds
      @id = id || '_'
      @match = Regexp.new(match || '.*')
      @valid = Square.new(
        Spec.new(rows || '0:*').range(0, row_bounds),
        Spec.new(columns || '0:*').range(0, col_bounds))
    end

    attr_reader :id, :match, :valid

    def matches ss, row, col
      @valid.include? row, col and (ss[row,col] || '').to_s =~ @match
    end
  end

  class Spec
    def initialize spec
      @spec = spec.to_s
      raise "invalid spec '#{@spec}'" if @spec !~ /[+-]?([0-9]+|\*)(:[+-]?([0-9]+|\*))?/
    end

    # + or - means relative to num, otherwise absolute
    def range num, bounds
      bits = @spec.split ":"
      s = bits.size == 1 ? @spec : bits[0]
      e = bits.size == 1 ? @spec : bits[1]
      range_start(num, bounds, s) .. range_end(num, bounds, e)
    end

  private

    def range_start num, bounds, spec
      if spec == '+*' or spec == '*'
        num + 1
      elsif spec == '-*' 
        bounds.min
      elsif spec[0] == '+' or spec[0] == '-'
        offset = spec[1, spec.length - 1].to_i
        spec[0] == '+' ? (num + offset) : (num - offset)
      else
        spec.to_i
      end
    end

    def range_end num, bounds, spec
      if spec == '+*' or spec == '*'
        bounds.max
      elsif spec == '-*' 
        num - 1
      elsif spec[0] == '+' or spec[0] == '-'
        offset = spec[1, spec.length - 1].to_i
        spec[0] == '+' ? (num + offset) : (num - offset)
      else
        spec.to_i
      end
    end
  end

  class Edge
    def initialize from, to, vert, horiz
      @from, @to = from, to
      @vert = Spec.new(vert || '+0')
      @horiz = Spec.new(horiz || '+0')
    end

    attr_reader :from, :to

    def get_square row, col, row_bounds, col_bounds
       Square.new(
        @vert.range(row, row_bounds),
        @horiz.range(col, col_bounds))
    end
  end

  class Spreadsheet
    def initialize arr_of_rows
      @data = arr_of_rows
      @row_bounds = @data.bounds
      @col_bounds = @data.empty? ? (0...0) : @data[0].bounds
    end

    def [] row, col
      if @row_bounds.include? row and @col_bounds.include? col
        @data[row][col]
      else
        nil
      end
    end

    attr_reader :row_bounds, :col_bounds
  end

  class Results
    def initialize edges, nodes, ss, root
      @ss, @root = ss, root
      @edges_byfrom = Hash.new {|h,k| h[k] = [] }
      edges.each {|edge| @edges_byfrom[edge.from] << edge }
      @nodes_byid = Hash.new
      nodes.each {|node| @nodes_byid[node.id] = node}
    end

    include Enumerable

    # start at root, looking for trees
    def each
      @root.valid.each {|row, col|
        matches(row, col, @root).each { |match| yield match }
      }
    end

  private

    def matches row, col, node
      return [] if !node.matches(@ss, row, col)

      me = {node.id => @ss[row,col]}
      edges = @edges_byfrom[node.id]
      return [me] if edges.empty?

      # get array with dims:
      # (1) each edge from this
      # -- we flatten the square-for-each-edge dim
      # (2) each match (a Hash) from edge
      edge_matches = edges.map do |edge|
        to = @nodes_byid[edge.to]
        sq = edge.get_square(row, col, @ss.row_bounds, @ss.col_bounds)
        paths = sq.flat_map do |sq_row, sq_col| 
          matches sq_row, sq_col, to
        end
        paths.select {|a| !a.empty?}
      end

      [me].product(*edge_matches).map do |assignments_arr|
        assignments_arr.inject Hash.new, :merge
      end
    end

  end
end

