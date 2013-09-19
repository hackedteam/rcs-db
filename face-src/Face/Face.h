// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the FACE_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// FACE_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.
#ifdef FACE_EXPORTS
#define FACE_API __declspec(dllexport)
#else
#define FACE_API __declspec(dllimport)
#endif


FACE_API int detect_faces(char* input_file, char *xml = "haarcascade_frontalface_default.xml", int display = 0);