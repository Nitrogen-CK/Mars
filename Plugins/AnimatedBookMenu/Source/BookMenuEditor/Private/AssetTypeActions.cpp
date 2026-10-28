// Copyright 2024 Suricoon. All Rights Reserved.


#include "AssetTypeActions.h"

#include "BookMenuEditor.h"
#include "DataAssets/BookMenuData.h"

FText FBookMenuDataAssetTypeAction::GetName() const
{
	return INVTEXT("Book Menu Data");
}

FColor FBookMenuDataAssetTypeAction::GetTypeColor() const
{
	return FColor::Yellow;
}

UClass* FBookMenuDataAssetTypeAction::GetSupportedClass() const
{
	return UBookMenuData::StaticClass();
}

uint32 FBookMenuDataAssetTypeAction::GetCategories()
{
	return IBookMenuEditorModule::Get().GetBookMenuAssetCategory();
}
