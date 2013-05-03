require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'

module RCS
module DB

  describe LinkManager do
    before do
      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer
    end

  end

end
end

