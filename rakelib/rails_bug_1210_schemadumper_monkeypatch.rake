# Extracted from Rails 2.3.10's active_record/schema_dumper.rb, with our patch applied.
# Put this into rakelib/rails_bug_1210_schemadumper_monkeypatch.rake in your Rails project
# see https://rails.lighthouseapp.com/projects/8994/tickets/1210-table_name_prefix-with-dbschemaload-causes-double-prefixes#ticket-1210-9
#--
# Copyright (c) 2004-2010 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'active_record/version'
# Compatible versions -- You can add versions to this as long as active_record/schema_dumper.rb hasn't changed.
raise "This monkey-patch only applies to 2.3.6 <= Rails <= 2.3.14" unless %w( 2.3.6 2.3.7 2.3.8 2.3.9 2.3.10 2.3.11 2.3.12 2.3.13 2.3.14 ).include?(ActiveRecord::VERSION::STRING)

require 'active_record/schema_dumper'

module ActiveRecord
  class SchemaDumper    # reopen

    private

      def tables(stream)
        @connection.tables.sort.each do |tbl|
          next unless strip_table_name_affixes(tbl)   # If using table_name_prefix/table_name_suffix, only dump the matching tables
          next if ['schema_migrations', ignore_tables].flatten.any? do |ignored|
            case ignored
            when String; strip_table_name_affixes(tbl) == ignored
            when Regexp; strip_table_name_affixes(tbl) =~ ignored
            else
              raise StandardError, 'ActiveRecord::SchemaDumper.ignore_tables accepts an array of String and / or Regexp values.'
            end
          end 
          table(tbl, stream)
        end
      end

      def table(table, stream)
        columns = @connection.columns(table)
        begin
          tbl = StringIO.new

          # first dump primary key column
          if @connection.respond_to?(:pk_and_sequence_for)
            pk, pk_seq = @connection.pk_and_sequence_for(table)
          elsif @connection.respond_to?(:primary_key)
            pk = @connection.primary_key(table)
          end
          
          tbl.print "  create_table #{strip_table_name_affixes(table).inspect}"
          if columns.detect { |c| c.name == pk }
            if pk != 'id'
              tbl.print %Q(, :primary_key => "#{pk}")
            end
          else
            tbl.print ", :id => false"
          end
          tbl.print ", :force => true"
          tbl.puts " do |t|"

          # then dump all non-primary key columns
          column_specs = columns.map do |column|
            raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" if @types[column.type].nil?
            next if column.name == pk
            spec = {}
            spec[:name]      = column.name.inspect
            spec[:type]      = column.type.to_s
            spec[:limit]     = column.limit.inspect if column.limit != @types[column.type][:limit] && column.type != :decimal
            spec[:precision] = column.precision.inspect if !column.precision.nil?
            spec[:scale]     = column.scale.inspect if !column.scale.nil?
            spec[:null]      = 'false' if !column.null
            spec[:default]   = default_string(column.default) if column.has_default?
            (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k.inspect} => ")}
            spec
          end.compact

          # find all migration keys used in this table
          keys = [:name, :limit, :precision, :scale, :default, :null] & column_specs.map(&:keys).flatten

          # figure out the lengths for each column based on above keys
          lengths = keys.map{ |key| column_specs.map{ |spec| spec[key] ? spec[key].length + 2 : 0 }.max }

          # the string we're going to sprintf our values against, with standardized column widths
          format_string = lengths.map{ |len| "%-#{len}s" }

          # find the max length for the 'type' column, which is special
          type_length = column_specs.map{ |column| column[:type].length }.max

          # add column type definition to our format string
          format_string.unshift "    t.%-#{type_length}s "

          format_string *= ''

          column_specs.each do |colspec|
            values = keys.zip(lengths).map{ |key, len| colspec.key?(key) ? colspec[key] + ", " : " " * len }
            values.unshift colspec[:type]
            tbl.print((format_string % values).gsub(/,\s*$/, ''))
            tbl.puts
          end

          tbl.puts "  end"
          tbl.puts
          
          indexes(table, tbl)

          tbl.rewind
          stream.print tbl.read
        rescue => e
          stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
          stream.puts "#   #{e.message}"
          stream.puts
        end
        
        stream
      end

      def indexes(table, stream)
        if (indexes = @connection.indexes(table)).any?
          add_index_statements = indexes.map do |index|
            statment_parts = [ ('add_index ' + strip_table_name_affixes(index.table).inspect) ]
            statment_parts << index.columns.inspect
            statment_parts << (':name => ' + strip_table_name_affixes(index.name).inspect)
            statment_parts << ':unique => true' if index.unique

            index_lengths = index.lengths.compact if index.lengths.is_a?(Array)
            statment_parts << (':length => ' + Hash[*index.columns.zip(index.lengths).flatten].inspect) if index_lengths.present?

            '  ' + statment_parts.join(', ')
          end

          stream.puts add_index_statements.sort.join("\n")
          stream.puts
        end
      end

      # Remove the ActiveRecord::Base.table_name_prefix and
      # ActiveRecord::Base.table_name_suffix from a table name.
      #
      # Returns nil if the affixes are missing from the argument.
      def strip_table_name_affixes(table_name)
        regexp = /\A#{Regexp.quote(Base.table_name_prefix || "")}(.*)#{Regexp.quote(Base.table_name_suffix || "")}\Z/m
        return nil unless table_name =~ regexp
        $1
      end
  end
end