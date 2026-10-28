// Copyright 2024 Suricoon. All Rights Reserved.

using UnrealBuildTool;

public class BookMenuEditor : ModuleRules
{
    public BookMenuEditor(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(
            new string[]
            {
                
                "Core", "AssetTools",
            }
        );

        PrivateDependencyModuleNames.AddRange(
            new string[]
            {
                "CoreUObject",
                "UnrealEd",
                "Engine",
                "Slate",
                "SlateCore",
                "BookMenu",
                "Projects",
                "GraphEditor",
                "PlacementMode",
                "EditorWidgets",
                "AssetRegistry",
                "UMG",
                "BlueprintGraph",
                "ToolMenus"
            }
        );
    }
}