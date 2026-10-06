#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameSession.h"
#include "Mars_GameSession.generated.h"

UCLASS()
class MARS_API AMars_GameSession : public AGameSession
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "Mars|Camp")
	void SetAdmissionOpen(bool bOpen);

	UFUNCTION(BlueprintPure, Category = "Mars|Camp")
	bool IsAdmissionOpen() const;

	virtual FString ApproveLogin(const FString& Options) override;

private:
	bool bAdmissionOpen = true;
};
