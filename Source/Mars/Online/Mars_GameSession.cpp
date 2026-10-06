#include "Mars_GameSession.h"

void AMars_GameSession::SetAdmissionOpen(bool bOpen)
{
	bAdmissionOpen = bOpen;
}

bool AMars_GameSession::IsAdmissionOpen() const
{
	return bAdmissionOpen;
}

FString AMars_GameSession::ApproveLogin(const FString& Options)
{
	if (!bAdmissionOpen)
	{
		return TEXT("Camp is departing; joining is closed.");
	}

	return Super::ApproveLogin(Options);
}
