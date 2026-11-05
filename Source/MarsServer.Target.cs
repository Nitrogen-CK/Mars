// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using System.Collections.Generic;

[SupportedPlatforms(UnrealPlatformClass.Server)]
public class MarsServerTarget : TargetRules
{
	public MarsServerTarget( TargetInfo Target) : base(Target)
	{
		Type = TargetType.Server;
		bWithPushModel = true;
		DefaultBuildSettings = BuildSettingsVersion.Latest;

		// Same as Mars.Target.cs: a monolithic target with full debug info outgrows the linker's default 4 GB PDB.
		WindowsPlatform.PdbPageSize = 16384;

		ExtraModuleNames.Add("Mars");
	}
}
