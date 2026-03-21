#include "stdafx.h"
#include "SonyCommerce_Orbis.h"

static void ForceOfflineFullVersionState()
{
	ProfileManager.SetDebugFullOverride(true);
	ProfileManager.SetFullVersion(true);
	StorageManager.SetSaveDisabled(false);
}

static void RunCommerceCallback(SonyCommerce::CallbackFunc cb, LPVOID lpParam, int err = SCE_OK)
{
	if (cb != NULL)
	{
		cb(lpParam, err);
	}
}

void SonyCommerce_UpgradeTrial()
{
}

void SonyCommerce_Orbis::CreateSession(CallbackFunc cb, LPVOID lpParam)
{
	ForceOfflineFullVersionState();
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::CloseSession()
{
}

void SonyCommerce_Orbis::GetCategoryInfo(CallbackFunc cb, LPVOID lpParam, CategoryInfo *info, const char *categoryId)
{
	(void)categoryId;
	if (info != NULL)
	{
		memset(info, 0, sizeof(*info));
	}
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::GetProductList(CallbackFunc cb, LPVOID lpParam, std::vector<ProductInfo>* productList, const char *categoryId)
{
	(void)categoryId;
	if (productList != NULL)
	{
		productList->clear();
	}
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::GetDetailedProductInfo(CallbackFunc cb, LPVOID lpParam, ProductInfoDetailed* productInfoDetailed, const char *productId, const char *categoryId)
{
	(void)productId;
	(void)categoryId;
	if (productInfoDetailed != NULL)
	{
		memset(productInfoDetailed, 0, sizeof(*productInfoDetailed));
	}
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::AddDetailedProductInfo(CallbackFunc cb, LPVOID lpParam, ProductInfo* productInfo, const char *productId, const char *categoryId)
{
	(void)productId;
	(void)categoryId;
	if (productInfo != NULL)
	{
		productInfo->annotation = 0;
	}
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::Checkout(CallbackFunc cb, LPVOID lpParam, const char* skuID)
{
	(void)skuID;
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::DownloadAlreadyPurchased(CallbackFunc cb, LPVOID lpParam, const char* skuID)
{
	(void)skuID;
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::Checkout_Game(CallbackFunc cb, LPVOID lpParam, const char* skuID)
{
	(void)skuID;
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::DownloadAlreadyPurchased_Game(CallbackFunc cb, LPVOID lpParam, const char* skuID)
{
	(void)skuID;
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::UpgradeTrial(CallbackFunc cb, LPVOID lpParam)
{
	ForceOfflineFullVersionState();
	RunCommerceCallback(cb, lpParam);
}

void SonyCommerce_Orbis::CheckForTrialUpgradeKey()
{
	ForceOfflineFullVersionState();
}

bool SonyCommerce_Orbis::LicenseChecked()
{
	ForceOfflineFullVersionState();
	return true;
}
