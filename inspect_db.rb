#!/usr/bin/env ruby
require "sqlite3"
require "pathname"


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

# Base directory where all paths should resolve from
BASE_DIR = "/Users/laruenceguild/source/kotlin/FOHSverseApp"

if ARGV.empty?
  puts "Usage: ruby inspect_db.rb relative/path/to/database.db"
  exit 1
end

# The path passed in is treated as relative to BASE_DIR
relative_path = ARGV[0]
db_path = File.expand_path(relative_path, BASE_DIR)

unless File.exist?(db_path)
  puts "Error: File not found: #{db_path}"
  exit 1
end

begin
  db = SQLite3::Database.new(db_path)
  db.results_as_hash = true
rescue SQLite3::Exception => e
  puts "Could not open database: #{e}"
  exit 1
end

puts "📘 Inspecting SQLite DB: #{db_path}"
puts "----------------------------------------"

tables = db.execute <<-SQL
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
  schema_info = db.execute("PRAGMA table_info(#{table})")

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
    count = db.get_first_value("SELECT COUNT(*) FROM #{table}")
    puts "Total rows: #{count}"
  rescue SQLite3::Exception => e
    puts "Error counting rows: #{e}"
  end

  # 3️⃣ Sample rows


  puts "--- Sample Rows ---"

  if table == "scriptures"
    puts "📖 Special sampling for 'scriptures' table based on last word of scriptureIndex"

    begin
      # Extract last word of scriptureIndex for each row, get distinct

      # Get all distinct scriptureIndex
      indices = db.execute("SELECT DISTINCT scriptureIndex FROM scriptures")
      # Extract last word in Ruby
      index_types = indices.map { |r| r["scriptureIndex"].split.last }.uniq.sort

      index_types.each do |type|
        puts "\n--- scriptureIndex type = #{type} (5 sample rows) ---"

        samples = db.execute("SELECT * FROM scriptures WHERE scriptureIndex LIKE ? LIMIT 5", ["% #{type}"])

        if samples.empty?
          puts "(no rows found for this type)"
        else
          samples.each_with_index do |r, i|
            puts "Row #{i}: #{r.inspect}"
          end
        end
      end

      begin
        rows = db.execute(<<-SQL)
        SELECT *
        FROM scriptures
        WHERE scriptureIndex LIKE '%FSPAN%'
        ORDER BY rowid DESC
        LIMIT 1000
        SQL

        if rows.empty?
          puts "(no rows found with FSPAN)"
        else
          rows.each_with_index do |r, i|
            puts "Row #{i}: #{r.inspect}"
          end
          puts "#{rows.size} ROWS"
        end

      rescue SQLite3::Exception => e
        puts "Error querying FSPAN rows: #{e}"
      end

    rescue SQLite3::Exception => e
      puts "Error reading scriptureIndex samples: #{e}"
    end
  else
    # Non-scriptures tables: default sampling windows
    print_row_window(db, table, 0, "First 5 rows (0–4)")


    puts "----------------------------------------"
  end
end
