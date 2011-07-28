#!/usr/bin/ruby

require 'rubygems'
require 'mrIRC'

class Example2 < MRIRC::IRC
	#"welcome" (001) is the first message sent by the server to indicate that
	#you're registered
	def on_welcome(event)
		join("#test") #join the channel "#test"
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
end

#register handlers to break the main loop
trap("INT", proc { exit })
trap("TERM", proc { exit })

bot = Example2.new
begin
	bot.connect("127.0.0.1")
	bot.run #prevent the script from exiting until the connection is severed
ensure
	bot.disconnect #ensure that the script exits cleanly
end