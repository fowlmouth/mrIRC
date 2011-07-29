require 'socket'

module MRIRC
  MRIRC_VERSION = "mrIRC - Minimalist Ruby IRC v0.2.4 https://github.com/fowlmouth/mrIRC"

  class IRCEventData
    attr_accessor :command, :numeric, :source, :source_nick, :source_host, :nick, :target, :target_nick, :target_host, :channel, :other, :text

    def initialize(command, numeric, source, target, message)
      @command = command
      @numeric = numeric
      @source = source
      @source_nick = source[/[^!]+/]
      @source_host = source[/[^!]+@.*/]
      @nick = @source_nick
      @target = target
      @target_nick = target[/[^!]+/]
      @target_host = target[/[^!]+@.*/]
      @channel = @target
      @other = @target_nick
      @text = message.chomp("\n").chomp("\r")
    end
  end
  
  class IRCConfigData
    attr_accessor :suppress_pong, :ctcp_respond
    
    def initialize
      @suppress_pong = false
      @ctcp_respond = true
      @version = MRIRC::MRIRC_VERSION
    end
  end

  class IRC
    ALIASES = {
      "001" => "welcome",
      "002" => "yourhost",
      "003" => "created",
      "004" => "myinfo",
      "231" => "serviceinfo",
      "232" => "endofservices",
      "233" => "service",
      "234" => "servlist",
      "235" => "servlistend",
      "259" => "adminemail",
      "305" => "unaway",
      "306" => "nowaway",
      "311" => "whoisuser",
      "312" => "whoisserver",
      "313" => "whoisoperator",
      "314" => "whowasuser",
      "315" => "endofwho",
      "316" => "whoischanop",
      "317" => "whoisidle",
      "318" => "endofwhois",
      "321" => "liststart",
      "322" => "list",
      "323" => "listend",
      "324" => "channelmodeis",
      "331" => "notopic",
      "332" => "topic",
      "351" => "version",
      "352" => "whoreply",
      "353" => "namreply",
      "361" => "killdone",
      "362" => "closing",
      "363" => "closeend",
      "364" => "links",
      "365" => "endoflinks",
      "366" => "endofnames",
      "367" => "banlist",
      "368" => "endofbanlist",
      "369" => "endofwhowas",
      "371" => "info",
      "372" => "motd",
      "373" => "infostart",
      "374" => "endofinfo",
      "375" => "motdstart",
      "376" => "endofmotd",
      "391" => "time",
      "392" => "usersstart",
      "393" => "users",
      "394" => "endofusers",
      "395" => "nousers",
      "401" => "nosuchnick",
      "402" => "nosuchserver",
      "403" => "nosuchchannel",
      "404" => "cannotsendtochan",
      "405" => "toomanychannels",
      "406" => "wasnosuchnick",
      "407" => "toomanytargets",
      "422" => "nomotd",
      "433" => "nickinuse",
      "442" => "notonchannel",
      "451" => "notregistered",
      "462" => "alreadyregistered",
      "464" => "badpass",
      "471" => "chanfull",
      "472" => "unknownmode",
      "473" => "inviteonlychan",
      "474" => "bannedfromchan",
      "475" => "badchannelkey",
      "476" => "badchanmask"
    }
  
    attr_reader :nick, :irc_config, :realname, :hostname, :channels
    attr_accessor :password, :method_prefix
    
    def initialize options = {}
      @irc_config = IRCConfigData.new
      @method_prefix = options[:prefix] || 'on_'
      @nick = options[:nick] || 'mrBot'
      @realname = options[:realname] || 'mrIRC User'
      @hostname = options[:hostname] || 'www.newmoongames.org'
      @verbose = options[:verbose] || false
      @_thread = nil
      @_socket = nil
      @_socketmutex = Mutex.new
      @password = ""
      @channels = Array.new
      
      data = IRCEventData.new("", 0, @nick, "", "")
      run_callback("init", data)
    end
    
    def connect(server, port = 6667, password = "")
      @_server = server
      @_port = port
      @password = password
      @_socket = TCPSocket.new(server, port)
      
      send_raw("NICK #{@nick}")
      send_raw("USER #{@nick} \"#{@hostname}\" \"#{@_server}\" : #{@realname}")
      send_raw("PASS #{password}") if (password != "")
      
      @_thread = Thread.new {
        @_socket.each_line { |line|
          run_callback("recv", IRCEventData.new("", 0, "", "", line.chop))
          case (line)
            when /(:[^\s]+ )?PING :([^\s]+)/
              send_raw("PONG :#{$2}") unless (@irc_config.suppress_pong)
              data = IRCEventData.new("PING", 0, $1.to_s, @nick, $2.to_s)
              run_callback("ping", data)
            when /(:[^\s]+ )?NOTICE ([^\s]+) :(.*)/
              data = IRCEventData.new("NOTICE", 0, $1.to_s, @nick, $2.to_s)
              run_callback("notice", data)
            when /:([^\s]+) PART ([^\s]+)(?: :(.*))?/
              data = IRCEventData.new("PART", 0, $1.to_s, $2.to_s, $3.to_s)
              @channels.delete(data.target) if (data.source_nick == @nick)
              run_callback("part", data)
            when /:([^\s]+) JOIN :([^\s]+)/
              data = IRCEventData.new("JOIN", 0, $1.to_s, $2.to_s, "")
              @channels.push(data.target) if (data.source_nick == @nick)
              run_callback("join", data)
            when /:([^\s]+) NICK :([^\s]+)/
              data = IRCEventData.new("NICK", 0, $1.to_s, $2.to_s, "")
              @nick = data.target_nick if (data.source_nick == @nick)
              run_callback("nick", data)
            when /:([^\s]+) PRIVMSG ([^\s]+) :(.*)/
              data = IRCEventData.new("PRIVMSG", 0, $1.to_s, $2.to_s, $3.to_s)
              data.channel = data.source_nick if (data.target_nick == @nick)
              run_callback("privmsg", data)
              if (data.text =~ /\001(\w+)(?: (.*))?\001/)
                run_callback("ctcp", data)
                case ($1.to_s)
                  when "ACTION"
                    data.text = $2.to_s
                    run_callback("action", data)
                  when "PING"
                    notice(data.nick, "\001PING #{$2.to_s}\001") if (@irc_config.ctcp_respond)
                  when "VERSION"
                    notice(data.nick, "\001VERSION #{@irc_config.version}\001") if (@irc_config.ctcp_respond)
                  when "TIME"
                    notice(data.nick, "\001TIME #{Time.now.asctime}\001") if (@irc_config.ctcp_respond)
                  when "USERINFO"
                    #not implemented
                end
              else
                run_callback("message", data)
              end
            when /:([^\s]+) (\d\d\d) (.*) :(.*)/
              data = IRCEventData.new($2.to_s, $2.to_i, $1.to_s, $3.to_s, $4.to_s)
              run_callback($2.to_s, data)
              run_callback(IRC::ALIASES[$2.to_s], data) if (IRC::ALIASES[$2.to_s] != IRC::ALIASES.default)
          end
          sleep(0.01)
        }
      }
    end
    
    def connected?
      return false unless (@_socket)
      return !@_socket.closed?
    end
    
    def join(channel, key = "")
      send_raw("JOIN #{channel} #{key}")
    end
    
    def part(channel, reason = "")
      send_raw("PART #{channel}#{(reason == "" ? "" : " :#{reason}")}")
    end
    
    def kick(channel, user, reason = "")
      send_raw("KICK #{channel} #{user}#{(reason == "" ? "" : " :#{reason}")}")
    end
    
    def change_nick(newnick)
      if (connected?)
        send_raw(":#{@nick} NICK #{newnick}")
      else
        @nick = newnick
      end
    end
    
    def nick=(newnick)
      change_nick(newnick)
    end
    
    def user_info(hostname, realname)
      if (connected?)
        send_raw(":#{@nick} USER #{@nick} #{hostname} #{@_server} : #{realname}")
      else
        @hostname = hostname
        @realname = realname
      end
    end
    
    def hostname=(newhost)
      user_info(newhost, @realname)
    end
    
    def realname=(newname)
      user_info(@hostname, newname)
    end
    
    def mode(target, mode, user = "")
      send_raw("MODE #{target} #{mode}#{(user == "" ? "" : " "+user)}")
    end
    
    def message(target, text)
      send_raw("PRIVMSG #{target} :#{text}")
      data = IRCEventData.new("PRIVMSG", 0, @nick, target, text)
      run_callback("sendmessage", data)
    end
    
    def notice(target, text)
      send_raw("NOTICE #{target} :#{text}")
      data = IRCEventData.new("NOTICE", 0, @nick, target, text)
      run_callback("sendnotice", data)
    end
    
    def describe(target, text)
      send_raw("PRIVMSG #{target} :\001ACTION #{text}\001")
      data = IRCEventData.new("PRIVMSG", 0, @nick, target, text)
      run_callback("sendaction", data)
      
    end
    
    def message_all(text)
      message(@channels.join(","), text)
    end
    
    def notice_all(text)
      notice(@channels.join(","), text)
    end
    
    def describe_all(text)
      describe(@channels.join(","), text)
    end
    
    def quit(message = "")
      send_raw("QUIT#{(message == "" ? "" : " :"+message)}")
    end
    
    def disconnect
      if (@_socket)
        quit("Client exited")
        @_socket.close
      end
    end
    
    def run
      return unless (@_thread != nil)
      while (@_thread.status)
      end
    end
    
    def send_raw(out_str)
      return unless (connected?)
      run_callback("send", IRCEventData.new("", 0, "", "", out_str))
      @_socketmutex.synchronize {
        @_socket.print "#{out_str}\r\n"
      }
    end
    
    private
    def run_callback(name, data)
      puts "#{name} --- #{data.text}" if @verbose
      self.send("#{@method_prefix}#{name}".intern, data) if self.respond_to?("#{@method_prefix}#{name}".intern)
    end
  end
end