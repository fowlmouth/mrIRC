#!/usr/bin/ruby

require 'rubygems'
require 'mrIRC'

class Example3 < MRIRC::IRC
	def on_init(event)
		@logs = Hash.new
	end
	
	def on_welcome(event)
		join("#test")
	end
	
	def on_message(event)
		log(event.channel, "<#{event.nick}> #{event.text}")
	end
	
	def on_action(event)
		log(event.channel, "* #{event.nick} #{event.text}")
	end
	
	#this method uses the standard Ruby IO functions to open the file in append
	#mode if it's not already open and write a string to the file
	def log(channel, text)
		if (@logs[channel] == @logs.default)
			@logs[channel] = File.open(channel+".log", "a")
		end
		@logs[channel].print("#{Time.now.strftime("[%j-%H:%M:%S]")} #{text}\n")
		@logs[channel].flush
	end
end

#register handlers to break the main loop
trap("INT", proc { exit })
trap("TERM", proc { exit })

bot = Example3.new
begin
	bot.connect("127.0.0.1")
	bot.run #prevent the script from exiting until the connection is severed
ensure
	bot.disconnect #ensure that the script exits cleanly
end