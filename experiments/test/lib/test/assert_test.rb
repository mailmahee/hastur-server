$LOAD_PATH.unshift "../"

require "test/unit"
require "assertions"

class AssertionTest < Test::Unit::TestCase
  include ::Hastur::Test::Assert

  def test_packet_equal_1
    e = {:a => "d"}
    a = {:a => "d", :e => "does not really matter"}
    assert(packet_equal(e, a))
  end
  
  def test_packet_equal_2
    e = {:a => {:b => "foo"}}
    a = {:a => { :b => "foo" }, :e => "does not really matter"}
    fake = {:a => "d", :e => "does not really matter"}
    assert(!packet_equal(e, fake))
    assert(packet_equal(e, a))
  end

  def test_packet_list_equal_1
    e = [{:a => {:b => "foo"}}, {:a => "h"}]
    a = [{:a => "h"}, {:a => {:b => "foo"}}]
    assert(packet_list_equal(e, a)) 
  end

  def _test_packet_list_equal_2
    e = [{:a => {:b => "foo"}}, {:a => "h"}]
    a = [{:a => "h"}, {:a => {:b => "foo"}}, {:a => "h"}]
    assert(!packet_list_equal(e, a))
  end
end
