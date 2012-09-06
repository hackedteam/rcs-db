#
#  SDL Language Weaver handling stuff
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/utf16le'

require 'ffi'

module RCS
module OCR

=begin

  typedef BOOL (*OCRDump_t)(WCHAR *, WCHAR *);
  void UseDLL()
  {
      BOOL ret;
  HMODULE hmod = LoadLibrary("C:\\RCS\\DB\\OCR\\OCR.dll");

  OCRDump_t pDump = (OCRDump_t)GetProcAddress(hmod, "OCRDump");
  ret = pDump(L"C:\\test.jpg", L"C:\\out.txt");
  }
=end

module SDL
  extend FFI::Library

  # we can use the HASP dongle only on windows
  if RbConfig::CONFIG['host_os'] =~ /mingw/
    ffi_lib File.join(Dir.pwd, 'ocr.dll')

    ffi_convention :stdcall

    attach_function :OCRDump, [:pointer, :pointer], :bool
  end

end

class Weaver
  extend RCS::Tracer

  class << self

    def transform(input_file, output_file)

      # cannot run on macos
      return  if RbConfig::CONFIG['host_os'] =~ /darwin/

      # allocate the memory
      inf = FFI::MemoryPointer.from_string(input_file.to_utf16le_binary)
      outf = FFI::MemoryPointer.from_string(output_file.to_utf16le_binary)

      # call the actual method in the DLL
      ret = SDL.OCRDump(inf, outf)

      trace :debug, "SDL ret: #{ret}"
    end

  end

end

end #DB::
end #RCS::
