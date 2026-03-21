#pragma once

inline bool GameHasUsableLocalProfile(int iPad)
{
#ifdef __ORBIS__
	(void)iPad;
	return true;
#else
	return ProfileManager.IsSignedIn(iPad);
#endif
}

inline bool GameIsSignedInLive(int iPad)
{
#ifdef __ORBIS__
	return GameHasUsableLocalProfile(iPad);
#else
	return ProfileManager.IsSignedInLive(iPad);
#endif
}

inline bool GameAllowedToPlayMultiplayer(int iPad)
{
#ifdef __ORBIS__
	return GameHasUsableLocalProfile(iPad);
#else
	return ProfileManager.AllowedToPlayMultiplayer(iPad);
#endif
}

inline bool GameHasNetworkSubscription(int iPad)
{
#ifdef __ORBIS__
	return GameHasUsableLocalProfile(iPad);
#else
	return ProfileManager.HasPlayStationPlus(iPad);
#endif
}

inline int GameGetNPAvailability(int iPad)
{
#ifdef __ORBIS__
	(void)iPad;
	return 0;
#else
	return ProfileManager.getNPAvailability(iPad);
#endif
}

inline bool GameHasOnlineServices(int iPad)
{
	return GameIsSignedInLive(iPad) && GameAllowedToPlayMultiplayer(iPad);
}

inline wstring GameGetLocalDisplayName(int iPad)
{
	wstring displayName = ProfileManager.GetDisplayName(iPad);
	if (!displayName.empty())
	{
		return displayName;
	}

	return L"Player";
}

inline char *GameGetOnlineName(int iPad)
{
	return ProfileManager.GetGamertag(iPad);
}
