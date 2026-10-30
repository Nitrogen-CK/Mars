// Validate() accepts the rig's spec and rejects every rule broken one at a time: a bare default spec (no fish, no nodes),
// a distance range inside out, a zero hook window, a hook tension at or past the snap, an empty table, a table entry with
// no item, a wait range inside out, a NaN reel speed, a missing node. Each rejection names the field it broke.
class UMars_AutoTest_Fishing_SpecValidateRejectsInvalid : UMars_AutoTestRig_Fishing
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildNodes(InHandle);
        Add_Step("validate the rig's spec and the broken ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_SpecWithNodes(InHandle).Validate();
        Assert_True(Good.IsValid(), f"the rig's spec is accepted (error: {Good.Get_Error()})");

        AssertRejected(FMars_Fishing_Spec(), "Fish.Table", "a bare default spec");

        const auto NotANumber = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NotANumber), "the test input is NaN");

        auto InsideOut = Make_SpecWithNodes(InHandle);
        InsideOut.Launch.MinDistanceCm = InsideOut.Launch.MaxDistanceCm + 1.0f;
        AssertRejected(InsideOut, "MinDistanceCm", "a MinDistanceCm over MaxDistanceCm");

        auto NoWindow = Make_SpecWithNodes(InHandle);
        NoWindow.Bite.HookWindowSeconds = 0.0f;
        AssertRejected(NoWindow, "HookWindowSeconds", "a zero HookWindowSeconds");

        auto WaitInsideOut = Make_SpecWithNodes(InHandle);
        WaitInsideOut.Bite.MaxWaitSeconds = WaitInsideOut.Bite.MinWaitSeconds - 0.1f;
        AssertRejected(WaitInsideOut, "MaxWaitSeconds", "a MaxWaitSeconds under MinWaitSeconds");

        auto HookAtSnap = Make_SpecWithNodes(InHandle);
        HookAtSnap.Reel.HookTension = HookAtSnap.Reel.SnapTension;
        AssertRejected(HookAtSnap, "HookTension", "a HookTension at the snap");

        auto NaNReel = Make_SpecWithNodes(InHandle);
        NaNReel.Reel.ReelSpeedCmPerS = NotANumber;
        AssertRejected(NaNReel, "ReelSpeedCmPerS", "a NaN ReelSpeedCmPerS");

        auto NoFish = Make_SpecWithNodes(InHandle);
        NoFish.Fish.Table.Empty();
        AssertRejected(NoFish, "Fish.Table", "an empty table");

        auto NoItem = Make_SpecWithNodes(InHandle);
        NoItem.Fish.Table.Add(FMars_Fishing_FishEntry());
        AssertRejected(NoItem, "Fish.Table[1]", "a table entry with no item");

        auto ZeroWeight = Make_SpecWithNodes(InHandle);
        ZeroWeight.Fish.Table[0].Weight = 0.0f;
        AssertRejected(ZeroWeight, "Weight", "a zero weight");

        auto NoAnchor = Make_SpecWithNodes(InHandle);
        NoAnchor.Setup.Anchor = FCk_Handle_Transform();
        AssertRejected(NoAnchor, "Setup.Anchor", "a missing anchor");

        auto NoArrive = Make_SpecWithNodes(InHandle);
        NoArrive.Presence.ArriveSeconds = 0.0f;
        AssertRejected(NoArrive, "ArriveSeconds", "a zero ArriveSeconds");
    }

    private void AssertRejected(const FMars_Fishing_Spec& InSpec, const FString& InField, const FString& InLabel)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InLabel} is rejected");
        Assert_True(Result.Get_Error().Contains(InField), f"{InLabel} is rejected naming {InField} (error: {Result.Get_Error()})");
    }
}
