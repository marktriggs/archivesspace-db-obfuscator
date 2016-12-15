ColumnDefinition = Struct.new(:name, :type, :options, :value)
ConstraintDefinition = Struct.new(:value)

class MySQLDumpParser

  BUFFER_SIZE = 4096
  NEWLINES = ["\n", "\r"]


  def initialize(handler)
    @handler = handler
    @eof = false
  end

  def parse(stream)
    @fh = stream
    @buffer = ''
    @buffer_offset = 0

    loop do
      fill_buffer!

      return if eof?

      if looking_at?('--') || looking_at?('/*')
        @handler.on_text(read_comment)
      elsif looking_at?("\r") || looking_at?("\n")
        @handler.on_text(read_newlines)
      elsif looking_at?('DROP TABLE')
        @handler.on_drop_table(read_to([';']))
        skip_over(NEWLINES)
      elsif looking_at?('CREATE TABLE')
        read_create_table
      elsif looking_at?('LOCK TABLES')
        @handler.on_lock(read_to([';']))
        skip_over(NEWLINES)
      elsif looking_at?('UNLOCK TABLES')
        @handler.on_unlock(read_to([';']))
        skip_over(NEWLINES)
      elsif looking_at?('INSERT ')
        read_insert
      else
        raise "Unknown input: #{@buffer[@buffer_offset..@buffer_offset + 70].inspect}"
      end
    end
  end

  private

  def eof?
    @eof
  end

  def looking_at?(s)
    fill_buffer!(s.length)

    return false if @buffer.length < s.length

    @buffer[@buffer_offset..-1].start_with?(s)
  end

  def read_comment
    read_to(NEWLINES, strip_trailing = false)
  end

  def read_newlines
    read_to(NEWLINES)
  end

  # Allow us to rewind even if we've just refilled the buffer
  BUFFER_OVERLAP = 1

  def fill_buffer!(min_length = 1)
    if (@buffer.length - @buffer_offset) < min_length
      unless @buffer == ''
        @buffer = @buffer[(@buffer_offset - BUFFER_OVERLAP)..-1]
        @buffer_offset = BUFFER_OVERLAP
      end

      next_input = @fh.read(BUFFER_SIZE - @buffer.length)

      @eof = true unless next_input

      unless @eof
        @buffer += next_input
      end
    end
  end

  def readchar
    fill_buffer!

    raise 'EOF' unless @buffer.length > 0

    ch = @buffer[@buffer_offset]
    @buffer_offset += 1

    ch
  end

  def read_to(delimiters, strip_trailing = true)
    result = ""

    while !delimiters.include?(ch = readchar)
      result << ch
    end

    skip_over(delimiters) if strip_trailing

    result
  end

  def rewind(places)
    @buffer_offset -= places
    raise "Oops" unless @buffer_offset >= 0
  end

  def skip_over(delimiters)
    loop do
      if @buffer_offset >= @buffer.length
        fill_buffer!
      end

      if delimiters.include?(@buffer[@buffer_offset])
        @buffer_offset += 1
      else
        break
      end
    end
  end

  def read_create_table
    # create table accession (...
    create_table = read_to(['('])
    column_defs = read_column_definitions

    options = read_to([';'])

    @handler.on_ddl(create_table, column_defs, options)
  end

  def read_insert
    # INSERT INTO `agent_contact` VALUES
    insert_into = read_to(['('])
    rewind(1)

    @handler.on_insert(insert_into,
                       to_enum(:read_values))
  end

  def read_values
    loop do
      # That's all values read
      if looking_at?(';')
        skip_over([';'])
        skip_over(NEWLINES)

        return
      end

      skip_over(['('])

      values = []

      while !looking_at?(')')
        if looking_at?("'")
          values << read_mysql_string
        elsif looking_at?('NULL')
          values << nil

          4.times {|_| readchar }
        else
          values << read_integer
        end

        skip_over([','])
      end

      skip_over([')'])
      skip_over([','])

      yield values
    end
  end

  def read_mysql_string
    # Skip the leading '
    readchar

    result = ''

    while (ch = readchar) != "'"
      if ch == '\\'
        # Escaped character
        result << readchar
      else
        result << ch
      end
    end

    result
  end

  def read_integer
    result = ''

    while (ch = readchar) =~ /[-0-9]/
      result << ch
    end

    rewind(1)

    Integer(result)
  end

  def read_column_definitions
    result = []

    loop do
      skip_over(NEWLINES)

      break if looking_at?(')')

      definition = read_to(NEWLINES).strip

      break if definition.empty?

      definition = definition.gsub(/,\z/, '')

      if definition =~ /\A`(.*?)` (.+?)(?: (.*))?\Z/
        result << ColumnDefinition.new($1, $2, ($3 || ""), definition)
      else
        result << ConstraintDefinition.new(definition)
      end

    end

    result
  end

end
