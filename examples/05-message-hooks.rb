#!/usr/bin/ruby

begin
  require 'rubygems'
rescue LoadError
end

require 'mrIRC'
require 'twitter'

COMMAND_PREFIX = '!'

class Example5 < MRIRC::IRC

  def initialize
    super
    @halps, @captain_hooks, @maaaaaaaaaaaaaaatches = \
     [],     {},             []
  end
  
  #"welcome" (001) is the first message sent by the server to indicate that
  #you're registered
  def on_welcome(event)
    join("#fowl") #join the channel "#test"
  end
  
  #the "join" event is triggered when the server sends a JOIN command, meaning
  #this event is also triggered when we join a channel, so we check who joined
  #and react appropriately
  def on_join(event)
    if (event.nick == self.nick)
      message(event.channel, "Hi guys!")
    else
      message(event.channel, "Hi #{event.nick}!")
    end
  end
  
  def on_message event
    if event.nick == event.channel
      #this is a private message, if you want to handle it differently
    end
    
    @maaaaaaaaaaaaaaatches.each { |m| m[1].call(event) if event.text =~ m[0] }
    
    
    if event.text[0,1] == COMMAND_PREFIX
      command = event.text[1..-1].split(' ')
    elsif event.text[0, @nick.size+2] == "#{@nick}: "
      command = event.text[@nick.size+2 .. -1].split(' ')
    else
      #message isnt a command, log it here or something
      return
    end
    
    if @captain_hooks.has_key? command[0]
      @captain_hooks[command[0]].call command, event
    elsif command[0] == 'help'
      message event.channel, @halps.join('; ') if @halps.size > 0
    end
  end
  
  def message_match regex, &block
    @maaaaaaaaaaaaaaatches << [regex, block]
  end
  
  def message_hook commands, halp = nil, &block
    [*commands].each { |c| @captain_hooks[c] = block }
    if halp
      @halps << "#{[*commands][0]} #{halp}"
    end
  end
end

#register handlers to break the main loop
trap("INT", proc { exit })
trap("TERM", proc { exit })

bot = Example5.new

bot.message_hook 'twitter-search', '<Search String(required)> - searches Twitter' do |command, event|
  return false if command.size < 2
  
  result = Twitter::Search.new.containing(command[1..-1].join(' ')).result_type(:recent).per_page(3).map do |r|
    "#{r.from_user}: #{r.text}"
  end
  
  bot.message event.channel, result.join('; ')
end

bot.message_match /banisterfiend/ do |event|
  if event.nick =~ /banisterfiend/
    bot.message event.nick, '<3'
  else
    bot.message event.channel, 'yes, we all know that banister sucks'
  end
end

begin
  bot.connect("irc.freenode.org")
  bot.run #prevent the script from exiting until the connection is severed
ensure
  bot.disconnect #ensure that the script exits cleanly
end