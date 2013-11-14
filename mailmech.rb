#!/usr/bin/env ruby

require 'colorize'
require 'mechanize'
require 'logger'

class Mailmech
  attr_accessor :server
  attr_accessor :listname
  attr_accessor :listalias
  attr_accessor :password
  attr_accessor :comment
  attr_accessor :archivetype
  attr_accessor :archiveurl
  attr_accessor :internal_domains

  def initialize (servername, name, pass)
    @server   = servername
    @listname = name
    @password = pass

    @connected = false

    @agent = Mechanize.new

    # No SSL certificate validation for now
    #OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    # Uncommment below to enable logging while extending mailmech
    #
    #@agent.log = Logger.new $stderr
    #@agent.agent.http.debug_output = $stderr    
    
    # Define global options, if not already available
    $options = {} if ! defined? $options
  end

  def ensure_connection
    if !@connected then
      @connected = true
      @basepage = "#{@server}/admin/#{@listname}"
      url = @basepage
      puts "* mailmech: ensure_connection to #{url} ...".green if $options[:verbose]
      page = @agent.get url

      login_form = page.form
      login_form.adminpw = @password

      page = @agent.submit(login_form, login_form.buttons.first)
    end
  end

  def reload_subscribers
    @subscriber_list = []
    url = "#{@server}/roster/#{@listname}"
    puts "* mailmech: reload subscribers from #{url} ...".green if $options[:verbose]
    begin
      page = @agent.get url
    rescue Mechanize::ResponseCodeError => e
      puts "* mailmech: Error #{e}".red
      return []
    end

    page.links_with(:href => /--at--/).each do |l|
      @subscriber_list << l.href
    end
    @subscriber_list.map! { |x| x.gsub!(/--at--/,"@").gsub!(/^(.*\/)/,'') }

    @subscriber_list.sort! if @subscriber_list.count > 0
    @subscriber_list
  end

  def subscribers 
    ensure_connection
    reload_subscribers
    @subscriber_list
  end
    
  def delete (del)
    ensure_connection

    url = "#{@basepage}/members/remove"

    puts "* mailmech: unsubscribe #{url} ...".green if $options[:verbose]

    page = @agent.get url

    submit_form = page.form
    submit_form.unsubscribees = del.join "\n"
    if !$options[:dryrun]
      page = @agent.submit(submit_form)
    end
  end

  def get_goodbye_msg
    ensure_connection

    page = @agent.get "#{@basepage}/?VARHELP=general/goodbye_msg"
    page.form.goodbye_msg
  end

  def get_welcome_msg
    ensure_connection

    page = @agent.get "#{@basepage}/general"
    page.form.welcome_msg
  end

  def set_goodbye_msg(msg)
    ensure_connection

    page = @agent.get "#{@basepage}/?VARHELP=general/goodbye_msg"
    page.form.goodbye_msg = msg
    if !$options[:dryrun]
      page = @agent.submit(page.form)
    end
  end

  def set_welcome_msg(msg)
    ensure_connection

    page = @agent.get "#{@basepage}/?VARHELP=general/welcome_msg"
    page.form.welcome_msg = msg
    if !$options[:dryrun]
      page = @agent.submit(page.form)
    end
  end

  def subscribe (subscribees)
    ensure_connection

    url = "#{@basepage}/members/add"
    puts "* mailmech: subscribe #{url} ...".green if $options[:verbose]

    page = @agent.get url
    submit_form = page.form
    submit_form.subscribees = subscribees.join("\n")
    if !$options[:dryrun]
      page = @agent.submit(submit_form)
    end
  end

  def intern? (s)
    @internal_domains.each do |d|
      return true if s =~ /#{d}/
    end
    return false
  end

  def split(list)
    # Return array [internal subscribers, external subscribers]
    return list.reject { |x| !intern?(x) },  list.reject { |x| intern?(x) } 
  end

  def domains(list)
    ret = list.map { |x| x.split('@').last }
    ret.sort.uniq
  end
end

