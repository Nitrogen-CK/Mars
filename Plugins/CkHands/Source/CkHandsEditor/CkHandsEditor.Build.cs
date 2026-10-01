using UnrealBuildTool;

public class CkHandsEditor : CkModuleRules
{
    public CkHandsEditor(ReadOnlyTargetRules Target) : base(Target)
    {
        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "UnrealEd",
            "AnimGraph",
            "BlueprintGraph",
            "ControlRig",
            "ControlRigDeveloper",
            "RigVM",
            "RigVMDeveloper",
            "CkCore",
            "CkLog",
            "CkHands"
        });
    }
}
