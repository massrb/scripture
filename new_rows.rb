#!/usr/bin/env ruby
require "sqlite3"
require 'uri'
require "pathname"
require 'net/http'
require 'json'
require "nokogiri"

FOHS_SPANISH = {
  "FAITHFULNESS" => "Fe",
  "GENTLENESS"   => "Mansedumbre",
  "GOODNESS"     => "Bondad",
  "JOY"          => "Gozo",
  "KINDNESS"     => "Amabilidad",
  "LOVE"         => "Amor",
  "PATIENCE"     => "Paciencia",
  "PEACE"        => "Paz",
  "SELF_CONTROL" => "Dominio propio"
}

BOOK_NAME_TO_CODE = {
  "Genesis"          => "GEN",
  "Exodus"           => "EXO",
  "Leviticus"        => "LEV",
  "Numbers"          => "NUM",
  "Deuteronomy"      => "DEU",
  "Joshua"           => "JOS",
  "Judges"           => "JDG",
  "Ruth"             => "RUT",
  "1 Samuel"         => "1SA",
  "2 Samuel"         => "2SA",
  "1 Kings"          => "1KI",
  "2 Kings"          => "2KI",
  "1 Chronicles"     => "1CH",
  "2 Chronicles"     => "2CH",
  "Ezra"             => "EZR",
  "Nehemiah"         => "NEH",
  "Esther"           => "EST",
  "Job"              => "JOB",
  "Psalms"           => "PSA",
  "Proverbs"         => "PRO",
  "Ecclesiastes"     => "ECC",
  "Song of Solomon"  => "SNG",
  "Isaiah"           => "ISA",
  "Jeremiah"         => "JER",
  "Lamentations"     => "LAM",
  "Ezekiel"          => "EZK",
  "Daniel"           => "DAN",
  "Hosea"            => "HOS",
  "Joel"             => "JOL",
  "Amos"             => "AMO",
  "Obadiah"          => "OBA",
  "Jonah"            => "JON",
  "Micah"            => "MIC",
  "Nahum"            => "NAM",
  "Habakkuk"         => "HAB",
  "Zephaniah"        => "ZEP",
  "Haggai"           => "HAG",
  "Zechariah"        => "ZEC",
  "Malachi"          => "MAL",
  "Matthew"          => "MAT",
  "Mark"             => "MRK",
  "Luke"             => "LUK",
  "John"             => "JHN",
  "Acts"             => "ACT",
  "Romans"           => "ROM",
  "1 Corinthians"    => "1CO",
  "2 Corinthians"    => "2CO",
  "Galatians"        => "GAL",
  "Ephesians"        => "EPH",
  "Philippians"      => "PHP",
  "Colossians"       => "COL",
  "1 Thessalonians"  => "1TH",
  "2 Thessalonians"  => "2TH",
  "1 Timothy"        => "1TI",
  "2 Timothy"        => "2TI",
  "Titus"            => "TIT",
  "Philemon"         => "PHM",
  "Hebrews"          => "HEB",
  "James"            => "JAS",
  "1 Peter"          => "1PE",
  "2 Peter"          => "2PE",
  "1 John"           => "1JN",
  "2 John"           => "2JN",
  "3 John"           => "3JN",
  "Jude"             => "JUD",
  "Revelation"       => "REV"
}



FREE_SPANISH_BIBLE_ID = '482ddd53705278cc-01'

API_PATH = "https://rest.api.bible/v1/bibles"


def fetch_passage(url, api_key)
  uri = URI(url)

  request = Net::HTTP::Get.new(uri)
  request['api-key'] = api_key   # <-- header required by API.Bible
  puts "USE KEY:<#{api_key}>"
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  return JSON.parse(response.body)
end

def db_insert(db, text, fohskey, book)
  puts "INSERT!"
  begin
    scripture_index = "(#{book} FSPAN)"

    fohs = FOHS_SPANISH[fohskey]
    puts "#{fohskey}=#{fohs}"
    db.execute(
      "INSERT INTO scriptures (scriptureIndex, fohskey, fohs, text) VALUES (?, ?, ?, ?)",
      [scripture_index, fohskey, fohs, text]
    )
    puts "Row inserted successfully for #{scripture_index}!"
  rescue SQLite3::Exception => e
    puts "Error inserting row: #{e}"
  end
