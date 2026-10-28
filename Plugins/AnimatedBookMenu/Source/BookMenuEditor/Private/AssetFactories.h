// Copyright 2024 Suricoon. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Factories/Factory.h"
#include "AssetFactories.generated.h"

/**
 * Factory Class to create new Book Data Objects
 */
UCLASS()
class BOOKMENUEDITOR_API UBookMenuDataFactory : public UFactory
{
	GENERATED_BODY()

public:

	//Set Defaults
	UBookMenuDataFactory();

	//Factory Interface
	virtual UObject* FactoryCreateNew(UClass* Class, UObject* InParent, FName Name, EObjectFlags Flags, UObject* Context, FFeedbackContext* Warn) override;
	
};
