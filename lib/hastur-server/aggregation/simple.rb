require "hastur-server/aggregation/base"

module Hastur
  module Aggregation
    extend self

    @functions.merge!({
      "integral"   => :integral,
      "derivative" => :derivative,
      "min"        => :min,
      "max"        => :max,
      "sum"        => :sum,
      "first"      => :first,
      "last"       => :last,
      "slice"      => :slice,
      "resample"   => :resample,
      "compact"    => :compact
    })

    #
    # Remove all but the first <count> elements in the series.
    #
    # @param [Hash] series
    # @param [Fixnum] count default 1
    # @return [Hash] series
    #
    def first(series, control, count=1)
      slice(series, control, 0, count-1)
    end

    #
    # Remove all but the last <count> elements in the series.
    #
    # @param [Hash] series
    # @param [Fixnum] count default 1
    # @return [Hash] series
    #
    def last(series, control, count=1)
      slice(series, control, count * -1, -1)
    end

    #
    # Take a fixed slice of elements from the series.
    #
    # @param [Hash] series
    # @param [Fixnum] first_idx the starting index
    # @param [Fixnum] last_idx the final index
    # @return [Hash] series
    #
    def slice(series, control, first_idx, last_idx)
      new_series = {}
      series.each do |uuid, name_series|
        new_series[uuid] = {}
        name_series.each do |name, ts_val|
          if skip_name?(control, name)
            ts_val
          else
            new_series[uuid][name] = {}
            keys = ts_val.keys[first_idx..last_idx]
            keys.each do |ts|
              new_series[uuid][name][ts] = ts_val[ts]
            end
          end
        end
      end
      return new_series, control
    end

    #
    # Cut the series down to the requested number of samples using a simple mod & drop function.
    # The time step is not guaranteed to be uniform and is not normalized.
    #
    # @example
    #   resample(100) - return 100 samples evenly distributed across the series
    #
    def resample(series, control, samples)
      each_subseries_in series, control do |name, subseries|
        new_subseries = {}
        count = 0
        sample_every = (subseries.count / samples).floor

        subseries.each do |ts,val|
          if count % sample_every == 0
            new_subseries[ts] = val
          end
          count = count + 1
        end
        new_subseries
      end
    end

    #
    # Remove non-numeric (e.g. null, strings) values from the series, or if you provide a replacement
    # value, replace those entries in the series with that value.
    #
    # @param [Hash] series
    # @param [String,Numeric,FalseClass] replace optional value to replace nil/null in the series
    #
    def compact(series, control, replace=false)
      each_subseries_in series, control do |name, subseries|
        new_subseries = {}
        subseries.each do |ts,val|
          if Numeric === val
            new_subseries[ts] = val
          elsif replace
            new_subseries[ts] = replace
          end
        end
        new_subseries
      end
    end

    #
    # Replace the series with the running sum for each timestamp.
    #
    # @param [Hash] series
    # @param [Fixnum] first_idx the starting index
    # @param [Fixnum] last_idx the final index
    # @return [Hash] series
    #   :first peek at the first value in the series for the first subtraction
    #   :shift pop the first value in the series for the first subtraction
    #   Numeric use the given number for the first subraction
    # @example
    #   sum() - start with 0 by default
    #   sum(shift) - shift the first value to initialize, series will be 1 item smaller
    #   sum(100) - start with an arbitrary number
    #   last(sum()) - get the final (total) value of the summed series
    #
    def integral(series, control, seed=0)
      map_over series, control, seed do |val,total|
        [val + total, val + total]
      end
    end

    #
    # Replace the series with the difference between neighboring values.
    # Useful for handling counters that are stored as absolutes.
    #
    # @param [Hash] series
    # @param [Symbol,Numeric] seed optional how to seed the difference
    #   :first peek at the first value in the series for the first subtraction
    #   :shift pop the first value in the series for the first subtraction
    #   Numeric use the given number for the first subraction
    # @return [Hash] series
    #
    def derivative(series, control, seed=:first)
      map_over series, control, seed do |val,previous|
        [val - previous, val]
      end
    end

    #
    # Find the highest value in each series and remove all other ts/vals.
    #
    # @param [Hash] series
    # @return [Hash] series
    #
    def max(series, control, ignore=nil)
      each_subseries_in series, control do |name, subseries|
        { :max => subseries.values.sort.last }
      end
    end

    #
    # Find the lowest value in each series and remove all other ts/vals.
    #
    # @param [Hash] series
    # @return [Hash] series
    #
    def min(series, control, ignore=nil)
      each_subseries_in series, control do |name, subseries|
        { :min => subseries.values.sort.first }
      end
    end

    #
    # Add up all the values in each series.
    #
    # @param [Hash] series
    # @return [Hash] series
    #
    def sum(series, control, seed=0)
      each_subseries_in integral(series, control, seed), control do |name, subseries|
        { :sum => subseries.values.last }
      end
    end
  end
end
