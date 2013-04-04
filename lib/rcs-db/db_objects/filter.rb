require 'mongoid'

#module RCS
#module DB

class EvidenceFilter
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user, type: Array, default: []
  field :name, type: String
  field :filter, type: String   # json

  index({name: 1}, {background: true})

  store_in collection: 'filters'

  def self.create_default
    EvidenceFilter.destroy_all({name: "Skype calls last month"})
    EvidenceFilter.find_or_create_by({user: [], name: "Skype calls last month", filter: {from: 'month', to: 0, date: 'da', type: ['call'], info: 'program:skype'}.to_json})

    EvidenceFilter.destroy_all({name: "Keylogged passwords last month"})
    EvidenceFilter.find_or_create_by({user: [], name: "Keylogged passwords last month", filter: {from: 'month', to: 0, date: 'da', type: ['keylog'], info: 'window:password'}.to_json})

    EvidenceFilter.destroy_all({name: "Facebook chats last week"})
    EvidenceFilter.find_or_create_by({user: [], name: "Facebook chats last week", filter: {from: 'week', to: 0, date: 'da', type: ['chat'], info: 'program:facebook'}.to_json})

    EvidenceFilter.destroy_all({name: "Used application last 24h"})
    EvidenceFilter.find_or_create_by({user: [], name: "Used application last 24h", filter: {from: '24h', to: 0, date: 'da', type: ['application'], info: 'action:start'}.to_json})

    EvidenceFilter.destroy_all({name: "Opened files last 24h"})
    EvidenceFilter.find_or_create_by({user: [], name: "Opened files last 24h", filter: {from: '24h', to: 0, date: 'da', type: ['file'], info: 'type:open'}.to_json})

    EvidenceFilter.destroy_all({name: "Captured files last 24h"})
    EvidenceFilter.find_or_create_by({user: [], name: "Captured files last 24h", filter: {from: '24h', to: 0, date: 'da', type: ['file'], info: 'type:capture'}.to_json})

    EvidenceFilter.destroy_all({name: "Relevant evidence all time"})
    EvidenceFilter.find_or_create_by({user: [], name: "Relevant evidence all time", filter: {from: 0, to: 0, date: 'da', rel: [3,4]}.to_json})

    EvidenceFilter.destroy_all({name: "Future calendar events"})
    EvidenceFilter.find_or_create_by({user: [], name: "Future calendar events", filter: {from: 'now', to: 0, date: 'da', type: ['calendar']}.to_json})
  end
end


#end # ::DB
#end # ::RCS