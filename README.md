mailmech
========

Administration of mailman lists using ruby and mechanize.

mailmech has two parts: mailmech.rb is the library, which is used by the frontend lists.rb


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

Examples
--------

- Statistics overview:

        lists.rb -F -x
    
        Statistics:
                        List |       Alias|       Total|        int.|        ext.|Domains ext.|             Comment
        ---------------------+------------+------------+------------+------------+------------+--------------------
                   vym-forum |       forum|          88|           1|          87|          53|  General Discussion
                   vym-devel |       devel|          43|           1|          42|          23|          Developers
             vym-translation |       trans|          17|           2|          15|           9|         Translators

- Find external domains of subscribers for three lists:

        lists.rb -l devel,trans,forum -s | grep domext
    
    
- Count mails in your own mailarchive:    

        lists.rb -F -X -l trans
        Processing 203 mails...
        Extended stats for "vym-translation":
          * Mails by internal senders (21):
              21 XXX@XXX.de                       

          * Mails by external senders (182):
              60 XXX@XXX.de                       
              15 XXX@XXX.cz                     
               9 XXX@XXX.info                      
               8 XXX@XXX.fr                         
               7 XXX@XXX.com.ar
               ...

    
Todo
----

- Add documentation
- Add error handling
- Gemify mailmech
- Implement more of the mailman interface in mailmech
