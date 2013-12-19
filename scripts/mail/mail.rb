require 'mail'
require 'pry'

class String
  def safe_utf8_encode
    self.force_encoding('UTF-8')
    self.encode! 'UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: 'x'
    #self.encode!('UTF-8', self.encoding.to_s, :invalid => :replace)
  end
end

def parse_multipart(parts)
  content_types = parts.map { |p| p.content_type.split(';')[0] }
  body = {}
  content_types.each_with_index do |ct, i|
    case ct
      when 'multipart/alternative'
        body = parse_multipart(parts[i].parts)
      else
        body ||= {}
        body[ct] = parts[i].body.decoded #.safe_utf8_encode
    end
  end
  body
end

def parse_multipart_new(parts)
  content_types = parts.map { |p| p.content_type.split(';')[0] }
  body = {}
  content_types.each_with_index do |ct, i|
    puts '-'*i + "> #{ct} : #{parts[i].multipart?}"
    if parts[i].multipart?
      body = parse_multipart_new(parts[i].parts)
    else
      puts '-'*i + "> #{parts[i].body.decoded.encoding}"
      body[ct] = parts[i].body.decoded.safe_utf8_encode
      body[ct].safe_utf8_encode
    end
  end
  body
end

mail = File.read('test.eml')
#mail = File.read('arabic.eml')
#mail = File.read('corrupted.eml')
#mail = File.read('multipart.eml')

parsed = Mail.read_from_string mail

puts "Date: " + parsed.date.to_time.to_s
puts "From: " + parsed.from.inspect
puts "To: " + parsed.to.inspect
puts "CC: " + parsed.cc.inspect
puts "Subject: " + parsed.subject.inspect

#binding.pry

puts
puts "Attachments: #{parsed.attachments.size}"
parsed.attachments.each do |attach|
  puts "#{attach.content_type}"
end
puts
puts "Multipart?: " + parsed.multipart?.to_s
puts "Part size: #{parsed.parts.size}"
puts
puts parsed.parts.inspect

puts
puts '----------------'
body = parse_multipart(parsed.parts) if parsed.multipart?
body ||= {}
body['text/plain'] ||= parsed.body.decoded unless parsed.body.nil?
puts body.keys
puts body.values.map {|x| x.size}

puts
puts '----------------'
body = parse_multipart_new(parsed.parts) if parsed.multipart?
body ||= {}
body['text/plain'] ||= parsed.body.decoded unless parsed.body.nil?
puts body.keys
puts body.values.map {|x| x.size}

#exit

if body.has_key? 'text/html'
  evidence = body['text/html']
else
  evidence = body['text/plain']
  evidence ||= 'Content of this mail cannot be decoded.'
end

puts
puts '----------------'
puts body['text/plain']
puts
puts '----------------'
puts body['text/html']
puts '----------------'
puts 

begin
  puts evidence.encoding
  if evidence =~ Regexp.new("vacation", true)
    puts "matched"
  else
    puts "not matched"
  end
rescue Exception => e
  puts e.message
  puts e.backtrace.join("\n")
end