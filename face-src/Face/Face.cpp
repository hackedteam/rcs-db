// Face.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "Face.h"

#include <iostream>
#include <stdio.h>

#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;


int detect_and_draw_faces( IplImage* image, CvHaarClassifierCascade* cascade)
{
	CvMemStorage* storage = cvCreateMemStorage(0);
	CvSeq* faces;

	/* use the fastest variant */
	//faces = cvHaarDetectObjects( image, cascade, storage, 1.2, 2, CV_HAAR_DO_CANNY_PRUNING );
	faces = cvHaarDetectObjects( image, cascade, storage, 1.1, 3, CV_HAAR_DO_CANNY_PRUNING );

	/* draw all the rectangles */
	for(int i = 0; i < faces->total; i++ ) {
		/* extract the rectangles only */
		CvRect face_rect = *(CvRect*)cvGetSeqElem( faces, i);
		cvRectangle( image, cvPoint(face_rect.x, face_rect.y),
			cvPoint((face_rect.x + face_rect.width), (face_rect.y + face_rect.height)),
			CV_RGB(255,0,0), 3 );
	}

	cvReleaseMemStorage( &storage );

	return faces->total;
}

FACE_API int detect_faces(char* input_file, char *xml, int display) 
{
	CvHaarClassifierCascade *classifier = NULL;
	IplImage* image = NULL;
	int faces;

	classifier = (CvHaarClassifierCascade*)cvLoad(xml, 0, 0, 0);
	if (!CV_IS_HAAR_CLASSIFIER(classifier)) {
		printf("Cannot load haar classifier file: %s\n", xml);
		return -1;
	}

	image = cvLoadImage( input_file );
	if (image == NULL) {
		printf("Cannot load image: %s\n", input_file);
		return -2;
	}

	faces = detect_and_draw_faces( image, classifier);

	if (display == 1) {
		cvNamedWindow( "test", 0 );
		cvShowImage( "test", image );
		cvWaitKey(0);
	}

	cvReleaseHaarClassifierCascade( &classifier );
	cvReleaseImage( &image );

	return faces;
}
