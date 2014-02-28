#
#  LEADTOOLS interface
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

module LEADTOOLS
  extend FFI::Library

  if RbConfig::CONFIG['host_os'] =~ /mingw/
    ffi_lib File.join($execution_directory, 'ocr/ocr.dll')

    ffi_convention :stdcall

    attach_function :OCRDump, [:pointer, :pointer], :bool
  end

end

class LeadTools
  extend RCS::Tracer

  class << self

    def transform(input_file, output_file)

      # cannot run on macos
      return if RbConfig::CONFIG['host_os'] =~ /darwin/

      # null terminate the strings for the DLL
      input_null = input_file.gsub("/", "\\") + "\x00"
      output_null = output_file.gsub("/", "\\") + "\x00"

      # allocate the memory
      inf = FFI::MemoryPointer.from_string(input_null.to_utf16le_binary)
      outf = FFI::MemoryPointer.from_string(output_null.to_utf16le_binary)

      # call the actual method in the DLL
      LEADTOOLS.OCRDump(inf, outf)
    end

  end

end

end #DB::
end #RCS::
