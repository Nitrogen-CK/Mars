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

		// Unique build environment (a project-specific MarsEditor.exe with Build/Windows/Application.ico)
		// unless this clone's UnrealToolbox Project Storage options ask for Shared, which builds engine
		// modules into the engine checkout and launches the engine's UnrealEditor.exe.
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
