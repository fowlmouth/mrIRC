#!/usr/bin/ruby

require 'rubygems'
require 'mrIRC'

class Example1 < MRIRC::IRC
	#"welcome" (001) is the first message sent by the server to indicate that
	#you're registered
	def on_welcome(event)
		join("#test") #join the channel "#test"
	end
end

bot = Example1.new #instantiate our class
bot.connect("127.0.0.1") #connect to a server at localhost on port 6667
bot.run #prevent the script from exiting until the connection is severed