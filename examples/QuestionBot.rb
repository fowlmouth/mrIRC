#!/usr/bin/ruby

begin
  require 'rubygems'
rescue LoadError
end

require 'mrIRC'
require 'george'

Database = George.new('~/Working/ircbot/QuestionBotDatabase.george',
  read_only: false, comment_chars: '::')

IRC_CODES = {
  '&bl;' => "\x02",
  '&rs;' => "\x0F",
  '&ul;' => "\x1F",
  '&rv;' => "\x16",
}

#cycle through db[:knowledge] and replace &bl; with the bold code thinger.
#when the bot sends the message to the server it seems to strip out the color
#codes and such, need to look into that
Database[:knowledge] = Hash[Database[:knowledge].map { |k, v|
  [k, v.gsub(/(#{IRC_CODES.keys.join('|')})*/) { |s| IRC_CODES[s] }]
}]

class QuestionBot < MRIRC::IRC

  #"welcome" (001) is the first message sent by the server to indicate that
  #you're registered
  def on_welcome(event)
    join Database[:settings][:chan] #join the channel "#test"
  end
  
  #the "join" event is triggered when the server sends a JOIN command, meaning
  #this event is also triggered when we join a channel, so we check who joined
  #and react appropriately
  def on_join(event)
  
  end
  
  def on_message event
    if event.nick == event.channel
      #this is a private message, if you want to handle it differently
    end
    
    if event.text[0, @nick.size+1] == "#{@nick}:"
      command = event.text[@nick.size+1 .. -1].strip
    else
      #message isnt a command, log it here or something
      return
    end
    
    if jews = command.match(/(.+?)\s+is\s+(.+)\s*/)
      jews = jews.to_a
      puts "Setting #{jews[1]} to #{jews[2]}"
      Database[:knowledge][jews[1]] = jews[2]
      message event.channel, 'Ok'
    elsif command =~ /(.+)\?/
      if Database[:knowledge].has_key? $1
        message event.channel, "#{$1} is #{Database[:knowledge][$1]}"
      else
        message event.channel, "Have no information about #{$1}, add with `#{@nick}: #{$1} is ...'"
      end
    elsif command =~ /^help/
      message event.channel, "Add information with `#{@nick}: <TOPIC> is <WORDS>', `#{@nick}: launcher?'"
    end
  end
end

#register handlers to break the main loop
trap 'INT' do exit end
trap 'TERM' do exit end

bot = QuestionBot.new

bot.nick = Database[:settings][:nick]
bot.realname = 'mrIRC github/fowlmouth/mrIRC'

begin
  bot.connect Database[:settings][:server]
  bot.run #prevent the script from exiting until the connection is severed
ensure
  bot.disconnect #ensure that the script exits cleanly
  
  begin
    #save the db
    
    #flip the hash so values are keys and keys are values
    #world.explode
    flipped_codes = Hash[IRC_CODES.map { |k, v| [v, k] }]
    Database[:knowledge] = Hash[Database[:knowledge].map { |k, v|
      [k, v.gsub(/(#{flipped_codes.keys.join('|')})*/) { |s| flipped_codes[s] }]
    }]
    
    puts "Writing stuff"
    Database.write
  rescue
    #oh god
    puts "FAILED WRITING"
    puts "#{$!.message} \n  #{$!.backtrace.join("\n  ")}"
  end
end