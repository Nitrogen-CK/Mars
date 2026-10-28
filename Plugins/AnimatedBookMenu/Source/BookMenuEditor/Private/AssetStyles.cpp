// Copyright 2024 Suricoon. All Rights Reserved.


#include "AssetStyles.h"

#include "Interfaces/IPluginManager.h"
#include "Styling/SlateStyleMacros.h"

FBookMenuAssetStyles::FBookMenuAssetStyles(): FSlateStyleSet("BookMenuEditor")
{
	SetParentStyleName(FAppStyle::GetAppStyleSetName());
	const FString PluginBaseDir = IPluginManager::Get().FindPlugin("BookMenu")->GetBaseDir();

	FSlateStyleSet::SetContentRoot(PluginBaseDir / TEXT("Resources"));
	
	static const FVector2D Icon16 = FVector2D(16.0f, 16.0f);
	static const FVector2D Icon64 = FVector2D(64.0f, 64.0f);

	Set("ClassIcon.BookMenuData", new IMAGE_BRUSH_SVG("Icons/BookMenuIcon_64", Icon16));
	Set("ClassThumbnail.BookMenuData", new IMAGE_BRUSH_SVG("Icons/BookMenuIcon_64", Icon64));
}

FBookMenuAssetStyles::~FBookMenuAssetStyles()
{
}
