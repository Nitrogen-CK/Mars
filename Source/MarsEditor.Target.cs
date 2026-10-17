// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using EpicGames.Core;
using System;
using System.Collections.Generic;

public class MarsEditorTarget : TargetRules
{
	public MarsEditorTarget( TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		bWithPushModel = true;
		DefaultBuildSettings = BuildSettingsVersion.Latest;

		// Unique build environment produces a project-specific MarsEditor.exe
		// in $(ProjectDir)/Binaries/Win64/ with Build/Windows/Application.ico embedded
		// by rc.exe. Without this, Launch defaults to the engine's stock UnrealEditor.exe
		// and the project icon never reaches the Windows taskbar.
		// Unique unless this clone's Project Storage options ask for Shared, which builds engine modules into the engine checkout.
		BuildEnvironment = Get_CloneEditorEnvironment(Target.ProjectFile);

		ExtraModuleNames.Add("Mars");
	}

	// Reads the untracked Saved/UnrealBuildTool/CkCloneBuildOptions.json that UnrealToolbox > Project
	// Storage writes ({"EditorEnvironment":"Shared"|"Unique"}); anything missing or unreadable is Unique.
	public static TargetBuildEnvironment Get_CloneEditorEnvironment(FileReference ProjectFile)
	{
		if (ProjectFile == null)
		{
			return TargetBuildEnvironment.Unique;
		}

		FileReference OptionsFile = FileReference.Combine(ProjectFile.Directory, "Saved", "UnrealBuildTool", "CkCloneBuildOptions.json");
		if (!FileReference.Exists(OptionsFile) || !JsonObject.TryRead(OptionsFile, out JsonObject Options))
		{
			return TargetBuildEnvironment.Unique;
		}

		return Options.TryGetStringField("EditorEnvironment", out string Environment)
			&& string.Equals(Environment, "Shared", StringComparison.OrdinalIgnoreCase)
			? TargetBuildEnvironment.Shared
			: TargetBuildEnvironment.Unique;
	}
}
