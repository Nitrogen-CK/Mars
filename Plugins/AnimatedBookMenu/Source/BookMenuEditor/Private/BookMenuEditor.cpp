// Copyright 2024 Suricoon. All Rights Reserved.

#include "BookMenuEditor.h"

#include "AssetStyles.h"
#include "AssetToolsModule.h"
#include "AssetTypeActions.h"
#include "AssetTypeCategories.h"
#include "IAssetTools.h"
#include "IAssetTypeActions.h"
#include "Styling/SlateStyleRegistry.h"

#define LOCTEXT_NAMESPACE "FBookMenuEditorModule"

class FBookMenuEditorModule : public IBookMenuEditorModule
{
public:

	EAssetTypeCategories::Type BookMenuAssetCategory;
	TArray<TSharedPtr<IAssetTypeActions>> CreatedAssetTypeActions;
	TSharedPtr<FSlateStyleSet> StyleSet;
	
	virtual void StartupModule() override;
	virtual void ShutdownModule() override;

	void RegisterAssetTypeAction(IAssetTools& AssetTools, TSharedRef<IAssetTypeActions> Action);

	virtual EAssetTypeCategories::Type GetBookMenuAssetCategory() const override
	{
		return BookMenuAssetCategory;
	}
	
};

void FBookMenuEditorModule::StartupModule()
{
	IAssetTools& AssetTools = FModuleManager::LoadModuleChecked<FAssetToolsModule>("AssetTools").Get();
	BookMenuAssetCategory = AssetTools.RegisterAdvancedAssetCategory(
		FName(TEXT("BookMenu")),
		LOCTEXT("BookMenuCategory", "Book Menu"));

	RegisterAssetTypeAction(AssetTools, MakeShareable(new FBookMenuDataAssetTypeAction()));

	//Register Style Set
	StyleSet = MakeShared<FBookMenuAssetStyles>();
	FSlateStyleRegistry::RegisterSlateStyle(*StyleSet.Get());
}

void FBookMenuEditorModule::ShutdownModule()
{
	if (FModuleManager::Get().IsModuleLoaded("AssetTools"))
	{
		IAssetTools& AssetTools = FModuleManager::GetModuleChecked<FAssetToolsModule>("AssetTools").Get();
		for (int32 Index = 0; Index < CreatedAssetTypeActions.Num(); ++Index)
		{
			AssetTools.UnregisterAssetTypeActions(CreatedAssetTypeActions[Index].ToSharedRef());
		}
	}
	CreatedAssetTypeActions.Empty();

	if (StyleSet.IsValid())
	{
		FSlateStyleRegistry::UnRegisterSlateStyle(*StyleSet.Get());
	}
}

void FBookMenuEditorModule::RegisterAssetTypeAction(IAssetTools& AssetTools, TSharedRef<IAssetTypeActions> Action)
{
	AssetTools.RegisterAssetTypeActions(Action);
	CreatedAssetTypeActions.Add(Action);
}

#undef LOCTEXT_NAMESPACE
    
IMPLEMENT_MODULE(FBookMenuEditorModule, BookMenuEditor)