// Copyright 2024 Suricoon. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "AssetTypeActions_Base.h"
#include "UObject/Object.h"


/**
 * Asset Type Action Class for the Book Menu Plugin
 */
class BOOKMENUEDITOR_API FBookMenuDataAssetTypeAction : public FAssetTypeActions_Base
{
public:
	
	virtual FText GetName() const override;
	virtual FColor GetTypeColor() const override;
	virtual UClass* GetSupportedClass() const override;
	virtual uint32 GetCategories() override;
};
