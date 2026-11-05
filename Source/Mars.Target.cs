// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using System.Collections.Generic;

public class MarsTarget : TargetRules
{
	public MarsTarget( TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		bWithPushModel = true;
		DefaultBuildSettings = BuildSettingsVersion.Latest;

		// A monolithic Mars with full debug info links a PDB over the linker's default 4 GB limit (LNK1318 LIMIT (12);
		// 5.9 GB on UE 5.8). UBT raises the page size on its own only for monolithic editor targets.
		WindowsPlatform.PdbPageSize = 16384;

		ExtraModuleNames.Add("Mars");
	}
}
