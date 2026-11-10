// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;

public class Mars : ModuleRules
{
    public Mars(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        CkModuleRules.ApplyProjectPCHOptions(this, Target);

        PublicDependencyModuleNames.AddRange(new string[] { "Core", "CoreUObject", "Engine", "InputCore" });

        PrivateDependencyModuleNames.AddRange(new string[] {  });

        if (Target.bBuildEditor)
        {
            PrivateDependencyModuleNames.AddRange(new string[] { "UnrealEd", "Sockets" });

            // The generated net-autotest stubs under Tests/Net/Generated include CkTests/Net/* (WITH_EDITOR && WITH_DEV_AUTOMATION_TESTS).
            // The CkEcs headers those pull in register their AngelScript binds inline, so the stub's object file links
            // against the modules that own the registration machinery and the handle.
            PrivateDependencyModuleNames.AddRange(new string[] { "CkTests", "CkEcs", "CkCore", "AngelscriptCode" });
        }

        SetupIrisSupport(Target, true);

        // Uncomment if you are using Slate UI
        // PrivateDependencyModuleNames.AddRange(new string[] { "Slate", "SlateCore" });

        // Uncomment if you are using online features
        // PrivateDependencyModuleNames.Add("OnlineSubsystem");

        // To include OnlineSubsystemSteam, add it to the plugins section in your uproject file with the Enabled attribute set to true
    }
}
