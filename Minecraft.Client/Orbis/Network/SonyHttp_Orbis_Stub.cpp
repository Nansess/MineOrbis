#include "stdafx.h"
#include "Common/Network/Sony/SonyHttp.h"

bool SonyHttp::init()
{
	return true;
}

void SonyHttp::shutdown()
{
}

bool SonyHttp::getDataFromURL(const char* szURL, void** ppOutData, int* pDataSize)
{
	(void)szURL;
	if (ppOutData != NULL)
	{
		*ppOutData = NULL;
	}
	if (pDataSize != NULL)
	{
		*pDataSize = 0;
	}
	return false;
}
