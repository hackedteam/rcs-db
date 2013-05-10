require 'spec_helper'

require_db 'db_layer'
require_db 'grid'
require_db 'build'

module RCS
module DB

  describe BuildLinux do

    describe '#intialize' do

      it 'sets the "platform" to "linux"' do
        expect(subject.platform).to eql 'linux'
      end
    end
  end

end
end
