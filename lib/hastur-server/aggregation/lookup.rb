require "hastur-server/time_util"
require "hastur-server/aggregation/base"
require "hastur-server/cassandra/schema"
require "hastur-server/cassandra/derive"

module Hastur
  module Aggregation
    include Hastur::TimeUtil
    extend self
    @functions.merge! "cname" => :cname, "fqdn" => :fqdn, "hostname" => :hostname

    def hostname(series, control)
      fqdn(cname(series, control))
    end

    def cname(series, control)
      names = do_lookup(series, control)
      new_series = {}
      series.keys.each do |uuid|
        if names[uuid][:cnames] and names[uuid][:cnames].any?
          new_series[names[uuid][:cnames][0]] = series[uuid]
        end
      end
      return new_series, control
    end

    def fqdn(series, control)
      names = do_lookup(series, control)
      new_series = {}
      series.keys.each do |uuid|
        if names[uuid][:fqdn]
          new_series[names[uuid][:fqdn]] = series[uuid]
        end
      end
      return new_series, control
    end

    private

    def do_lookup(series, control)
      Hastur::Cassandra.network_names_for_uuids(
        control[:cass_client],
        series.keys,
        control[:start_ts],
        control[:end_ts]
      )
    end
  end
end
