#!/usr/bin/env ruby
require "sqlite3"
require 'uri'
require "pathname"
require 'net/http'
require 'json'
require "nokogiri"
require "yaml"
require 'optparse'
require 'ostruct'

file = "translator.rb"

if File.exist?(file)
  require_relative file
else
  puts "Optional file not found: #{file}"
end


FOHS = {
  REINAVAL:{
    "FAITHFULNESS" => "Fe",
    "GENTLENESS"   => "Mansedumbre",
    "GOODNESS"     => "Bondad",
    "JOY"          => "Gozo",
    "KINDNESS"     => "Amabilidad",
    "LOVE"         => "Amor",
    "PATIENCE"     => "Paciencia",
    "PEACE"        => "Paz",
    "SELF_CONTROL" => "Dominio propio"
  },
  THAIKJV: {
    "FAITHFULNESS"  => "ความซื่อสัตย์",
    "GENTLENESS"    => "ความอ่อนโยน",
    "GOODNESS"      => "ความดี",
    "JOY"           => "ความชื่นชม",
    "KINDNESS"      => "ความเมตตา",
    "LOVE"          => "ความรัก",
    "PATIENCE"      => "ความอดทน",
    "PEACE"         => "ความสงบ",
    "SELF_CONTROL"  => "การควบคุมตนเอง"
  }
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
  "Psalm"            => "PSA",
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

# from api.bible
API_PATH = "https://rest.api.bible/v1/bibles"

TABLE_NAME = 'scriptures'

def fetch_passage(url, api_key)
  uri = URI(url)

  request = Net::HTTP::Get.new(uri)
  request['api-key'] = api_key   # <-- header required by API.Bible
  puts "USE KEY:<#{api_key}>"
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.code.to_i != 200
    puts response.inspect
    raise "API Fetch failed with http code #{response.code}"
  end
  return JSON.parse(response.body)
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

class ScriptureInserter

  def initialize(options)
    @db_path = options[:db_path]
    @rebuild_db_path = options[:rebuild_db_path]
    @options = options
    @config = YAML.load_file('config.yaml')
    @mnemonic = @options[:bible_mnemonic].to_s
    rec = @config['bibles'].find {|el| el['mnemonic'] == @mnemonic}
    @target_language = options[:target_language]
    @translator = Translator.new if defined?(Translator) && @target_language

    if rec
      rec.keys.each{|k| @config[k] = rec[k]}
    end
    @bible_id = @config['bible_id']
    @api_key = @config['api_key']
    @recs_to_process = @config['recs_to_process']

    unless File.exist?(@db_path)
      puts "Error: File not found: #{@db_path}"
      exit 1
    end

    begin
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = true
      if @rebuild_db_path
        @db_rebuild = SQLite3::Database.new(@rebuild_db_path)
        @db_rebuild.results_as_hash = true
      end
    rescue SQLite3::Exception => e
      puts "Could not open database: #{e}"
      exit 1
    end
  end

  def db_insert(text, fohskey, scripture_index, fohs=nil)
    puts "INSERT!"
    begin
      # scripture_index = "(#{book} FSPAN)"

      fohs = FOHS[@mnemonic.to_sym][fohskey] if fohs.nil?
      puts "#{fohskey}=#{fohs}"
      @db.execute(
        "INSERT INTO scriptures (scriptureIndex, fohskey, fohs, text) VALUES (?, ?, ?, ?)",
        [scripture_index, fohskey, fohs, text]
      )
      puts "Row inserted successfully for #{scripture_index}!"
    rescue SQLite3::Exception => e
      puts "Error inserting row: #{e}"
    end
  end


  def print_summary
    begin
      @recs_to_process = @config['recs_to_process']
      count = @db.get_first_value("SELECT COUNT(*) FROM #{TABLE_NAME}")
      puts "Total rows: #{count} in table #{TABLE_NAME}"
      # Total row count for all scriptureIndex ending with 'WEBUS'
      count = @db.get_first_value("SELECT COUNT(*) FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)'")
      fohskeys = @db.execute("SELECT DISTINCT fohskey FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)' ORDER BY fohskey")
      fohs_list = fohskeys.map { |r| r['fohskey'] }.join(', ')
      puts "FOHS Keys Found (#{fohskeys.length} types): #{fohs_list}\n"
      

    rescue SQLite3::Exception => e
      puts "Error printing database summary: #{e}"
    end
  end

  def get_rebuild_text(rec)
    row = @db_rebuild.execute("SELECT text FROM scriptures WHERE scriptureIndex = ? AND fohskey = ? LIMIT 1",
      [rec.db_target_index, rec.fohskey]).first
    row&.[]("text")
  end

  def source_records
    samples = @db.execute("SELECT * FROM scriptures WHERE scriptureIndex LIKE '%WEBUS)' LIMIT #{@recs_to_process}")
    if samples.empty?
      puts "no source rows found"
    else
      puts "\n--- scriptureIndex ending in WEBUS (#{samples.count} total rows - source rows) ---"
    end
    samples.each do |row|
      
      db_source_index = row["scriptureIndex"]  # get the field'
      if db_source_index.nil? || db_source_index.strip.empty?
        puts "\nRow #{i}: (no scriptureIndex)"
        next
      end

      fohskey = row['fohskey']
      parts = db_source_index.gsub(/[()]/, '').split
      source_bible_version = parts.pop       # 'WEBUS'
      reference = parts.join(' ')  # e.g., "1 John 4:8"
      # cleaned = scripture_index.gsub(/[()]/, '').strip

      # Find the chapter:verse token (last token before version)
      chapter_verse = parts.pop   # e.g. "3:14"
      book = parts.join(' ')

      api_book_code = BOOK_NAME_TO_CODE[book]
      chapter, verse = chapter_verse.split(':')
      db_target_index = "(#{book} #{chapter}:#{verse} #{@mnemonic})"

      db_match = @db.get_first_value(
        "SELECT 1 FROM scriptures WHERE scriptureIndex = ? AND fohskey = ? LIMIT 1",
        [db_target_index, fohskey]
      ) ? true : false

      matching_row = @db.get_first_row(
        "SELECT * FROM scriptures WHERE scriptureIndex = ? AND fohskey = ? LIMIT 1",
        [db_target_index, fohskey]
        )

      db_match = !matching_row.nil?
      if db_match
        empty_text = (matching_row["text"].nil? || matching_row["text"].strip.empty? || 
                      matching_row['fohs'].nil? || matching_row['fohs'].strip.empty?)
      end

      # 3:17 or 3:17-16
      if verse =~ /(\d+)-(\d+)/
        # JHN.13.34-JHN.13.35
        api_verse_code = "#{api_book_code}.#{chapter}.#{$1}-#{api_book_code}.#{chapter}.#{$2}"
      else
        api_verse_code = "#{api_book_code}.#{chapter}.#{verse}"
      end

      api_url = "#{API_PATH}/#{@bible_id}/passages/#{api_verse_code}"

      yield OpenStruct.new(db_source_index: db_source_index, fohskey: fohskey, 
                 text: row['text'], bible_version: source_bible_version, api_book_code: api_book_code, 
                 api_verse_code: api_verse_code, api_url: api_url, db_target_index: db_target_index,
                 db_match: db_match, empty_text: empty_text)

    end
    puts "Processed #{samples.count} source records"
  end

  def parse_result(result)
    # p result
    html = result["data"]&.[]("content")
    
    # next if html.nil?
    puts "HTML:"
    p html
    if html.nil?
      puts 'EXIT no result to parse'
      exit
    end
    doc = Nokogiri::HTML.fragment(html)

    # Remove all <span class="v"> tags
    doc.css('span.v').remove
    doc.text.strip
  end

  def process_rows
    count = 0
    insert_count = 0
    begin
      source_records do |rec|
        count += 1
        puts "*******************"
        puts rec.inspect
        if !rec.db_match || rec.empty_text
          puts "Missing match for #{rec.db_target_index} - #{rec.fohskey} count: #{insert_count}"
          if @options[:insert]
            if @db_rebuild
              text = get_rebuild_text(rec)
              db_insert(text, rec.fohskey, rec.db_target_index)
            elsif @translator
              text = @translator.convert(rec.text)
              fohs = @translator.convert(rec.fohskey)
              if rec.empty_text
                puts "UPDATE text"
                @db.execute(
                  "UPDATE scriptures SET text = ?, fohs = ? WHERE scriptureIndex = ? AND fohskey = ?",
                  [text, fohs, rec.db_target_index, rec.fohskey]
                )
              else
                db_insert(text, rec.fohskey, rec.db_target_index, fohs)
              end
            else
              puts "API URL: #{rec.api_url}"
              result = fetch_passage(rec.api_url, @api_key)
              text = parse_result(result)
              db_insert(text, rec.fohskey, rec.db_target_index)
            end
            insert_count += 1
            # sleep(15) if (insert_count + 1) % 10 == 0
            if insert_count >= 400
              puts "EXIT, inserted #{insert_count} records"
              exit
            end
          end
        else
          p rec
        end
        exit if count >= 1000
      end
    rescue StandardError => e
      puts "Error processing rows: #{e}"
      puts e.backtrace.first(20).join("\n")
    end
  end

end


options = { insert: false }

OptionParser.new do |opts|
  opts.on("-b", "--bible MNEUMONIC", "Bible Mnuemonic") do |id|
    puts 'mneumonic is ' + id.to_s
    options[:bible_mnemonic] = id
  end
  opts.on("--insert", "Enable DB insertions") do
    options[:insert] = true
  end
  opts.on("-r", "--rebuild PATH", "Path to DB to rebuild from") do |path|
    options[:rebuild_db_path] = path
  end
  opts.on("-d", "--db PATH", "Path to DB") do |path|
    options[:db_path] = path
  end
  opts.on("-t", "--target LANGUAGE", "Convert to target language") do |lang|
    options[:target_language] = lang
  end
end.parse!

if options[:bible_mnemonic].nil?
  puts "Error: --bible mnemonic is required"
  puts parser
  exit 1
elsif options[:db_path].nil?
  puts "Error: --db path to database is required"
  puts parser
  exit 1
end


inserter = ScriptureInserter.new(options)
inserter.process_rows

