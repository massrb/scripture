#!/usr/bin/env ruby
require 'sqlite3'
require 'pathname'
require 'optparse'


# 3️⃣ Sample rows (multiple windows)
def print_row_window(db, table, offset, label)
  puts "--- #{label} ---"
  begin
    rows = db.execute("SELECT * FROM #{table} LIMIT 5 OFFSET #{offset}")

    if rows.empty?
      puts "(no rows in this range)"
    else
      rows.each_with_index do |row_hash, i|
        puts "Row #{offset + i}: #{row_hash.inspect}"
      end
    end
  rescue SQLite3::Exception => e
    puts "Error reading rows: #{e}"
  end
end

if ARGV.empty?
  puts "Error: Missing args"
  exit 1
end

mnemonic = ARGV[0]
db_path = ARGV[1]

class Inspector

  def initialize(mnemonic,db_path)
    @db_path = db_path
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

      samples = @db.execute("SELECT * FROM scriptures WHERE scriptureIndex LIKE ? LIMIT 5", ["% #{type}"])

      if samples.empty?
        puts "(no rows found for this type)"
      else
        samples.each_with_index do |r, i|
          puts "Row #{i}: #{r.inspect}"
        end
      end
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
      ORDER BY rowid DESC
      LIMIT 1000
      SQL

    if rows.empty?
      puts "(no rows found with #{@mnemonic})"
    else
      puts "ROWS for #{mnemonic}"
      rows.each_with_index do |r, i|
        puts "Row #{i}: #{r.inspect}"
      end
      puts "#{rows.size} ROWS"
    end
  end

  def inspect_db
    begin
     
    rescue SQLite3::Exception => e
      puts "Error reading scriptureIndex samples: #{e}"
    end
  end

end


options = { csv: false }

OptionParser.new do |opts|
  opts.on("-b", "--bible MNEUMONIC", "Bible Mnuemonic") do |id|
    puts 'mneumonic is ' + id.to_s
    options[:bible_mnemonic] = id
  end
  opts.on("--csv", "output CSV") do
    options[:csv] = true
  end
  opts.on("-s", "--skip FIELDS", "CSV fields to ommit") do |flds|
    options[:fields] = flds.split(/:/)
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


ins = Inspector.new(mnemonic, db_path)
ins.print_tables


   

