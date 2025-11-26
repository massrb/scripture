
Utilities for creating bible scriptures from api.bible for different languages

The basic command to insert rows into the database is

ruby new_rows.rb -d <DATABASE_PATH> -b <BIBLE_MNEMONIC> -i  
-i specifies to insert the rows. 
Without -i, it's a trial run with any debug code without any insertions into the database

example:
ruby new_rows.rb -d scripture.db -b THAIKJV -i

The mneumonic THAIKJV is a mnemonic name that we are giving the particular bible version
such as the Thai King James etc. This should be a unique string. The new_rows module
looks into the config file for a match of that mnemonic in order to get the bible id that
api.bible uses. It also adds the mnemomic to the scripture index for each row that gets inserted. 
So new rows get scripture index of something like "(John 3:16 THAIKJV)" in this case.

The insertions happen by looking for all rows that have WEBUS in the scriptureIndex. From each of those rows, the particular verse for the target bible version is derrived and the api.bible url for the API call
is derrived to obtain the scripture needed for each row. 

