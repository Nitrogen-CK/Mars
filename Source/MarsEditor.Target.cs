// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;
using EpicGames.Core;
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
		// Shared instead when this clone's Project Storage options (UnrealToolbox) ask for it, which builds
		// engine modules into the engine checkout. Same contract as CkPluginsEditor.Target.cs and
		// CkBuildConfig.ApplyProjectPCHOptions: Schema 1, EditorEnvironment exactly "Shared" or "Unique",
		// anything else fails the build instead of silently building Unique; no file means Unique.
		BuildEnvironment = TargetBuildEnvironment.Unique;
		if (ProjectFile != null)
		{
			FileReference OptionsFile = FileReference.Combine(ProjectFile.Directory, "Saved", "UnrealBuildTool", "CkCloneBuildOptions.json");
			if (FileReference.Exists(OptionsFile))
			{
				JsonObject Options = JsonObject.Read(OptionsFile);
				if (Options.GetIntegerField("Schema") != 1)
				{
					throw new BuildException("Unsupported storage options schema: {0}", OptionsFile);
				}
				string Environment = Options.GetStringField("EditorEnvironment");
				if (Environment == "Shared")
				{
					BuildEnvironment = TargetBuildEnvironment.Shared;
				}
				else if (Environment != "Unique")
				{
					throw new BuildException("Invalid EditorEnvironment in {0}", OptionsFile);
				}
			}
		}

		ExtraModuleNames.Add("Mars");
	}
}
