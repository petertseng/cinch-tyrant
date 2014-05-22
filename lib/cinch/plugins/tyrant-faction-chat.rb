require 'cinch'
require 'cinch/plugins/tyrant-poll'
require 'cinch/tyrant/cmd'
require 'tyrant/faction'

module Cinch; module Plugins; class TyrantFactionChat < TyrantPoll
  include Cinch::Plugin

  timer 60, method: :check_all

  match(/chat(.*)/i)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('chat', 'chat', '<on|off>',
      lambda { |m| is_officer?(m) },
      'Turns faction chat monitor on/off. ' +
      'Faction chat is relayed into the channel every minute if enabled.'
    ),
  ]

  class MonitoredFaction < TyrantPoll::MonitoredFaction
    attr_reader :last

    def initialize(*args)
      super
      messages = @tyrant.get_faction_chat
      @last = messages[-1] ? messages[-1]['post_id'] : nil
    end

    def poll_name; @last ? 'getNewFactionMessages' : 'getFactionMessages'; end
    def poll_params; @last ? "last_post=#{@last}" : ''; end

    def poll_result(json)
      new_messages = json['messages']
      @last = new_messages[-1]['post_id'] unless new_messages.empty?
      new_messages
    end
  end

  def monitored_faction
    MonitoredFaction
  end

  def initialize(*args)
    super
    shared[:last_faction_chat] = Hash.new

    @factions.each { |_, f|
      shared[:last_faction_chat][f.faction_id] = f.last
    }
  end

  def notification_type
    :faction_chat
  end

  def notify(faction, channels, new_messages)
    return if new_messages.nil?
    registration_regex = /^#{bot.nick}\s+confirm\s+(\w+)\s+(\w+)$/i

    new_messages.each { |m|
      user = ::Tyrant.get_name_of_id(m['user_id'])

      msg = "[FACTION] #{user}: #{m['message'] ? m['message'].sanitize : 'nil'}"
      channels.each { |c| Channel(c).send(msg) }

      if (match = registration_regex.match(m['message']))
        # TODO: Have this update the cache?
        members = faction.tyrant.get_faction_members
        member = members[m['user_id'].to_s]
        # Not found? Cache probably stale. Assume member.
        perm = member ? member['permission_level'].to_i : 1
        level = Cinch::Tyrant::Auth::DEFAULT_PERMISSIONS[perm]
        nick = match[1]
        code = match[2]
        success = Cinch::Tyrant::Auth::confirm_register(
          faction.faction_id, m['user_id'].to_i, nick, level, code
        )
        if success
          channels.each { |c|
            Channel(c).send(nick + ': Thank you for registering.')
          }
        end
      end
    }
    shared[:last_faction_chat][faction.faction_id] = faction.last
  end
end; end; end
