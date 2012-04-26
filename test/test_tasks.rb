require_relative 'helper'
require_db 'tasks'

=begin

module RCS
module DB

class DummyGenerator
  def count
    10
  end

  def next_entry
    yield 'test', 'test'
  end
end

end # ::DB
end # ::RCS

class TestTaskProcessor < Test::Unit::TestCase
  def test_get_valid_processor
    processor = RCS::DB::TaskProcessor.get 'dummy'
    assert_not_nil processor
    assert_respond_to processor, :process
    assert_equal 10, processor.count
  end
  
  def test_get_invalid_processor
    assert_nil RCS::DB::TaskProcessor.get 'invalid'
  end
end

=end