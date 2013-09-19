// FaceReco.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <Windows.h>

#include <Face.h>

typedef int (*DetectFace_t)(char *, char *, int);

int _tmain(int argc, _TCHAR* argv[])
{
	char input[256];
	int faces;

	if (argc<2) {
		fprintf(stderr, "usage:\n%S <image>\n", argv[0]);
		exit(-1);
	}

	sprintf_s(input, 256, "%S", argv[1]);

	HMODULE hmod = LoadLibrary(L"Face.dll");
	printf("hmod: %x\n", hmod);
	DetectFace_t detect_faces = (DetectFace_t)GetProcAddress(hmod, "detect_faces");
	printf("DetectFace_t: %x\n", detect_faces);

	faces = detect_faces(input, "haarcascade_frontalface_default.xml", 1);

	if (faces > 0) 
		printf("Face detected: %d\n", faces);

	exit(0);
}

