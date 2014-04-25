
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
    @valid.include? row, col and ss[row][col] =~ @match
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

