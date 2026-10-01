using UnrealBuildTool;

public class CkHands : CkModuleRules
{
    public CkHands(ReadOnlyTargetRules Target) : base(Target)
    {
        PublicDependencyModuleNames.AddRange(new string[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "AnimGraphRuntime",
            "ControlRig",
            "RigVM",
            "CkCore",
            "CkLog"
        });

        PrivateDependencyModuleNames.AddRange(new string[]
        {
            "GeometryCore"
        });
    }
}
