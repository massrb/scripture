require "sqlite3"
require "yaml"

TABLE   = "scriptures"
LANGUAGE_KEY_COL  = "languageKey"

class Migrator

  def initialize(db_filename)
    unless db_filename
      puts "Usage: ruby add_column.rb path/to/database.db"
      exit 1
    end

    # Open the SQLite database
    @db = SQLite3::Database.new(db_filename)
    @db.results_as_hash = true

    # Check existing columns
    columns = @db.execute("PRAGMA table_info('#{TABLE}')")
    @column_names = columns.map { |row| row['name'] }  # 'name' is the column name in hash
    @config = YAML.load_file('config.yaml')
  end

  def add_column
    unless @column_names.include?(LANGUAGE_KEY_COL)
      @db.execute <<~SQL
        ALTER TABLE #{TABLE}
        ADD COLUMN #{LANGUAGE_KEY_COL} TEXT;
      SQL
      puts "Added column #{LANGUAGE_KEY_COL} to #{TABLE}"
    else
      puts "Column #{LANGUAGE_KEY_COL} already exists in #{TABLE}"
    end
  end

  def update_language_index(id, val)
    @db.execute(
      <<~SQL,
      UPDATE #{TABLE}
      SET languageKey = ?
      WHERE id = ?;
      SQL
      [val, id]
    )
  end

  def migrate
    rows = @db.execute(<<-SQL)
      SELECT *
      FROM #{TABLE}
      ORDER BY id ASC
    SQL

    cur_mnemonic = nil
    lang = nil
    rows.each do |row|
      # puts row.inspect
      langIdx = row['languageKey']
      srcIdx = row['scriptureIndex']
      if langIdx.nil? || langIdx.strip.empty?
        if mat = srcIdx.match(/\(([^()]+)\s+([A-Z0-9_-]+)\)/)
          mnemonic = mat[2]  
          if mnemonic != cur_mnemonic
            bible_config = @config['bibles'].find {|el| el['mnemonic'] == mnemonic}
            lang = bible_config['language']
            cur_mnemonic = mnemonic
          end
        end
        txt = nil
        if lang == 'ENGLISH'
          txt = row['scriptureIndex']
        else
          book_map = @config['BOOKS'][lang]
          if mat = srcIdx.match(/\(\s*([1-3]?\s*[A-Za-z]+(?:\s+[A-Za-z]+)*)\b/)
            word = mat[1]
            new_word = book_map[word]
            val = srcIdx.gsub(word,new_word)
            update_language_index(row['id'], val)
          end
        end
      end
    end
  end

end
migrator = Migrator.new(ARGV[0])
migrator.add_column
migrator.migrate







