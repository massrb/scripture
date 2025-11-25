#!/usr/bin/env ruby
require 'sqlite3'
require 'pathname'
require 'optparse'


class Inspector

  def initialize(options)
    @db_path = options[:db_path]
    @mnemonic = options[:mnemonic]
    @check_nulls = options[:check_nulls]
    if options[:csv]
      @csv = true
      @ignorable_fields = options[:ignorable_fields]
    end
    unless File.exist?(@db_path)
      puts "Error: File not found: #{@db_path}"
      exit 1
    end

    begin
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = true
    rescue SQLite3::Exception => e
      puts "Could not open database: #{e}"
      exit 1
    end
  end

  def print_all_sample_rows
    indices = @db.execute("SELECT DISTINCT scriptureIndex FROM scriptures")
    # Extract last word in Ruby
    index_types = indices.map { |r| r["scriptureIndex"].split.last }.uniq.sort

    index_types.each do |type|
      puts "\n--- scriptureIndex type = #{type} (5 sample rows) ---"

      samples = @db.execute("SELECT * FROM scriptures WHERE scriptureIndex LIKE ?", ["% #{type}"])

      if samples.empty?
        puts "(no rows found for this type)"
      else
        samples.each_with_index do |r, i|
          puts "Row #{i}: #{r.inspect}"
          break if i >= 5
        end
      end
      puts "Total Rows For #{type}: #{samples.size}"
    end
  end

  def print_tables
    puts "📘 Inspecting SQLite DB: #{@db_path}"
    puts "----------------------------------------"

    tables = @db.execute <<-SQL
      SELECT name
      FROM sqlite_master
      WHERE type='table'
      ORDER BY name;
    SQL

    if tables.empty?
      puts "No tables found."
      exit
    end

    tables.each do |row|
      table = row["name"]
      puts "\n=== 🗂️  Table: #{table} ==="

      # 1️⃣ Full schema
      puts "\n--- Schema ---"
      schema_info = @db.execute("PRAGMA table_info(#{table})")

      schema_info.each do |col|
        cid      = col["cid"]
        name     = col["name"]
        ctype    = col["type"]
        notnull  = col["notnull"] == 1 ? "YES" : "NO"
        default  = col["dflt_value"]
        pk       = col["pk"] == 1 ? "YES" : "NO"

        puts <<~FIELD
          • Column: #{name}
            - Type: #{ctype}
            - Not Null: #{notnull}
            - Default: #{default.inspect}
            - Primary Key: #{pk}
        FIELD
      end
      # 2️⃣ Row count
      puts "--- Row Count ---"
      begin
        count = @db.get_first_value("SELECT COUNT(*) FROM #{table}")
        puts "Total rows: #{count}"
      rescue SQLite3::Exception => e
        puts "Error counting rows: #{e}"
      end
      if table == "scriptures"
        print_all_sample_rows
      end
    end
  end

   def print_sample_rows
    rows = @db.execute(<<-SQL)
      SELECT *
      FROM scriptures
      WHERE scriptureIndex LIKE '%#{@mnemonic}%'
      ORDER BY id ASC
      LIMIT 1000
    SQL

    if rows.empty?
      puts "(no rows found with #{@mnemonic})"
      return
    end

    if @csv
      # --- CSV MODE ---
      # Print header row (column names)
      headers = rows.first.keys.reject { |k| k.is_a?(Integer) }
      headers = headers - @ignorable_fields if @ignorable_fields.is_a?(Array)

      # Print each row as CSV
      puts headers.join(",")
      rows.each do |row|
        values = headers.map { |h| row[h].to_s.gsub(",", " ") }
        puts values.join(",")
      end

    else
      # --- NORMAL MODE ---
      puts "ROWS for #{@mnemonic}"
      rows.each_with_index do |r, i|
        puts "Row #{i}: #{r.inspect}"
      end
      puts "#{rows.size} ROWS"
    end
  end

  def inspect_db
    begin

      if @check_nulls
        cols = @db.execute("PRAGMA table_info('scriptures')").map { |row| row["name"] }

        # Build the WHERE clause: (col1 IS NULL OR col1 = '') OR (col2 IS NULL OR col2 = '') ...
        conditions = cols.map { |c| "(#{c} IS NULL OR #{c} = '')" }.join(" OR ")

        sql = "SELECT * FROM scriptures WHERE #{conditions}"
        puts "SQL: " + sql
        rows = @db.execute(sql)
        puts rows.count.to_s
        rows.each{|r| puts r.inspect }
      elsif @mnemonic
        print_sample_rows
      else
        print_all_sample_rows
      end
     
    rescue SQLite3::Exception => e
      puts "Error inspecting database: #{e}"
      puts e.backtrace.first(20).join("\n")
    end
  end

end


options = { csv: false }

OptionParser.new do |opts|
  opts.on("-b", "--bible MNEUMONIC", "Bible Mnuemonic") do |id|
    options[:mnemonic] = id
  end
  opts.on("--nulls", "check for blank or null fields") do
    options[:check_nulls] = true
  end
  opts.on("--csv", "output CSV") do
    options[:csv] = true
  end
  opts.on("-s", "--skip FIELDS", "CSV fields to ommit") do |flds|
    options[:ignorable_fields] = flds.split(/:/)
  end
  opts.on("-d", "--db PATH", "Path to DB") do |path|
    options[:db_path] = path
  end
end.parse!

if options[:db_path].nil?
  puts "Error: --db path to database is required"
  puts parser
  exit 1
end

ins = Inspector.new(options)
ins.inspect_db


   

