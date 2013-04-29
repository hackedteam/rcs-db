require 'spec_helper'
require_db 'db_layer'

describe Alert do
  describe 'relations' do
  	it 'should embeds many AlertLogs' do
      subject.should respond_to :logs
    end

    it 'should belongs to a User' do
      subject.should respond_to :user
    end
  end


  context 'given an Alert with one Log' do
    before do
      @alert = Alert.new last: Time.now.to_i
      @alert.logs << AlertLog.new
    end

    context 'when all the Logs are deleted' do
      before { @alert.logs.last.destroy }

      it 'should reset the parent Alert "last" attribute' do
        @alert.last.should be_nil
      end
    end
  end


  context 'given an Alert with two Logs' do
    before do
      @last_time = Time.now.to_i
      @alert = Alert.new last: @last_time
      @alert.logs.concat [AlertLog.new, AlertLog.new]
    end

    context 'when only one AlertLog is deleted' do
      before { @alert.logs.sample.destroy }

      it 'the "last" attribute should not be resetted' do
        @alert.last.should == @last_time
      end
    end
  end
end
