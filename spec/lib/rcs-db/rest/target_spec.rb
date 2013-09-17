require 'spec_helper'
require_db 'db_layer'
require_db 'rest'
require_db 'rest/target'

module RCS::DB
  describe TargetController do

    before do
      # skip check of current user privileges
      subject.stub :require_auth_level

      subject.stub(:mongoid_query).and_yield

      # stub the #ok method and then #not_found methods
      subject.stub(:ok) { |*args| args.first }
      subject.stub(:not_found) { |message| message }
    end
  end
end