class MailingLists
  def initialize
    @lists = []
  end

  def <<(other)
    @lists << other
  end

  def names
    ret = []
    @lists.each { |l| ret << l.listname }
    ret 
  end

  def find_by_alias(a)
    @lists.each do |l|
      return l if l.listalias == a 
    end
    return nil
  end
    
  def delete(aliases, emails)
    sublists = []
    aliases.each do |a|
      l = find_by_alias(a)
      if !l.nil? then
        sublists << l
      end
    end
    sublists.each do |l| 
      l.delete(emails) 
      if !$options[:dryrun] && !$options[:no_verify] then
        l.reload_subscribers if !$options[:dryrun] 
      end
    end
  end

  def get_goodbye_msg(a)
    l = find_by_alias(a)
    l.get_goodbye_msg if !l.nil? 
  end

  def get_welcome_msg(a)
    l = find_by_alias(a)
    l.get_welcome_msg if !l.nil? 
  end

  def set_goodbye_msg(a,msg)
    l = find_by_alias(a)
    l.set_goodbye_msg(msg) if !l.nil? 
  end

  def set_welcome_msg(a,msg)
    l = find_by_alias(a)
    l.set_welcome_msg(msg) if !l.nil? 
  end

  def subscribe(aliases, emails)
    sublists = []
    aliases.each do |a|
      l = find_by_alias(a)
      if !l.nil? then
        sublists << l
      end
    end
    sublists.each do |l| 
      l.subscribe(emails) 
      if !$options[:dryrun] && !$options[:no_verify] then
        l.reload_subscribers if !$options[:dryrun] 
      end
    end
  end

  def member?(listalias, email)
    l = find_by_alias(listalias)
    if !l.nil? then
      return l.subscribers.member?(email)
    end
    false
  end

  def statistics(aliases)
    sublists = []
    if aliases.empty? then
      sublists = @lists
    else
      aliases.each do |a|
        l = find_by_alias(a)
        if !l.nil? then
          sublists << l
        end
      end
    end

    return s if sublists.empty?

    s = "Statistics:\n"
    w = 12
    s += sprintf("%20s |%#{w}s|%#{w}s|%#{w}s|%#{w}s|%#{w}s|%20s\n","List","Alias","Total","int.","ext.","Domains ext.","Comment")
    s += '-'*21 + ('+' + '-'*w)*5 + ('+' + '-'*20) + "\n"

    sublists.each do |l|
      slist = l.subscribers
      slist_int, slist_ext = l.split(slist)
      s += sprintf("%20s |%#{w}s|%#{w}i|%#{w}i|%#{w}i|%#{w}i|%20s\n",
             l.listname, 
             l.listalias,
             slist.count,
             slist_int.count, 
             slist_ext.count, 
             l.domains(slist_ext).count,
             l.comment)
    end
    s
  end

  require 'find'
  require 'mail'
  def xstats(listalias)
    l = find_by_alias(listalias)
    if l.archivetype != 'mdir' then
      puts "Sorry, \"#{l.listname}\" has no mdir archive."
      return
    end

    paths = []
    Find.find(l.archiveurl) do |p|
      paths << p if File.file?(p)
    end
    puts "Processing #{paths.count} mails...\n"

    froms_int = {}
    mails_int = 0
    froms_ext = {}
    mails_ext = 0
    paths.each do |p|
      f = Mail.read(p).from.first
      if l.intern?(f) then
        mails_int += 1
        if froms_int.has_key?(f) then
          froms_int[f] += 1
        else
          froms_int[f] =1
        end
      else
        mails_ext += 1
        if froms_ext.has_key?(f) then
          froms_ext[f] += 1
        else
          froms_ext[f] =1
        end
      end
    end

    puts "Extended stats for \"#{l.listname}\":"
    puts "  * Mails by internal senders (#{mails_int}):"
    froms_int.sort_by {|k,v| v}.reverse.each do |f|
      printf "     %3d %-40s\n", f[1], f[0]
    end
    puts
    puts "  * Mails by external senders (#{mails_ext}):"
    froms_ext.sort_by {|k,v| v}.reverse.each do |f|
      printf "     %3d %-40s\n", f[1], f[0]
    end
  end

  def to_s(aliases = [])  
    sublists = []
    if aliases.empty? then
      sublists = @lists
    else
      aliases.each do |a|
        l = find_by_alias(a)
        if !l.nil? then
          sublists << l
        end
      end
    end

    s = ''
    sublists.each do |l|
      slist = l.subscribers
      slist_int, slist_ext = l.split(slist)
      if l.internal_domains.count > 0
        slist_int.each {|x| s +=  "subint, #{l.listname}, #{x}\n"}
        slist_ext.each {|x| s +=  "subext, #{l.listname}, #{x}\n"}
        a = l.domains(slist_int)
        a.each {|x| s +=  "domint, #{l.listname}, #{x}\n"}
        a = l.domains(slist_ext)
        a.each {|x| s +=  "domext, #{l.listname}, #{x}\n"}
      else
        s += "All subscribers #{l.listname}, #{l.comment}\n"
        slist.each {|x| s +=  "suball, #{l.listname}, #{x}\n"}
      end
      s += "\n"
    end
    s
  end
end
