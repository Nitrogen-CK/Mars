// UMars_VineProfile.Validate() rejects each bad field with an error that names it (one case per rule), every preset
// filled by utils_vine::Fill_Preset passes, and a request whose worst case breaks a budget (a dense moss patch) is
// rejected naming the knob to turn. Validate() is called directly, so no ensure fires.
class UMars_AutoTest_Vine_ProfileValidateRejectsEachBadRange : UMars_AutoTestRig_Vine
{
    default _Slot = 6;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every preset passes", n"Step_Presets");
        Add_Step("each bad field is named", n"Step_BadFields");
        Add_Step("an over-budget request is rejected", n"Step_Budget");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Presets(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_VinePreset> Presets;
        Presets.Add(EMars_VinePreset::Ivy);
        Presets.Add(EMars_VinePreset::GiantRoot);
        Presets.Add(EMars_VinePreset::ThinRoot);
        Presets.Add(EMars_VinePreset::HangingMoss);
        Presets.Add(EMars_VinePreset::Rootlets);
        Presets.Add(EMars_VinePreset::Cobweb);
        for (auto Preset : Presets)
        {
            const auto Result = Make_Profile(Preset).Validate();
            Assert_True(Result.IsValid(), f"preset {Preset :n} validates ({Result.Get_Error()})");
        }
    }

    private void Expect(UMars_VineProfile InProfile, const FString& InField)
    {
        const auto Result = InProfile.Validate();
        Assert_False(Result.IsValid(), f"a bad {InField} is rejected");
        Assert_True(Result.Get_Error().Contains(InField), f"the error names {InField} ({Result.Get_Error()})");
    }

    UFUNCTION()
    private void Step_BadFields(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto P = Make_Profile(EMars_VinePreset::GiantRoot);
        P.Stem.Meshes.Mesh = nullptr;
        Expect(P, "Stem.Meshes.Mesh");

        P = Make_Profile(EMars_VinePreset::GiantRoot);
        P.Stem.Radius.EndFrac = 0.0f;
        Expect(P, "Stem.Radius.EndFrac");

        P = Make_Profile(EMars_VinePreset::GiantRoot);
        P.Stem.Radius.EndFrac = 1.5f;
        Expect(P, "Stem.Radius.EndFrac");

        P = Make_Profile(EMars_VinePreset::Ivy);
        P.Attach.StepCm = 1.0f;
        Expect(P, "Attach.StepCm");

        P = Make_Profile(EMars_VinePreset::Ivy);
        P.Attach.StepCm = 300.0f;
        Expect(P, "Attach.StepCm");

        P = Make_Profile(EMars_VinePreset::Ivy);
        P.Attach.StandOffCm = 100.0f;
        Expect(P, "Attach.StandOffCm");

        P = Make_Profile(EMars_VinePreset::GiantRoot);
        P.Twist.PitchCm = 0.0f;
        Expect(P, "Twist.PitchCm");

        P = Make_Profile(EMars_VinePreset::Ivy);
        P.Ends.Air.ClearanceCm = FVector2D(200.0, 100.0);
        Expect(P, "Ends.Air.ClearanceCm");

        P = Make_Profile(EMars_VinePreset::GiantRoot);
        P.Ends.Ground.Fingers.Count = FIntPoint(5, 3);
        Expect(P, "Ends.Ground.Fingers.Count");

        P = Make_Profile(EMars_VinePreset::Ivy);
        P.Branches.LengthCm = FVector2D(60.0, 15.0);
        Expect(P, "Branches.LengthCm");

        P = Make_Profile(EMars_VinePreset::HangingMoss);
        P.Strands.Meshes.Reset();
        Expect(P, "Strands.Meshes");
    }

    UFUNCTION()
    private void Step_Budget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FMars_Vine_Request Request;
        Request.Profile = Make_Profile(EMars_VinePreset::HangingMoss);
        Request.Profile.Strands.PerSquareMetre = 500.0f;
        Request.Layout = EMars_VineLayout::Patch;
        Request.Shape.PatchRadiusCm = 300.0f;
        const auto Result = Request.Validate();
        Assert_False(Result.IsValid(), "a dense patch is over its card budget");
        Assert_True(Result.Get_Error().Contains("Strands.PerSquareMetre"), f"the error names the knob ({Result.Get_Error()})");

        Request.Profile.Strands.PerSquareMetre = 6.0f;
        Request.Shape.PatchRadiusCm = 90.0f;
        Assert_True(Request.Validate().IsValid(), "a normal patch is inside its budgets");
    }
}
