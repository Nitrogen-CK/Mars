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

		ExtraModuleNames.Add("Mars");
	}
}
