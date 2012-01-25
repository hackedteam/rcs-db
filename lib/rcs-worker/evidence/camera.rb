module RCS
module CameraProcessing
  def process
    puts "CAMERA: #{@info[:data]}"
  end

  def type
    :camera
  end
end # ApplicationProcessing
end # DB
