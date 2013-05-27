
# Matchers for comparing string with different encoding

RSpec::Matchers.define :binary_include do |needle|
  match do |string|
    string.force_encoding('BINARY').include? needle.force_encoding('BINARY')
  end
end

RSpec::Matchers.define :binary_equals do |needle|
  match do |string|
    string.force_encoding('BINARY') == needle.force_encoding('BINARY')
  end
end

RSpec::Matchers.define :binary_match do |regexp|
  match do |string|
    string  =~ regexp
  end
end

# Check if a mongoid document has been added to the PushQueue
#
# @examples:
#   expect(my_target).to be_in_push_queue
#   expect(my_target).to be_in_push_queue.with_action(:create)
#   expect(my_entity).to be_in_push_queue.with_action(:create).exactly 3.times
#   expect(my_entity).to be_in_push_queue.exactly 7.times
RSpec::Matchers.define :be_in_push_queue do
  chain :with_action do |action_name|
    @action_name = action_name
  end

  chain :exactly do |count|
    @count = count.respond_to?(:max) ? count.max+1 : count
  end

  match do |object|
    # Only mondoid documents can be added to the PushQueue
    return false unless object.respond_to? :_id

    # Optional: Filter for the object type
    filter = {}
    filter['type'] = 'entity' if object.kind_of? Entity

    filter['message.id'] = object.id
    filter['message.action'] = "#{@action_name}" if @action_name

    criteria = PushQueue.where(filter)

    if @count
      criteria.count == @count
    else
      criteria.exists?
    end
  end
end
