require_relative 'text_scrambler'
require 'set'
require 'json'

class ObfuscatingParseHandler

  def initialize
    @scrambler = TextScrambler.new
    @table_defs = {}
  end

  def on_ddl(create_table, columns, options)
    if create_table =~ /CREATE TABLE `(.*?)`/
      @table_defs[$1] = columns.select {|column_def| column_def.is_a?(ColumnDefinition)}
    end

    puts create_table
    print " (\n  "
    puts columns.map(&:value).join(",\n  ")
    puts options
    puts ";"
  end

  def on_text(text)
    puts text
  end

  def on_lock(statement)
    print statement, ";\n"
  end

  def on_unlock(statement)
    print statement, ";\n"
  end

  def on_drop_table(statement)
    print statement, ";\n"
  end

  def mysql_escape(s)
    escaped = s.clone

    escaped.gsub!(/\\/, Regexp.quote('\\\\'))
    escaped.gsub!(/'/, Regexp.quote("\\'"))
    escaped.gsub!(/"/, Regexp.quote('\\"'))

    escaped
  end

  UNSCRAMBLED_TABLE_COLUMNS = Set.new([
                                        ['permission', 'permission_code'],
                                        ['enumeration', 'name'],
                                        ['enumeration_value', 'value'],
                                        ['resource', 'identifier'],
                                        ['accession', 'identifier'],
                                        ['container', 'container_extent'],
                                        ['container_profile', 'width'],
                                        ['container_profile', 'depth'],
                                        ['container_profile', 'height'],
                                        ['container_profile', 'stacking_limit'],
                                        ['user', 'agent_record_type'],
                                        ['collection_management', 'processing_hours_per_foot_estimate'],
                                        ['collection_management', 'processing_total_extent'],
                                        ['collection_management', 'processing_hours_total'],
                                        ['date', 'begin'],
                                        ['date', 'end'],
                                        ['subnote_metadata', 'guid'],
                                        ['system_event', 'title'],
                                        ['system_event', 'message'],
                                      ])

  UNSCRAMBLED_COLUMNS_ANY_TABLE = Set.new(['real_1', 'real_2', 'real_3', 'integer_1', 'integer_2', 'integer_3',
                                           'jsonmodel_type'])

  UNSCRAMBLED_DATA_TYPES = Set.new(['datetime', 'date', 'timestamp'])

  def on_insert(insert_into, values_enum)
    table = if insert_into =~ /INSERT INTO `(.*?)`/
              $1
            end

    raise 'Unknown table' unless table

    column_defs = @table_defs.fetch(table)

    puts insert_into

    values_enum.each_with_index do |values, idx|
      puts "," if idx > 0

      print "("
      print values.each_with_index.map {|value, column_idx|
        this_column = column_defs.fetch(column_idx)

        if value.is_a?(String)
          if table == 'note' && this_column.name.downcase == 'notes'
            value = clean_note_json(value)
          elsif table == 'auth_db' && this_column.name.downcase == 'pwhash'
            # password is always 'admin'
            value = '$2a$10$bq/XuojTCE1UtnAEiU5Mkux0lEAKXa9yl/d4.h3CcZB/hNWDeGJPe'
          else
            normalised_column = this_column.name.downcase

            if UNSCRAMBLED_TABLE_COLUMNS.include?([table, normalised_column]) ||
               UNSCRAMBLED_COLUMNS_ANY_TABLE.include?(normalised_column) ||
               UNSCRAMBLED_DATA_TYPES.include?(this_column.type.downcase)
            # Don't scramble
            else
              value = @scrambler.call(value)
            end
          end

          "'" << mysql_escape(value) << "'"
        elsif value.nil?
          "NULL"
        else
          value.to_s
        end
      }.join(',')
      print ")"
    end

    puts ";"
  end

  def clean_note_json(s)
    notes = JSON.parse(s)

    clean_notes(notes)

    JSON.dump(notes)
  end

  def clean_notes(notes)
    if notes.is_a?(Hash)
      if notes['content']
        if notes['content'].is_a?(Array)
          notes['content'] = notes['content'].map {|text|
            @scrambler.call(text)
          }
        else
          notes['content'] = @scrambler.call(notes['content'])
        end
      else
        notes.each do |k, v|
          clean_notes(v)
        end
      end

      if notes['items']
        notes['items'] = notes['items'].map {|item|
          if item.is_a?(String)
            @scrambler.call(item)
          else
            clean_notes(item)
          end
        }
      end

      ["actuate", "arcrole", "href", "role", "show", "title", "type", "value", "reference_text"].each do |attr|
        if notes[attr] && notes[attr].is_a?(String)
          notes[attr] = @scrambler.call(notes[attr])
        end
      end

    elsif notes.is_a?(Array)
      notes.each do |elt|
        clean_notes(elt)
      end
    else
      notes
    end
  end

end
