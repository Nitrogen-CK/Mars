// The pantry rat's two rat-local looks (Script/ECS/PantryRat/Mars_PantryRat_Look_Assets.as) have generated masters at the
// path each look definition names (_GeneratedPackageRoot + /M_CkUsf_Look_ + _LookName, read through the accessors), both
// are Masked (the dither needs OpacityMask), and a MID made from each exposes FadeAlpha at its 1.0 default (a missing
// parameter would read 0). Fails until the editor step has run Ck_Usf_GenerateLooks MarsPantryRatSurface /
// MarsPantryRatEyePlate / MarsPantryRatEyePlateLit (Phase 7: Look_EyePlate() is the Lit one the R02 EyePatch slot wears).
// Reads assets only; nothing is placed.
//
// The masters are loaded by path, not through utils_usf::Get_LookMasterMaterial: in the headless -nullrhi test editor no
// material shader is compiled, so that function (CkUsf_Utils.cpp:44-52) logs "has shader compile errors (or is still
// compiling)" for every CkUsf master (MarsImageDecal and MarsEyePlate included - the reason of the two Eyes known reds).
// That is a renderer check this test cannot make headless; the compile proof for these masters is the live editor's.
class UMars_AutoTest_PantryRat_LookMastersResolve : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the surface master resolves and is Masked", n"Step_AssertSurfaceMaster");
        Add_Step("the eye-plate master resolves and is Masked", n"Step_AssertEyePlateMaster");
        Add_Step("a MID of each look exposes FadeAlpha = 1", n"Step_AssertMidsExposeFadeAlpha");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertSurfaceMaster(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertMasked(utils_pantry_rat_look::Look_Surface());
    }

    UFUNCTION()
    private void Step_AssertEyePlateMaster(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertMasked(utils_pantry_rat_look::Look_EyePlate());
    }

    UFUNCTION()
    private void Step_AssertMidsExposeFadeAlpha(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Mesh = Cast<USkeletalMesh>(LoadObject(this,
            "/Game/ArtCandidates/PantryRat/R02/Meshes/PantryRat_R02_Mars_SK.PantryRat_R02_Mars_SK"));
        if (ck::Is_NOT_Valid(Mesh))
        {
            FinishFailure("PantryRat_R02_Mars_SK does not load (a slot host for the MIDs)");
            return;
        }

        auto Comp = Cast<USkeletalMeshComponent>(NewObject(this, USkeletalMeshComponent));
        Comp.SetSkeletalMeshAsset(Mesh);

        // Phase 7: the R02 EyePatch slot (5) wears the Lit eye-plate master as saved.
        auto Slot5 = Comp.GetMaterial(5);
        Assert_True(ck::IsValid(Slot5) && Slot5.GetPathName() == MasterPath(utils_pantry_rat_look::Look_EyePlate()),
            f"the EyePatch slot wears [{MasterPath(utils_pantry_rat_look::Look_EyePlate())}]");

        AssertFadeAlpha(Comp, 0, utils_pantry_rat_look::Look_Surface());
        AssertFadeAlpha(Comp, 5, utils_pantry_rat_look::Look_EyePlate());
        AssertMasked(utils_pantry_rat_look::Look_EyePlateUnlit());
    }

    private FString MasterPath(UCkUsf_LookDefinition InLook) const
    {
        const auto AssetName = f"M_CkUsf_Look_{InLook._LookName}";
        return f"{InLook._GeneratedPackageRoot}/{AssetName}.{AssetName}";
    }

    private UMaterialInterface LoadMaster(UCkUsf_LookDefinition InLook)
    {
        return Cast<UMaterialInterface>(LoadObject(this, MasterPath(InLook)));
    }

    private void AssertMasked(UCkUsf_LookDefinition InLook)
    {
        auto Master = LoadMaster(InLook);
        if (ck::Is_NOT_Valid(Master))
        {
            FinishFailure(f"no generated master at [{MasterPath(InLook)}]; run Ck_Usf_GenerateLooks {InLook._LookName} in the editor");
            return;
        }

        Assert_True(Master.GetBlendMode() == EBlendMode::BLEND_Masked, f"{InLook._LookName} master blend mode is Masked");
    }

    private void AssertFadeAlpha(USkeletalMeshComponent InComp, int32 InSlot, UCkUsf_LookDefinition InLook)
    {
        auto Master = LoadMaster(InLook);
        if (ck::Is_NOT_Valid(Master))
        {
            FinishFailure(f"no generated master at [{MasterPath(InLook)}]");
            return;
        }

        auto Mid = InComp.CreateDynamicMaterialInstance(InSlot, Master);
        if (ck::Is_NOT_Valid(Mid))
        {
            FinishFailure(f"no MID of {InLook._LookName}");
            return;
        }

        Assert_True(Math::IsNearlyEqual(Mid.GetScalarParameterValue(n"FadeAlpha"), 1.0, 1e-4),
            f"{InLook._LookName} MID reads FadeAlpha at its 1.0 default");

#if EDITOR
        auto Names = TArray<FName>();
        MaterialEditing::GetScalarParameterNames(Mid, Names);
        Assert_True(Names.Contains(n"FadeAlpha"), f"{InLook._LookName} MID lists the FadeAlpha scalar parameter");
#endif

        if (InLook == utils_pantry_rat_look::Look_EyePlate())
        {
            const auto Patch = Mid.GetVectorParameterValue(n"PatchColor");
            Assert_True(Math::IsNearlyEqual(Patch.R, 0.1022, 1e-3) && Math::IsNearlyEqual(Patch.G, 0.0497, 1e-3)
                && Math::IsNearlyEqual(Patch.B, 0.0742, 1e-3), f"{InLook._LookName} MID reads PatchColor #5A3F4D (linear)");
        }
    }
}
