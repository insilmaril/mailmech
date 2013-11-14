#!/usr/bin/env ruby

require "#{ENV['PWD']}/mailmech"
require 'colorize'
require 'csv'
require 'logger'
require 'optparse'
require 'tempfile'
require 'yaml'

def logstring (action, list, email, company, message)
  ret = [] 
  list = " (#{list})" if !list.empty?
  ret << " \"#{email}\"" if !email.empty?
  ret << " \"#{company}\"" if !company.empty?
  ret << " \"#{message}\"" if !message.empty?
  return "#{action}#{list}: #{ret.join(",")}"
end

def logresult (list, action, target, success)
  if success
    result = "succeeded"
    color = :green
  else
    result = "failed"
    color = :red
  end
  s = sprintf("%46s %s\n", "Changing text #{result} (#{list}): ".colorize(color), target) 
  puts s
  if success
    $log.info(s)
  else
    $log.warn(s)
  end
end

def list_selected?
  if $options[:selected_list].empty? then
    puts "Please select one or more lists with \"-l ALIAS1,ALIAS2, ...\"!"
    exit
  end
end

def verify_deletion(lists, del)
  lists.each do |list|
    del.each do |n|
      ok = !$lists.member?(list,n.downcase)

      if ok then
        printf("%46s %s\n", "List subscription deleted (#{list}):".green, "#{n}") 
        $log.info( logstring("List subscription deleted", list, n, "", $options[:message]) )
      else
        printf("%46s %s\n", "List deletion failed (#{list}):".red,  "#{n}")
        $log.warn( logstring("List deletion failed", list, n, "", $options[:message]) )
      end
    end
  end
end

