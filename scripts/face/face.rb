require 'opencv'
include OpenCV

INPUT = 'd2.png'

image = CvMat.load(INPUT)

Dir['haarcascades/*'].each do |xml|
  detector = CvHaarClassifierCascade::load(xml)
  found = false
  detector.detect_objects(image).each do |region|
    found = true
    color = CvColor::Blue
    image.rectangle! region.top_left, region.bottom_right, :color => color
  end
  puts "#{xml.ljust(50)} #{found}"

  if found
    window = GUI::Window.new('Face: ' + File.basename(xml))
    window.show(image)
    GUI::wait_key
    window.destroy
  end
end