end

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
api_key = ARGV[1]

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
    puts "📖 Printing all scriptureIndex ending with 'WEBUS' as a single group"

    begin
      # Total row count for all scriptureIndex ending with 'WEBUS'
      count = db.get_first_value("SELECT COUNT(*) FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)'")
      puts "\n--- scriptureIndex ending in WEBUS (#{count} total rows, showing 5 sample rows) ---"

      # NEW: get all distinct fohskey values for WEBUS rows
      fohskeys = db.execute("SELECT DISTINCT fohskey FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)' ORDER BY fohskey")
      fohs_list = fohskeys.map { |r| r['fohskey'] }.join(', ')

      puts "FOHS Keys Found (#{fohskeys.length} types): #{fohs_list}"
      puts "------------------------------------------------------------"

      # Fetch 5 sample rows for the group
      samples = db.execute("SELECT * FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)' LIMIT 2300")

      if samples.empty?
        puts "(no rows found)"
      else
        count = 0
        samples.each_with_index do |r, i|
          puts "Row #{i}: #{r.inspect}"

          scripture_index = r["scriptureIndex"]  # get the field'
          fohskey = r['fohskey']
    
          if scripture_index.nil? || scripture_index.strip.empty?
            puts "\nRow #{i}: (no scriptureIndex)"
            next
          end

          # Remove parentheses and version
          parts = scripture_index.gsub(/[()]/, '').split
          version = parts.pop       # 'WEBUS'
          reference = parts.join(' ')  # e.g., "1 John 4:8"
          cleaned = scripture_index.gsub(/[()]/, '').strip

          # Find the chapter:verse token (last token before version)
          chapter_verse = parts.pop   # e.g. "3:14"
          book = parts.join(' ')
          book_code = BOOK_NAME_TO_CODE[book]

          chapter, verse = chapter_verse.split(':')

          # 3:17 or 3:17-16
          if verse =~ /(\d+)-(\d+)/
            # JHN.13.34-JHN.13.35
            scripture_ref = "#{book_code}.#{chapter}.#{$1}-#{book_code}.#{chapter}.#{$2}"
          else
            scripture_ref = "#{book_code}.#{chapter}.#{verse}"
          end
          puts scripture_ref

          # URL encode
          encoded_reference = URI.encode_www_form_component(reference)
          
          # Spanish Free Bible Version (API.Bible) Bible ID
          bible_id = "482ddd53705278cc-01"
          
          # Build API URL
          url = "#{API_PATH}/#{bible_id}/passages/#{scripture_ref}"
          
          # Print
          puts "\nRow #{i}:"
          puts "  scriptureIndex: #{scripture_index}"
          puts "  Reference for API: #{reference}"
          puts "  Encoded: #{encoded_reference}"
          puts "  API URL: #{url}"


          result = fetch_passage(url, api_key)
          p result
          html = result["data"]&.[]("content")
          next if html.nil?
          puts "HTML:"
          p html
          doc = Nokogiri::HTML.fragment(html)

          # Remove all <span class="v"> tags
          doc.css('span.v').remove

          text = doc.text.strip
          puts "message:#{text}"
          target_index = "(#{book} #{chapter}:#{verse} FSPAN)"
          # Query
          row = db.get_first_row(
            "SELECT * FROM scriptures WHERE scriptureIndex = ? AND fohskey = ?", 
            [target_index, fohskey]
          )

          if row
            puts "skip #{target_index}"
          else
            count += 1
            db_insert(db, text, fohskey, "#{book} #{chapter}:#{verse}")
            # exit if count >= 10
          end
        end
      end
    rescue SQLite3::Exception => e
      puts "Error reading WEBUS scriptureIndex rows: #{e}"
    end
  else
    # Non-scriptures tables: default sampling windows
    print_row_window(db, table, 0, "First 5 rows (0–4)")
  end

end
