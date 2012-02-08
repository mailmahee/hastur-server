#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'minitest/autorun'
require 'ffi-rzmq'
require 'securerandom'
require 'socket'

require 'hastur/client'
require 'hastur/message'

class TestClassHasturClientModule < MiniTest::Unit::TestCase
  ROUTER_URI = "ipc://router-#{self.class.to_s}"
  CLIENT_UUID = SecureRandom.uuid
  FAKE_UUID = SecureRandom.uuid
  STAT = {
    :name      => "foo.bar",
    :value     => 1024,
    :units     => "s",
    :timestamp => 1328176249.1028926,
  }
  LOG = "some stuff happened"
  ERROR = StandardError.new "something funky!"

  PLUGIN = {
    :command => "/bin/echo",
    :args    => "abcdefghijklmnopqrstuvwxyz",
  }
  PLUGIN_RESULT_REMOVE = [ :pid, :status ]
  PLUGIN_RESULT = PLUGIN.merge({
    :stdout  => PLUGIN[:args]
  })

  def zmq_router(ctx, router_uri)
    router = ctx.socket(ZMQ::ROUTER)
    router.setsockopt(ZMQ::LINGER, -1)
    router.bind(router_uri)

    seen = {
      'Hastur::Message::HeartbeatClient' => 0,
    }

    loop do
      msg = Hastur::Message.recv(router)
      puts "MSG: #{msg.to_json}"
      case msg
        when Hastur::Message::Stat
          seen[msg.class.to_s] = msg.decode
        when Hastur::Message::Log
          break if msg.payload == "Client #{CLIENT_UUID} exiting."
          seen[msg.class.to_s] = msg.paylaod
        when Hastur::Message::Error
          assert_equal ERROR.to_s, msg.payload
        when Hastur::Message::HeartbeatClient
          seen[msg.class.to_s] += 1
        when Hastur::Message::PluginResult
          data = msg.decode
          PLUGIN_RESULT_REMOTE.each { |key| data.delete key }
          assert_equal PLUGIN_RESULT, data
        when Hastur::Message::RegisterClient
          seen[msg.class.to_s] = msg
        when Hastur::Message::Rawdata
        when Hastur::Message::HeartbeatService
        when Hastur::Message::RegisterService
        when Hastur::Message::RegisterPlugin
        when Hastur::Message::Notification
          puts "Unexpected #{msg.class} message: #{msg.to_json}"
        else
          puts msg.to_json
      end
      msg.close_zmq_parts
    end

    assert_equal STAT, seen['Hastur::Message::Stat']['params']
    assert_equal LOG,  seen['Hastur::Message::Log']
    assert_equal 1,    seen['Hastur::Message::HeartbeatClient']
    assert_equal 1,    seen['Hastur::Message::RegisterClient']
    assert_equal PLUGIN_RESULT seen['Hastur::Message::PluginResult']

    assert_equal LOG, seen['Hastur::Message::Log']

    router.close
  end

  def test_fake_router
    ctx = ZMQ::Context.new

    router_thread = Thread.new do
      zmq_router(ctx, ROUTER_URI) rescue STDERR.puts $!.inspect, $@
    end

    client = Hastur::Client.new(
      :uuid         => CLIENT_UUID,
      :routers      => [ ROUTER_URI ],
      :port         => 20005,
      :heartbeat    => 1,
      :ack_interval => 1,
    )

    client_thread = Thread.new do
      client.run rescue STDERR.puts $!.inspect, $@
    end

    sleep 0.2

    packet = { :method => :stat, :params => STAT }
    UDPSocket.new.send MultiJson.encode(packet), 0, '127.0.0.1', 20005

    sleep 1

    client.shutdown

    sleep 0.3

    client_thread.join
    router_thread.join
    ctx.terminate
  end
end