begin
  # Logging to list log
  $log = Logger.new("list.log")
  $log.info("Program started: #{$0} #{ARGV}")

  $options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: lists.rb [options]"

    $options[:add] = []
    opts.on( '-a', '--add a,b,c', Array, 'Subscribe list or FILE (csv: email,company)' ) do |a|
      $options[:add] = a
    end

    $options[:company] = ""
    opts.on( '-c', '--company STRING', 'Company' ) do |c|
      $options[:company] = c
    end

    $options[:configuration] = ""
    opts.on( '-F', '--configuration STRING', 'Configuration file' ) do |c|
      $options[:configuration] = c
    end

    $options[:debug] = false
    opts.on( '-d', '--debug', 'Output more information' ) do
      $options[:debug] = true
    end

    $options[:delete] = []
    opts.on( '-D', '--delete a,b,c', Array, 'Delete subscribers' ) do |a|
      $options[:delete] = a
    end

    $options[:delete_external] = false
    opts.on( nil,'--delete-external', 'Delete external subscribers' ) do 
      $options[:delete_external] = true
    end

    $options[:dryrun] = false
    opts.on( '-n', '--dry-run', 'Dry run' ) do
      $options[:dryrun] = true
    end

    $options[:edit_goodbye_msg] = false
    opts.on( nil, '--edit-goodbye-msg', 'Edit goodbye message' ) do
      $options[:edit_goodbye_msg] = true
    end

    $options[:edit_welcome_msg] = false
    opts.on( nil, '--edit-welcome-msg', 'Edit welcome message' ) do
      $options[:edit_welcome_msg] = true
    end

    $options[:get_goodbye_msg] = false
    opts.on( nil, '--get-goodbye-msg', 'Get goodbye message' ) do
      $options[:get_goodbye_msg] = true
    end

    $options[:get_welcome_msg] = false
    opts.on( nil, '--get-welcome-msg', 'Get welcome message' ) do
      $options[:get_welcome_msg] = true
    end

    $options[:show] = false
    opts.on( '-s', '--show', 'Show subscriber list' ) do |list|
      $options[:show] = true
    end

    $options[:message] = ""
    opts.on( '-m', '--message STRING', 'Message to be logged' ) do |m|
      $options[:message] = m
    end

    $options[:no_verify] = false
    opts.on( '-v', '--no-verify', 'Do not verify subscription') do
      $options[:no_verify] = true
    end

    $options[:verbose] = false
    opts.on( '-V', '--verbose', 'Verbose output for debugging') do
      $options[:verbose] = true
    end
    $options[:selected_list] = []
    opts.on( '-l', '--list a,b,c', Array, 'Select list by ALIAS' ) do |list|
      $options[:selected_list] = list
    end

    $options[:stats] = false
    opts.on( '-x', '--stats', 'Print statistics' ) do
      $options[:statistics] = true
    end

    $options[:xstats] = false
    opts.on( '-X', '--xstats', 'Print extended statistics' ) do
      $options[:xstats] = true
    end
  end
  optparse.parse!

  # Read configuration

  configfile  = 'mailmech.yaml'

  if !$options[:configuration].empty? then
    configfile = $options[:configuration]
    $log.info "Using configuration #{configfile}"
  end

  config = begin
             YAML.load( File.open(configfile))
           rescue ArgumentError => e
             puts "Could not parse #{configfile}: #{e.message}"
             exit
           end

  $lists = MailingLists.new

  config['lists'].each do |clist|
    newlist = Mailmech.new(
      config['listservers'][clist['server']]['url'],
      clist['name'],
      clist['pass']
    )
    newlist.listalias   = clist['alias'] 
    newlist.comment = clist['comment'] 
    newlist.internal_domains = config['internal_domains']

    if defined?(clist['archivetype']) && defined?(clist['archiveurl']) then
      newlist.archivetype = clist['archivetype']
      newlist.archiveurl = clist['archiveurl']
    end
    $lists << newlist
  end

  if !$options[:delete].empty?
    list_selected?
    
    # Create list of subscribers to delete
    del = []
    if $options[:delete].first=~ /@.+\..+/
      # Looks like email deleteress
      del = $options[:delete]
    else
      # No email address, try file
      csv = begin 
              CSV.read($options[:delete].first)
            rescue
              puts "Could not read from #{$options[:delete].first}"
              exit
            end
      csv.each { |l| del << l[0] }
    end
    $lists.delete($options[:selected_list], del)

    if !$options[:no_verify] then
      verify_deletion($options[:selected_list], del)
    end
  end # Delete

  if $options[:delete_external] then
    list_selected?

    $options[:selected_list].each do |ml|
      del = $lists.list(ml, :external)
      if del.count > 0 
        puts "Really delete #{del.count} subsriptions from #{ml} (yes/no)?"

        if gets.chomp == 'yes' then
          $lists.delete([ml],del)

          if !$options[:no_verify] then
            verify_deletion([ml], del)
          end
        end
      end
    end # list
  end # Delete external

  if $options[:edit_goodbye_msg] then
    list_selected?

    $options[:selected_list].each do |list|
      msg_org = $lists.get_goodbye_msg(list)
      tf = Tempfile.new('msg_edit')
      tf.write(msg_org)
      tf.rewind
      system("#{ENV['EDITOR']} #{tf.path}")
      tf.rewind
      msg_new = tf.read
      if msg_new != msg_org 
        $lists.set_goodbye_msg(list,msg_new)
        if !$options[:no_verify]
          logresult(list, "Changing text", "Goodbye Mesage", msg_new == $lists.get_goodbye_msg(list))
        end
      else
        puts "Message not changed!"
      end
      tf.close
      tf.unlink
    end 
  end 

  if $options[:edit_welcome_msg] then
    list_selected?

    $options[:selected_list].each do |list|
      msg_org = $lists.get_welcome_msg(list)
      tf = Tempfile.new('msg_edit')
      tf.write(msg_org)
      tf.rewind
      system("#{ENV['EDITOR']} #{tf.path}")
      tf.rewind
      msg_new = tf.read
      if msg_new != msg_org 
        $lists.set_welcome_msg(list,msg_new)
        if !$options[:no_verify]
          logresult(list, "Changing text", "Welcome message", msg_new == $lists.get_welcome_msg(list))
        end
      else
        puts "Message not changed!"
      end
      tf.close
      tf.unlink
    end 
  end 

  if $options[:statistics] then
    puts $lists.statistics($options[:selected_list])
    exit
  end

  if $options[:get_goodbye_msg] then
    list_selected?

    $options[:selected_list].each do |list|
      puts $lists.get_goodbye_msg(list)
    end 
  end 

  if $options[:get_welcome_msg] then
    list_selected?

    $options[:selected_list].each do |list|
      puts $lists.get_welcome_msg(list)
    end 
  end 

  if $options[:show] then
    puts $lists.to_s($options[:selected_list])
    exit
  end

  if $options[:xstats] then
    list_selected?
    $options[:selected_list].each { |list| $lists.xstats(list) }
    exit
  end

  if !$options[:add].empty? then
    list_selected?
    
    # Create list of new subscribers
    new = []
    if $options[:add].first=~ /@.+\..+/
      # Looks like email address
      new = $options[:add]
    else
      # No email address, try file
      csv = begin 
              CSV.read($options[:add].first)
            rescue
              puts "Could not read from #{$options[:add].first}"
              exit
            end
      csv.each { |l| new << l[0] }
    end

    # Subscribe
     
    $lists.subscribe($options[:selected_list],new)

    # Verify subscription
    
    $options[:selected_list].each do |list|

      puts "Dry run: Skipped subscribing #{new.count} new customers to #{list}." if $options[:dryrun] 
      
      if !$options[:no_verify] then
        new.each do |n|
          ok = $lists.member?(list,n.downcase)

          if ok then
            printf("%46s %s\n", "Mailinglist verified (#{list}):".green, "#{n}") 
            $log.info( logstring("Verified list subscription", list, n, "", $options[:message]) )
          else
            printf("%46s %s\n", "Mailinglist error (#{list}):".red,  "#{n}")
            $log.warn( logstring("List subscription failed", list, n, "", $options[:message]) )
          end

          # No need to log message a second time
          $options[:message] = ""
        end
      end
    end
  end #add

  if !$options[:message].empty? then
    $log.info( logstring("Message", $options[:selected_list].join(","), "", "", $options[:message]) )
  end


end