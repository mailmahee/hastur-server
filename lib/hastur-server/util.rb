# A collection of useful functions, including thise for
# working with ZeroMQ, specifically with the ffi-rzmq gem.
require "multi_json"
require "ffi-rzmq"
module Hastur
  module Util
    extend self  # Allows calling as Util.blah

    SECS_2100       = 4102444800
    MILLI_SECS_2100 = 4102444800000
    MICRO_SECS_2100 = 4102444800000000
    NANO_SECS_2100  = 4102444800000000000
    SECS_1971       = 31536000
    MILLI_SECS_1971 = 31536000000
    MICRO_SECS_1971 = 31536000000000
    NANO_SECS_1971  = 31536000000000000

    #
    # Best effort to make all timestamps be Hastur timestamps, 64 bit
    # numbers that represent the total number of microseconds since Jan
    # 1, 1970 at midnight UTC.  Default to giving Time.now as a Hastur
    # timestamp.
    #
    def self.timestamp(ts=Time.now)
      case ts
        when nil, ""
          (Time.now.to_f * 1_000_000).to_i
        when Time;
          (ts.to_f * 1_000_000).to_i
        when SECS_1971..SECS_2100
          ts * 1_000_000
        when MILLI_SECS_1971..MILLI_SECS_2100
          ts * 1_000
        when MICRO_SECS_1971..MICRO_SECS_2100
          ts
        when NANO_SECS_1971..NANO_SECS_2100
          ts / 1_000
        else
          raise "Unable to convert timestamp: #{ts} (class: #{ts.class})"
      end
    end

    # application boot time in epoch microseconds, intentionally not system boot time
    BOOT_TIME = timestamp

    #
    # return the current uptime in microseconds
    #
    def self.uptime(time=Time.now)
      now = timestamp(time)
      time - BOOT_TIME
    end

    #
    # keep a single, global counter for the :sequence field
    #
    @counter = 0
    def self.next_seq
      @counter+=1
    end

    UUID_RE = /\A[a-f0-9]{8}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{12}\Z/i

    def self.valid_uuid?(uuid)
      if UUID_RE.match(uuid)
        true
      else
        false
      end
    end

    # not really thorough yet
    def self.valid_zmq_uri?(uri)
      case uri
        when %r{ipc://.};         true
        when %r{tcp://[^:]+:\d+}; true
        else;                     false
      end
    end

    #
    # Find a useful socket identity, falling back to the memory address of the socket
    # if it no identity was assigned with setsockopt(ZMQ::IDENTITY, ""). Since identity
    # can't be changed after connect/bind, it's unlikely this will ever change during runtime.
    # @param [ZMQ::Socket] socket to identify
    # @return [String] id
    #
    def self.sockid(socket)
      if socket.kind_of? ZMQ::Socket
        rc = socket.getsockopt(ZMQ::IDENTITY, id=[])
        if ZMQ::Util.resultcode_ok?(rc) and id[0]
          id[0]
        else
          socket.socket.address
        end
      elsif socket.kind_of? FFI::Pointer
        socket.address
      else
        raise ArgumentError.new "Cannot generate a useful identity for the socket."
      end
    end

    def self.setsockopts(sock, opts = {})
      rc = sock.setsockopt(::ZMQ::LINGER, opts[:linger] || -1)
      raise "Error setting ZMQ::LINGER: #{::ZMQ::Util.error_string}" unless rc > -1
      rc = sock.setsockopt(::ZMQ::HWM, opts[:hwm] || 1)
      raise "Error setting ZMQ::HWM: #{::ZMQ::Util.error_string}" unless rc > -1
    end

    def self.bind(sock, uri)
      rc = sock.bind(uri)
      raise "Could not bind socket to URI '#{uri}': #{::ZMQ::Util.error_string}" unless rc > -1
    end

    #
    # Check a URI for validity before passing onto ZMQ.
    # We explicitly disallow "localhost" because ZMQ will break silently on IPv6 enabled systems.
    #
    def check_uri(uri)
      result = /\A(?<protocol>\w+):\/\/(?<hostname>[^:]+):(?<port>\d+)\Z/.match(uri)
      if result.nil?
        raise "URI's must be in: protocol://hostname:port format"
      end

      if result[:hostname] == "localhost"
        raise "'localhost' is not allowed, since ZMQ will silently fail on IPv6-enabled hosts"
      end
    end

    #
    # Create a socket and connect in one go, setting sane defaults for sockopts.
    # Defaults:
    # * ZMQ::LINGER => 1
    # * ZMQ::HWM    => 1
    #
    # Example:
    #  Hastur::Util.connect_socket(ctx, ZMQ::PUSH, "tcp://127.0.0.1:1234")
    #
    def connect_socket(ctx, type, uri, opts = {})
      bind_or_connect_socket(ctx, type, uri, opts.merge(:connect => true, :bind => false))
    end

    #
    # Create a socket and bind in one go, setting sane defaults for sockopts.
    # Defaults:
    # * ZMQ::LINGER => 1
    # * ZMQ::HWM    => 1
    #
    # Example:
    #  Hastur::Util.bind_socket(ctx, ZMQ::PULL, "tcp://127.0.0.1:1234")
    #
    def bind_socket(ctx, type, uri, opts = {})
      bind_or_connect_socket(ctx, type, uri, opts.merge(:connect => false, :bind => true))
    end

    #
    # Send a Hastur-specific message with a header envelope containing version, time, and sequence.
    #
    def hastur_send(socket, method, data_hash)
      method ||= "error"
      @seq_num ||= 0
      @uptime ||= Time.now.to_i
      packet_data = {
        'sequence' => @seq_num,
        'uptime' => @uptime,
        'time' => Time.now,
      }
      method_data = { 'method' => method } if data_hash[:method].nil?
      @seq_num += 1
      json = MultiJson.encode(data_hash.merge(packet_data).merge(method_data || {}))
      envelope = [ "v1\n#{method}\nack:none" ]
      socket.send_strings(envelope + [ json ])
    end

    private

    #
    # Create a socket and bind or connect in one go, setting sane defaults for sockopts.
    # Defaults:
    # * ZMQ::LINGER => 1
    # * ZMQ::HWM    => 1
    #
    # Example:
    #  Hastur::Util.bind_socket(ctx, ZMQ::PULL, "tcp://127.0.0.1:1234")
    #
    def bind_or_connect_socket(ctx, type, uri, opts = {})
      if type.kind_of?(Symbol) || type.kind_of?(String)
        type = ZMQ.const_get(type.to_s.upcase)
      end

      socket = ctx.socket(type)

      opts[:linger] = 1 unless opts.has_key?(:linger)
      opts[:hwm]    = 1 unless opts.has_key?(:hwm)

      # Linger and HWM aren't strictly necessary, but the behavior
      # they enable is what we usually expect.  For now, have all
      # sockets use the same options.  Set socket options *before*
      # bind or connect.

      # flush messages before shutdown
      socket.setsockopt(ZMQ::LINGER, opts[:linger]) if opts[:linger]
      # high water mark, the number of buffered messages
      socket.setsockopt(ZMQ::HWM,    opts[:hwm])    if opts[:hwm]
      # Identity for router, req and sub sockets
      socket.setsockopt(ZMQ::IDENTITY, opts[:identity]) if opts[:identity]

      status = 0
      if opts[:bind]
        status = socket.bind uri
      elsif opts[:connect]
        if uri.respond_to?(:each)
          uri.each do |single_uri|
            status = socket.connect single_uri
            break if status < 0
          end
        else
          status = socket.connect uri
        end
      else
        raise "Must provide either bind or connect option to bind_or_connect_socket!"
      end
      socket
    end
  end
end

