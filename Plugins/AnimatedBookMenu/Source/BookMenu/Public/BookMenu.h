// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "UObject/ObjectMacros.h"
#include "Modules/ModuleManager.h"

/**
 * Enumeration used as execution pins on some blueprint nodes 
 */
UENUM(BlueprintType)
enum class EExecResultBookMenu : uint8
{
	Success	 		UMETA(DisplayName = "Success"),
	Failed	 		UMETA(DisplayName = "Failed")
};

//The Book Menu Module
class FBookMenuModule : public IModuleInterface
{
public:

	/** IModuleInterface implementation */
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;
};
