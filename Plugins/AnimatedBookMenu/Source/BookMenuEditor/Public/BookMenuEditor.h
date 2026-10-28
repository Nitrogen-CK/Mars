// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once

#include "CoreMinimal.h"
#include "AssetTypeCategories.h"
#include "Modules/ModuleManager.h"

/**
 * Editor Module which adds functionality to the Unreal Editor so that users can create Book Configuration Assets
 * for easier configuration and usage of the plugin
 */
class IBookMenuEditorModule : public IModuleInterface
{
public:

	//Module Instance
	static inline IBookMenuEditorModule& Get()
	{
		return FModuleManager::LoadModuleChecked<IBookMenuEditorModule>("BookMenuEditor");
	}

	//The Asset Type Category for the Menu
	virtual EAssetTypeCategories::Type GetBookMenuAssetCategory() const = 0;

};


