mailmech
========

Administration of mailman lists using ruby and mechanize.


Current list of options
-----------------------


Usage: lists.rb [options]
    -a, --add a,b,c                  Subscribe list or FILE (csv: email,company)
    -c, --company STRING             Company
    -F, --configuration STRING       Configuration file
    -d, --debug                      Output more information
    -D, --delete a,b,c               Delete subscribers
        --delete-external            Delete external subscribers
    -n, --dry-run                    Dry run
        --edit-goodbye-msg           Edit goodbye message
        --edit-welcome-msg           Edit welcome message
        --get-goodbye-msg            Get goodbye message
        --get-welcome-msg            Get welcome message
    -s, --show                       Show subscriber list
    -m, --message STRING             Message to be logged
    -v, --no-verify                  Do not verify subscription
    -l, --list a,b,c                 Select list by ALIAS
    -x, --stats                      Print statistics
    -X, --xstats                     Print extended statistics


Installation
------------

You need to have ruby installed on your system and then install missing
gems, for example you will need the "mechanize" gem:

  gem install mechanize

Modify the example configuration in betaman.yaml to your needs.

Note: Passwords are currently saved as clear text, this may be a
      security risk.


Todo
----

- Add documentation
- Gemify mailmech
- Implement more of the mailman interface in mailmech
