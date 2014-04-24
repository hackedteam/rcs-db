require 'spec_helper'
require_ocr 'facereco'

module RCS
  module OCR
    describe FaceRecognition do

      it 'should not find any face if not present' do
        found = FaceRecognition.detect(fixtures_path('faces/0.jpg'))
        found.should eq({:face => false})
      end

      # it 'should find a face in this picture (1)' do
      #   found = FaceRecognition.detect(fixtures_path('faces/1.jpg'))
      #   found.should eq({:face => true})
      # end

      it 'should find a face in this picture (2)' do
        found = FaceRecognition.detect(fixtures_path('faces/2.jpg'))
        found.should eq({:face => true})
      end

      it 'should find a face in this picture (3)' do
        found = FaceRecognition.detect(fixtures_path('faces/3.jpg'))
        found.should eq({:face => true})
      end

      it 'should find a face in this picture (4)' do
        found = FaceRecognition.detect(fixtures_path('faces/4.jpg'))
        found.should eq({:face => true})
      end

      it 'should find a face in this picture (z1)' do
        found = FaceRecognition.detect(fixtures_path('faces/z1.jpg'))
        found.should eq({:face => true})
      end

      it 'should find a face in this picture (q1)' do
        found = FaceRecognition.detect(fixtures_path('faces/q1.jpg'))
        found.should eq({:face => true})
      end

      # it 'should find a face in this picture (d1)' do
      #   found = FaceRecognition.detect(fixtures_path('faces/d1.png'))
      #   found.should eq({:face => true})
      # end

      it 'should find a face in this picture (d2)' do
        found = FaceRecognition.detect(fixtures_path('faces/d2.png'))
        found.should eq({:face => true})
      end

      it 'should react correctly if the image does not exist' do
        FaceRecognition.should_receive(:trace).with(:error, "Cannot process image: file does not exist or invalid format image.")
        found = FaceRecognition.detect(fixtures_path('faces/not_existant.jpg'))
        found.should eq({:face => false})
      end
    end
  end
end
