require 'spec_helper'
require_db 'db_layer'


describe Alert do
  before { turn_off_tracer}

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
      connect_mongo
      empty_test_db

      @last_time = Time.now.to_i
      @alert = Alert.new last: @last_time
      @alertLogA, @alertLogB = AlertLog.new, AlertLog.new
      @alert.logs.concat [@alertLogA, @alertLogB]
    end

    context 'when only one AlertLog is deleted' do
      before { @alert.logs.sample.destroy }

      it 'the "last" attribute should not be resetted' do
        @alert.last.should == @last_time
      end
    end

    context 'when an AlertLog is too old' do
      before do
        @alertLogA.time = Time.now - 2.weeks
        @alert.save
      end

      context '#destroy_old_logs' do
        before do
          Alert.destroy_old_logs
          @alert.reload
        end

        it 'should destroy the old AlertLog' do
          @alert.logs.count.should == 1
          @alert.logs.first.should == @alertLogB
        end
      end
    end
  end
end
