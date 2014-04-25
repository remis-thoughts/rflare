
class Array
  def bounds; 0 ... size; end
end

class Range
  def cap num
    num < min ? min : (num > max ? max : num)
  end
end

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
  def initialize node, row_bounds, col_bounds
    @id = node[:id] || 0,
    @match = Regexp.new(node[:match] || '.*'),
    @valid = Square.new(
      parse_range(node[:columns], col_bounds),
      parse_range(node[:rows], row_bounds))
  end

  attr_reader :id, :match, :columns, :rows

  def matches ss, row, col
    @valid.include? row, col and (ss[row,col] || '') =~ @match
  end

  private

  def parse_range it, bounds
    if it.nil?
      bounds
    elsif it.is_a? Numeric
      it .. it
    elsif it.is_a? Array
      if it.empty?
        bounds
      elsif it.size == 1
        bounds.cap(it[0] || bounds.min) .. bounds.max
      else
        bounds.cap(it[0] || bounds.min) .. bounds.cap(it[1] || bounds.max)
      end
    else
      raise "invalid range '#{it}'"
    end
  end
end

class Edge
  def initialize edge
    @from, @to = edge[:from], edge[:to]
    raise "edges need 'from' and 'to'" if @from.nil? or @to.nil?
    @vert = edge[:vert] || '+0'
    @horiz = edge[:horiz] || '+0'
    
  end

  attr_reader :from, :to

  def get_square row, col, row_bounds, col_bounds
     Square.new(
      get_range(row, row_bounds, @vert),
      get_range(col, col_bounds, @horiz))
  end

  private

  # spec like[+-]?([0-9]+|\*)
  # + or - means relative to num, otherwise absolute
  def get_range num, bounds, spec
    if spec == '+*'
      if num >= bounds.max
        num ... num # empty
      else
        bounds.cap(num + 1) .. bounds.max
      end
    elsif spec == '-*' 
      bounds.min ... bounds.cap(num)
    elsif spec[0] == '+' or spec[0] == '-'
      offset = spec[1, spec.length - 1].to_i
      col = spec[0] == '+' ? (num + offset) : (num - offset)
      col .. col
    else
      raise "invalid spec #{spec}"
    end
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

