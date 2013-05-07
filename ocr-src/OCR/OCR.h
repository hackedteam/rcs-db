// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the OCR_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// OCR_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.
#ifdef OCR_EXPORTS
#define OCR_API __declspec(dllexport)
#else
#define OCR_API __declspec(dllimport)
#endif

OCR_API BOOL OCRDump(WCHAR *image, WCHAR *dest);

