#!/usr/bin/ruby

#IMPORTANT: This script relies on the fxruby 1.6.x library, please ensure that
#the appropriate gem is installed before attempting to run this script

#we set the parameters for the script here to make them easily editable
$mynick = "myBot"
$server = "127.0.0.1"
$channel = "#test"
$port = "6667"
$realname = "Cheese Pizza"

require 'rubygems'
require 'fox16'
require 'mrIRC'

include Fox

#####BEGIN GUI PORTION#####
class Example4 < MRIRC::IRC
	def initialize()
		super() #remember to call this if you overrise initialize() so mrIRC can initialize itself
		
		#set parameters
		self.nick = $mynick
		self.realname = $realname
		
		#create an application and a main window for it
		@fxapp = FXApp.new
		@mainWindow = FXMainWindow.new(@fxapp, @nick+" - mrIRC Bot", :width => 400, :height => 500)
		
		#add a menu bar first, fill the width of the window with it, and ensure
		#that it's anchored to the top of the window
		@menuBar = FXMenuBar.new(@mainWindow, LAYOUT_TOP|LAYOUT_LEFT|LAYOUT_FILL_X)
			#Add an entry to the menu named "File"
			@menuTitle1 = FXMenuTitle.new(@menuBar, "&File")
				#Create a pane to contain the "File" menu items
				@menuFile = FXMenuPane.new(@menuTitle1)
					#create the individual menu items and add event handlers for
					#when they're activated
					@menuFileConnect = FXMenuCommand.new(@menuFile, "&Connect")
					@menuFileConnect.connect(SEL_COMMAND) {
						guiprint("Connecting to #{$server}:#{$port}...")
						connect($server, $port)
					}
					@menuFileDisconnect = FXMenuCommand.new(@menuFile, "&Disconnect")
					@menuFileDisconnect.connect(SEL_COMMAND) {
						quit("Disconnect requested")
						guiprint("Disconnected.")
					}
					@menuFileQuit = FXMenuCommand.new(@menuFile, "&Quit")
					@menuFileQuit.connect(SEL_COMMAND) {
						disconnect
						@fxapp.stop
					}
			#Attach the pane to the entry in the menu
			@menuTitle1.menu = @menuFile

		#Create a text area for output
		@outFrame = FXText.new(@mainWindow)
		@outFrame.layoutHints = LAYOUT_FILL_X|LAYOUT_FILL_Y #Fill any unused space
		@outFrame.editable = false #disallow typing in the text are, but allow selecting
		@outFrame.backColor = FXRGB(0, 0, 0) #background color black
		@outFrame.textColor = FXRGB(0, 255, 0) #foreground color green
		
		@fxapp.create #create the native widgets we've specified
		@mainWindow.show(PLACEMENT_SCREEN) #display the window in the center of the screen (this parameter seems to be undocumented)
		#indicate the GUI is running for later and run the main loop
		@fxrunning = true
		@fxapp.run
		@fxrunning = false
	end
	
	def guiprint(text)
		#check if the gui is active so messages that come in between gui
		#shutdown and script shutdown don't cause an exception
		if (@fxrunning)
			#add a newline if this isn't the first line, this is prepended to
			#prevent a blank space at the end of output when it scrolls
			@outFrame.text += "\n" if (@outFrame.text != "")
			#append the text
			@outFrame.text += text
		end
	end
end

#####BEGIN IRC PORTION#####
class Example4
	def on_welcome(event)
		#join the channel
		guiprint("Joining #{$channel}...")
		join($channel)
	end
	
	def on_sendmessage(event)
		#show our activity on the console
		guiprint(">>> #{event.text}")
	end
	
	def on_sendaction(event)
		#show our activity on the console
		guiprint("*** #{event.text}")
	end

	def on_message(event)
		#print received messages to the gui
		guiprint("<#{event.nick}> #{event.text}")
	end
	
	def on_action(event)
		#print received actions to the gui
		guiprint("* #{event.nick} #{event.text}")
	end
end

begin
	bot = Example4.new #start the gui
ensure
	bot.disconnect if bot.connected? #ensure the bot exits cleanly
end