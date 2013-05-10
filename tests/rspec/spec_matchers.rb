
# Matchers for comparing string with different encoding

RSpec::Matchers.define :binary_include do |needle|
  match do |string|
    string.force_encoding('BINARY').include? needle.force_encoding('BINARY')
  end
end

RSpec::Matchers.define :binary_equals do |needle|
  match do |string|
    string.force_encoding('BINARY') == needle.force_encoding('BINARY')
  end
end

RSpec::Matchers.define :binary_match do |regexp|
  match do |string|
    string  =~ regexp
  end
end
