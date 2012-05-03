
#include "stdafx.h"
#include "hasp.h"
#include "hasp-key.h"
#include "aes_alg.h"
#include <stdio.h>

CRITICAL_SECTION dec_critic;

unsigned char vendor_code[] =
"gsqEryrFG9ltbm1YAtV0N7fMC1XAX229O4BUfEtTW+pmgucgMq3s2GExaMzOojem9AOoXiPy0ycVYfiy"
"WR+b4bbGrCV9yrB45p0oM4Jv3WAk4XEUFNY1Z2wQoO36qD5po184QLSZOVQttWDw5F4zqAjHKxWs2sWz"
"NbGU3DvbuEWE37QTkMSQCu8ttxZ0eT5LlG9IUncSS7Ay9FM9tpXWsSccwxvptWcCQfjfytQ6NeQL5ZMR"
"waUykVfd+lte2ejo6nE+eHiou2RxgUtehIzfPM6eT5bz0Y6//SyY8xQIGXW9fOjphVbXQhgHN1U66Jjb"
"7Po++/il6JZ+wzg5LoOSNXH7y3z98SWbqaJzUiohChbUN3oNHT4ll16dqeOhekyKDL9jTxejrpBd7Ve4"
"siEBgGr68ce7o/Jy7mXX3xttwKbQxb7tMfSDIVdQETNw1cAkbaCgdSkBnZmyoaGpnnBxYl9cFwInFz4f"
"5HXPXPoquNfzAu7njMii65JuZUGdwXQCd5c5AH/A0/V5kIb+ewOWrdA2DJBlld+msOiq25eFX/ivMzg5"
"r/votyLOqwv7h0oGsDGyhC6OJugWQh6PMAAGj/5NiY9NMEULUb7e3G4mxPct81E3+8tXMR2dRSCzEx6Y"
"hC297iA/yzrWFiZRBZF4kuHzTEB3vv7nQIZSeWLVjBzznXMRSkjmI2hXvDWQpcrB+ShEuPCZZG1ER0Mp"
"FaSWorpOyNCZPwodzfiQgH9sldlAEkIpCGvCWzpKgpp7RscVOO5l1wnxWSTrIt9ipYohnnxR++6oErRg"
"hazIuDv4dtOO8mr2ZL3uSXdYVExhoActIrsuDMUPM/vs9Bw4bvfplAMS+YI/KwX7SCpUhg8qg+PcAggi"
"WyPFukolkgfnLXbm+04kRc5bm8wbPDus7KWzRd23aOxqnSwuzwDuwjGe/YA=";

unsigned char crypt_key[16] = {0xB3, 0xE0, 0x2A, 0x88, 0x30, 0x69, 0x67, 0xAA, 0x21, 0x74, 0x23, 0xCC, 0x90, 0x99, 0x0C, 0x3C}; 

#define AES_PADDING 16
#define VERSION 20111222

#pragma pack(1)
typedef struct {
	DWORD version;
	char serial[256];
	hasp_time_t time;
	DWORD license_left;
} struct_info_t;
#pragma pack()

typedef struct {
	BYTE encrypted[sizeof(struct_info_t)+AES_PADDING];
} encrypted_info_t;

HASPKEY_API encrypted_info_t RI(BYTE *crypt_iv)
{
	char *info = NULL, *start = NULL, *end = NULL;   
	hasp_handle_t handle = HASP_INVALID_HANDLE_VALUE;
	hasp_time_t htime;
	struct_info_t struct_info;
	encrypted_info_t encrypted_info;
	aes_context crypt_ctx;
	DWORD tot_len, pad_len;
	BYTE iv[16];

	memcpy(iv, crypt_iv, 16);
	ZeroMemory(&struct_info, sizeof(struct_info));
	struct_info.version = VERSION;
	ZeroMemory(&encrypted_info, sizeof(encrypted_info));
	do {
		if(hasp_get_info("<haspscope />", "<haspformat root=\"rcs\"><hasp><attribute name=\"id\" /></hasp></haspformat>", vendor_code, &info) != HASP_STATUS_OK) {
			memcpy(&encrypted_info, "\x01", sizeof(char));
			break;
		}

		if(!(start = strstr(info, "<hasp id=\""))) {
			memcpy(&encrypted_info, "\x02", sizeof(char));
			break;
		}
		start += strlen("<hasp id=\"");

		if(!(end = strchr(start, '"'))) {
			memcpy(&encrypted_info, "\x03", sizeof(char));
			break;
		}
		*end = '\0';

		// Copio il seriale 
		_snprintf_s(struct_info.serial, sizeof(struct_info.serial), _TRUNCATE, "%s", start);		

		if(hasp_login(HASP_DEFAULT_FID, vendor_code, &handle) != HASP_STATUS_OK){
			memcpy(&encrypted_info, "\x04", sizeof(char));
			break;
		}

		if(hasp_get_rtc(handle, &htime) != HASP_STATUS_OK) {
			memcpy(&encrypted_info, "\x05", sizeof(char));
			break;
		}

		// Copio il timestamp
		struct_info.time = htime;

		// Copio il numero di agent rimasti per il pay-per-use
		if (hasp_read(handle, HASP_FILEID_RW, 0, 4, &struct_info.license_left) != HASP_STATUS_OK){
			memcpy(&encrypted_info, "\x06", sizeof(char));
			break;
		}

		// Cifro tutta la struttura dentro encrypted_info.encrypted
		// inserendo il padding
		tot_len = sizeof(struct_info);
		tot_len/=16;
		tot_len++;
		tot_len*=16;
		pad_len = tot_len - sizeof(struct_info);
		memset(encrypted_info.encrypted, pad_len, tot_len);
		memcpy(encrypted_info.encrypted, &struct_info, sizeof(struct_info));
		aes_set_key( &crypt_ctx, crypt_key, 128);
		aes_cbc_encrypt(&crypt_ctx, iv, encrypted_info.encrypted, encrypted_info.encrypted, tot_len);
	} while(0);

	if(info) 
		hasp_free(info);

	if(handle != HASP_INVALID_HANDLE_VALUE) 
		hasp_logout(handle);

	return encrypted_info;
}


HASPKEY_API BOOL DC(void)
{
	DWORD count;
	BOOL ret_val = FALSE;
	hasp_handle_t handle = HASP_INVALID_HANDLE_VALUE;

	EnterCriticalSection(&dec_critic);
	do {
		if (hasp_login(HASP_DEFAULT_FID, vendor_code, &handle) != HASP_STATUS_OK)
			break;

		if (hasp_read(handle, HASP_FILEID_RW, 0, 4, &count) != HASP_STATUS_OK)
			break;

		if (count == 0) 
			break;
		count--;

		if (hasp_write(handle, HASP_FILEID_RW, 0, 4, &count) != HASP_STATUS_OK)
			break;

		ret_val = TRUE;
	} while(0);

	if (handle != HASP_INVALID_HANDLE_VALUE)
		hasp_logout(handle);
	LeaveCriticalSection(&dec_critic);
	return ret_val;
}
