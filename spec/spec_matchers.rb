
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


# Check target entity have been in place (position entity) at a specific time
#
# @examples:
#   expect(bob).to have_been_in(duomo)
#   expect(bob).to have_been_in(duomo).exactly 3.times
# @TODO:
#   expect(bob).to have_been_in(duomo).at Time.new(2013, 02, 01)
#   expect(bob).to have_been_in(duomo).at [{"start"=>1358253164, "end"=>1358257904}, {"start"=>1358426673, "end"=>1358428978}]
RSpec::Matchers.define :have_been_in do |position_entity|
  chain :exactly do |number|
    @exactly = number.respond_to?(:max) ? number.max+1 : number
  end

  match do |entity|
    # Check if the two entity are linked
    result = entity.linked_to? position_entity, type: :position

    # Get the link that connect `enetiy` with `position_entity`. The "info" attribute
    # contains a list of timeframes that represent the moments in which `entity` has
    # been in `position_entity`
    if result and @exactly
      link = entity.links.connected_to(position_entity).first
      result = link.info.size == @exactly
    end

    result
  end
end
