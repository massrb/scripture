


# Bible Scripture Utilities  
Tools for generating multilingual Bible scripture entries using **api.bible** and inserting them into a database.

---

## 🔧 Overview  
This utility fetches Bible verses from **api.bible** for a specific translation and inserts them into a SQLite database.  
It uses a **mnemonic** (e.g., `THAIKJV`, `REINAVAL`) to identify and select the desired Bible version.

---

## 🚀 Basic Usage  
To insert rows into the database:

```bash
ruby new_rows.rb -d <DATABASE_PATH> -b <BIBLE_MNEMONIC> -i
```

The mneumonic THAIKJV is a mnemonic name that we are giving the particular bible version
such as the Thai King James etc. This should be a unique string. The new_rows module
looks into the config file for a match of that mnemonic in order to get the bible id that
api.bible uses. It also adds the mnemomic to the scripture index for each row that gets inserted. 
So new rows get scripture index of something like "(John 3:16 THAIKJV)" in this case.

The insertions happen by looking for all rows that have WEBUS in the scriptureIndex. From each of those rows, the particular verse for the target bible version is derrived and the api.bible url for the API call
is derrived to obtain the scripture needed for each row. 


