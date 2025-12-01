


# Bible Scripture Utilities  
Tools for generating multilingual Bible scripture entries using **api.bible** and inserting them into a database.

---

## 🔧 Overview  
This utility fetches Bible verses from **api.bible** for a specific translation and inserts them into a SQLite database.  
It uses a **mnemonic** (e.g., `THAIKJV`, `REINAVAL`) to identify and select the desired Bible version.

---

## Preperation

- copy config.yaml.example to config.yml. 
- fill in the value of api_key in config.yaml to a valid api key from api.bible
- you will need a database with scriptureIndexes containing WEBUS such as "(John 3:16 WEBUS)"

## 🚀 Basic Usage  
To insert rows into the database:

```bash
ruby new_rows.rb -d <DATABASE_PATH> -b <BIBLE_MNEMONIC> -i
```

## How Mnemonics Work

A mnemonic such as **`THAIKJV`** is a short, unique identifier representing a specific Bible version (for example, the Thai King James Version).  
The `new_rows` module uses this mnemonic in two ways:

1. **Configuration Lookup**  
   It searches the config file for the mnemonic to find the corresponding **api.bible `bibleId`** used for API requests.

2. **Scripture Index Tagging**  
   The mnemonic is appended to the `scriptureIndex` of each newly inserted row.  
   For example, a generated entry might look like: "(John 3:16 THAIKJV)"


---

## How Insertions Work

The insertion process begins by scanning the database for all rows whose `scriptureIndex` ends with **`WEBUS`**, which serves as the base or template version.  
For each WEBUS row:

1. The verse reference (e.g., `John 3:16`) is extracted.  
2. The corresponding URL for the target translation is constructed using the mnemonic’s `bibleId`.  
3. The verse text is retrieved from **api.bible**.
4. A new row is inserted into the database with the target translation’s mnemonic included in the `scriptureIndex`.

This allows the tool to generate full parallel scripture sets for any Bible version configured in your system.


---

## Fruits of the spirit field translations

The config.yaml file will have entries such as this

```bash
- bible_id: 2eb94132ad61ae75-01
    mnemonic: THAIKJV
    name: "Thai King James Version"
    language: THAI
```

 Using the 'language' entry, the translation will use that to index the FOHS table in the configuration in order to translate words such as peace, love, joy etc. These translations are used to populate the fohs fields.


---
## Translations Using Web Scraping

There is a **translation module** that can be adapted to work with websites providing a text input/output form—such as pages where you enter an English verse and receive a translated version.  
The only configuration required for this module is the **`translation_site`** value in the config file.

---

## Setup Instructions

To use the translator module:

1. **Copy the example files:**
   ```bash
   cp translator_example.rb translator.rb
   cp Gemfile.example Gemfile
   ```

2. **Install gems using ruby bundler** (if not already installed)

   ```bash
   bundle install
   ```

3. ***Modify translator.rb to scrape the website that you are using***

 - Each site would have different types of HTML etc

4. the command to run this module is

   ```bash
   ruby new_rows.rb -d scripture.db -b THAICONV -t th -i
   ```

 - -t specifies that the translation module is to be used.
 - 'th' here is not really used but is required and might be relevant for future use
 - the mnemonic specified with -b will be used as part of the scriptureIndex for the rows created

---

## Inspector tool

**List a sample of the different bible translations in the database**

  ```bash
  ruby inspect_db.rb  -d scripture.db
  ```

**List the rows for a particular bible version**

  ``` 
  ruby inspect_db.rb  -d scripture.db -b THAIKJV
  ```

**List rows as CSV**

  ```
  ruby inspect_db.rb  -d scripture.db THAIKJV -c
  ```

---

## Migration

**Migration utility**

The migration tool was used to add the languageKey field. 

conversions are found in the config.yaml file. Use a copy of the database

```
cp scripture_FOHSkey_database.db scripture_FOHSkey_database_v2.db

ruby migrate_db.rb scripture_FOHSkey_database_v2.db
```






