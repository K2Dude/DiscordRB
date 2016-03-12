require 'discordrb/api'

module Discordrb
  module Cache
    # Initializes this cache
    def init_cache
      @users = {}

      @servers = {}

      @channels = {}
      @private_channels = {}

      @restricted_channels = []
    end

    # Gets a channel given its ID. This queries the internal channel cache, and if the channel doesn't
    # exist in there, it will get the data from Discord.
    # @param id [Integer] The channel ID for which to search for.
    # @return [Channel] The channel identified by the ID.
    def channel(id)
      id = id.resolve_id

      raise Discordrb::Errors::NoPermission if @restricted_channels.include? id

      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      begin
        response = API.channel(token, id)
        channel = Channel.new(JSON.parse(response), self)
        @channels[id] = channel
      rescue Discordrb::Errors::NoPermission
        debug "Tried to get access to restricted channel #{id}, blacklisting it"
        @restricted_channels << id
        raise
      end
    end

    # Creates a private channel for the given user ID, or if one exists already, returns that one.
    # It is recommended that you use {User#pm} instead, as this is mainly for internal use. However,
    # usage of this method may be unavoidable if only the user ID is known.
    # @param id [Integer] The user ID to generate a private channel for.
    # @return [Channel] A private channel for that user.
    def private_channel(id)
      id = id.resolve_id
      debug("Creating private channel with user id #{id}")
      return @private_channels[id] if @private_channels[id]

      response = API.create_private(token, @bot_user.id, id)
      channel = Channel.new(JSON.parse(response), self)
      @private_channels[id] = channel
    end

    # Gets the code for an invite.
    # @param invite [String, Invite] The invite to get the code for. Possible formats are:
    #
    #    * An {Invite} object
    #    * The code for an invite
    #    * A fully qualified invite URL (e. g. `https://discordapp.com/invite/0A37aN7fasF7n83q`)
    #    * A short invite URL with protocol (e. g. `https://discord.gg/0A37aN7fasF7n83q`)
    #    * A short invite URL without protocol (e. g. `discord.gg/0A37aN7fasF7n83q`)
    # @return [String] Only the code for the invite.
    def resolve_invite_code(invite)
      invite = invite.code if invite.is_a? Discordrb::Invite
      invite = invite[invite.rindex('/') + 1..-1] if invite.start_with?('http', 'discord.gg')
      invite
    end

    # Gets information about an invite.
    # @param invite [String, Invite] The invite to join. For possible formats see {#resolve_invite_code}.
    # @return [Invite] The invite with information about the given invite URL.
    def invite(invite)
      code = resolve_invite_code(invite)
      Invite.new(JSON.parse(API.resolve_invite(token, code)), self)
    end

    # Gets a user by its ID.
    # @note This can only resolve users known by the bot (i.e. that share a server with the bot).
    # @param id [Integer] The user ID that should be resolved.
    # @return [User, nil] The user identified by the ID, or `nil` if it couldn't be found.
    def user(id)
      id = id.resolve_id
      @users[id]
    end

    # Gets a server by its ID.
    # @note This can only resolve servers the bot is currently in.
    # @param id [Integer] The server ID that should be resolved.
    # @return [Server, nil] The server identified by the ID, or `nil` if it couldn't be found.
    def server(id)
      id = id.resolve_id
      @servers[id]
    end

    # Finds a channel given its name and optionally the name of the server it is in.
    # @param channel_name [String] The channel to search for.
    # @param server_name [String] The server to search for, or `nil` if only the channel should be searched for.
    # @return [Array<Channel>] The array of channels that were found. May be empty if none were found.
    def find_channel(channel_name, server_name = nil)
      results = []

      @servers.values.each do |server|
        server.channels.each do |channel|
          results << channel if channel.name == channel_name && (server_name || server.name) == server.name
        end
      end

      results
    end

    # Finds a user given its username.
    # @param username [String] The username to look for.
    # @return [Array<User>] The array of users that were found. May be empty if none were found.
    def find_user(username)
      @users.values.find_all { |e| e.username == username }
    end
  end
end