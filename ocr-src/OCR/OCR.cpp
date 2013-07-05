// OCR.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "OCR.h"

#define LTV175_CONFIG 175
#include "ltver.h"
#include "l_bitmap.h"
#include "ltdoc2.h"

BOOL is_initialized = FALSE;

BOOL LoadBitmap(L_HDOC2 hDoc,L_TCHAR* pszFileName, BITMAPHANDLE *Bitmap)
{
   if (L_LoadBitmap(pszFileName, Bitmap, sizeof(BITMAPHANDLE), 0, ORDER_BGRORGRAY, NULL, NULL) != SUCCESS)
	   return FALSE;

   if (L_Doc2AddPage(hDoc, Bitmap, 0) != SUCCESS)
		return FALSE;

   return TRUE;
}

BOOL SaveToFile(L_HDOC2 hDoc, WCHAR *dest_file)
{
	RESULTOPTIONS2 ResOpts;
    RECOGNIZEOPTS2 RecogOpts;

	L_INT nRet;

	ZeroMemory(&RecogOpts, sizeof(RECOGNIZEOPTS2));
	ZeroMemory(&ResOpts, sizeof(RESULTOPTIONS2));
    RecogOpts.uStructSize         = sizeof(RECOGNIZEOPTS2);
    RecogOpts.nPageIndexStart     = 0;
    RecogOpts.nPagesCount         = 1;
    RecogOpts.bEnableSubSystem    = TRUE;
    RecogOpts.bEnableCorrection   = TRUE;
    RecogOpts.SpellLangId         = DOC2_LANG_ID_AUTO;

	nRet = L_Doc2FindZones(hDoc, 0);

	if(nRet != SUCCESS)
		return FALSE;

	nRet = L_Doc2GetRecognitionResultOptions(hDoc, &ResOpts, sizeof(RESULTOPTIONS2));
	if(nRet != SUCCESS)
		return FALSE;

	ResOpts.Format = DOC2_UFORMATTED_TEXT;
	ResOpts.DocFormat = DOCUMENTFORMAT_TXT;
	
	nRet = L_Doc2SetRecognitionResultOptions(hDoc, &ResOpts);
	if(nRet != SUCCESS)
		return FALSE;

	nRet = L_Doc2Recognize(hDoc, &RecogOpts, NULL, NULL);
	if (nRet != SUCCESS)
		return FALSE;

	nRet = L_Doc2SaveResultsToFile(hDoc, dest_file);
	if (nRet != SUCCESS)
		return FALSE;

	return TRUE;
}

BOOL SetUp(L_HDOC2 *hDoc, L_INT *coll_id)
{
	*hDoc = NULL;
	*coll_id = 0;

	if (L_Doc2StartUp(hDoc, NULL, FALSE) != SUCCESS)
		return FALSE;

	if (L_Doc2CreateSettingsCollection(*hDoc, -1, coll_id) != SUCCESS)
		return FALSE;

	if (L_Doc2SetActiveSettingsCollection(*hDoc, *coll_id) != SUCCESS)
		return FALSE;

	return TRUE;
}

OCR_API BOOL OCRDump(WCHAR *image, WCHAR *dest)
{
	L_HDOC2 hDoc;
	L_INT coll_id;
	BITMAPHANDLE LEADBitmap;
	BOOL ret_val = FALSE;

	if (!is_initialized) {
		if (L_SetLicenseFile(L"C:\\RCS\\DB\\OCR\\OCR.lic", L"RZT2f5TM1kXA8sz+kmkRzbZuvhDAMSccTlc5qzEwYQzUnEYGYOKyY9z/JjQn91p49yxKN7buYut+GaHkt73vuF71ghKym5zO28thkOvBEtpoPWd552NCQ2mkEjlZ/i3qvCK5io9/Xz2c5HYQQUXE0DGWSTy2Njea6Y96GTtOVrJ20HlcBoJvOK5LRytgh+Zs/qjWLCaDnUmmiG9zoh75fRVbIAgJSFMJX6n/3SuhpmkTjODVckhTqlzOR8bZIOtFAf/jgH98IU0PJdRPaBS4A04rSS2PZNKMeBogoLnTCKMIf5KLUE+6ZlitzJ65GFX9uD3MsKnCFFyogd+/ynoN2XP94DUmpBTDSj3F6CHbMORBC33zvjZTt6nRkoJwlwgdN72QWq+bbWgD6Sw9KPDKO3aUdCurxz7oAhQpMBrpmRhtIbgPI1iEcXOxVTnCdmslKuS6q0Aw2X6OCyxrseE3tg==") != SUCCESS)
			return FALSE;
		is_initialized = TRUE;
	}

	if (L_InitBitmap(&LEADBitmap, sizeof(BITMAPHANDLE), 0, 0, 0) != SUCCESS)
		return FALSE;

	if (SetUp(&hDoc, &coll_id)) 
		if (LoadBitmap(hDoc, image, &LEADBitmap))
			if (SaveToFile(hDoc, dest))
				ret_val = TRUE;

	if (LEADBitmap.Flags.Allocated)
		L_FreeBitmap(&LEADBitmap);

	if (hDoc && coll_id)
		L_Doc2DeleteSettingsCollection(hDoc, coll_id);
	if (hDoc)
		L_Doc2ShutDown(&hDoc);

	return ret_val;
}


/*
typedef BOOL (*OCRDump_t)(WCHAR *, WCHAR *);

void UseDLL()
{
	BOOL ret;
	HMODULE hmod = LoadLibrary("C:\\OCR.dll");

	OCRDump_t pDump = (OCRDump_t)GetProcAddress(hmod, "OCRDump");
	ret = pDump(L"C:\\Users\\naga\\Desktop\\Untitled.jpg", L"C:\\Users\\naga\\AppData\\Local\\Temp\\out1.txt");
}	
*/

