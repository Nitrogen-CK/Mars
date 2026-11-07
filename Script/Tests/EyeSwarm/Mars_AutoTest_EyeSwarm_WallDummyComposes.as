// A spawned eye wall fills its eyeball ISM and its lid ISM with the same number of eyes (its whole grid), index-paired:
// each lid instance has its eyeball's centre and rotation and the same Phase and Variant (read from the wall's mirror;
// script cannot read per-instance data back), all in 0..1. A focus override writes FocusOverride xyz and
// FocusOverrideWeight into both ISMs' custom primitive data, and clearing it zeroes the weight. Passes on the fallbacks:
// engine spheres stand in for the unimported meshes and a headless boot asks for no look. Isolated Z band: -86000.
class UMars_AutoTest_EyeSwarm_WallDummyComposes : UCk_AutoTest_Base
{
    private const FVector FocusPoint = FVector(250.0, -40.0, -85900.0);
    private const float32 FocusWeight = 0.75f;

    private FCk_Handle _DummyEntity;
    private UMars_EyeWallDummy_EntityScript _Dummy;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_EyeWallDummy_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -86000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_EyeWallDummy_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnDummyConstructed"));

        Add_Step_WaitUntil("the wall is constructed", n"Check_Constructed");
        Add_Step_WaitUntil("both instancers exist and are filled", n"Check_Filled");
        Add_Step("both ISMs hold the whole grid", n"Step_AssertCounts");
        Add_Step("index-paired instances share centre, rotation, Phase and Variant", n"Step_AssertPairs");
        Add_Step("a focus override writes both ISMs' custom primitive data", n"Step_AssertFocusOverride");
        Add_Step("clearing the override zeroes the weight on both", n"Step_AssertFocusCleared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDummyConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _DummyEntity = InEntityScriptHandle;
        _Dummy = Cast<UMars_EyeWallDummy_EntityScript>(utils_entity_script::TryGet_EntityScript(_DummyEntity));
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Dummy));
    }

    UFUNCTION()
    private void Check_Filled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Dummy.Get_IsFilled());
    }

    UFUNCTION()
    private void Step_AssertCounts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Instancers = _Dummy.Get_Instancers();
        if (ck::Is_NOT_Valid(Instancers.Eyeballs) || ck::Is_NOT_Valid(Instancers.Eyelids))
        {
            FinishFailure("the wall has no eyeball or lid instancer");
            return;
        }

        const auto NumEyeballs = Instancers.Eyeballs.GetInstanceCount();
        Assert_True(NumEyeballs > 0, "the eyeball ISM has instances");
        Assert_Equals_Int(Instancers.Eyelids.GetInstanceCount(), NumEyeballs, "the lid ISM has one instance per eyeball");
        Assert_Equals_Int(NumEyeballs, _Dummy.Get_NumEyes(), "every eye of the grid is an instance");
    }

    UFUNCTION()
    private void Step_AssertPairs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Instancers = _Dummy.Get_Instancers();
        const int32 NumEyes = Math::Min(Instancers.Eyeballs.GetInstanceCount(), Instancers.Eyelids.GetInstanceCount());
        for (int32 Index = 0; Index < NumEyes; ++Index)
        {
            FTransform Eyeball;
            FTransform Lid;
            Instancers.Eyeballs.GetInstanceTransform(Index, Eyeball, false);
            Instancers.Eyelids.GetInstanceTransform(Index, Lid, false);

            Assert_True(Eyeball.GetLocation().Equals(Lid.GetLocation(), 0.01),
                f"eye {Index}: the lid's centre [{Lid.GetLocation().ToString()}] is the eyeball's [{Eyeball.GetLocation().ToString()}]");
            Assert_True(Eyeball.GetRotation().GetForwardVector().Equals(Lid.GetRotation().GetForwardVector(), 0.001)
                    && Eyeball.GetRotation().GetUpVector().Equals(Lid.GetRotation().GetUpVector(), 0.001),
                f"eye {Index}: the lid has the eyeball's rotation");

            AssertPairedFloat(Instancers, Index, constants_eye_swarm::k_Slot_Phase);
            AssertPairedFloat(Instancers, Index, constants_eye_swarm::k_Slot_Variant);
        }
    }

    UFUNCTION()
    private void Step_AssertFocusOverride(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dummy.Request_FocusOverride(FocusPoint, FocusWeight);

        const auto Last = _Dummy.Get_LastFocusOverride();
        Assert_True(Last.Point.Equals(FocusPoint, 0.01), f"the last focus override point [{Last.Point.ToString()}]");
        Assert_Equals_Float(Last.Weight, FocusWeight, 0.0001, "the last focus override weight");

        AssertFocusCpd(_Dummy.Get_EyeballPart(), FocusWeight);
        AssertFocusCpd(_Dummy.Get_EyelidPart(), FocusWeight);
    }

    UFUNCTION()
    private void Step_AssertFocusCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dummy.Clear_FocusOverride();

        Assert_Equals_Float(_Dummy.Get_LastFocusOverride().Weight, 0.0, 0.0001, "the cleared focus override weight");
        AssertCpd(_Dummy.Get_EyeballPart(), constants_eye_swarm::k_Cpd_FocusOverrideWeight, 0.0f);
        AssertCpd(_Dummy.Get_EyelidPart(), constants_eye_swarm::k_Cpd_FocusOverrideWeight, 0.0f);
    }

    // Both mirrors hold the same value for InSlot of instance InIndex, and it is in 0..1.
    private void AssertPairedFloat(const FMars_EyeSwarm_Instancers& InInstancers, int32 InIndex, int32 InSlot)
    {
        const auto OnEyeball = utils_eye_swarm::Get_WrittenFloat(InInstancers.EyeballData, InIndex, InSlot);
        const auto OnLid = utils_eye_swarm::Get_WrittenFloat(InInstancers.EyelidData, InIndex, InSlot);
        Assert_True(OnEyeball >= 0.0f && OnEyeball <= 1.0f, f"eye {InIndex} slot {InSlot}: the eyeball's value [{OnEyeball}] is written and in 0..1");
        Assert_True(Math::Abs(OnEyeball - OnLid) < 0.00001f, f"eye {InIndex} slot {InSlot}: the lid's value [{OnLid}] is the eyeball's [{OnEyeball}]");
    }

    private void AssertFocusCpd(const FCk_Handle_UnrealComponent& InPart, float32 InWeight)
    {
        const auto Index = constants_eye_swarm::k_Cpd_FocusOverride;
        AssertCpd(InPart, Index, float32(FocusPoint.X));
        AssertCpd(InPart, Index + 1, float32(FocusPoint.Y));
        AssertCpd(InPart, Index + 2, float32(FocusPoint.Z));
        AssertCpd(InPart, constants_eye_swarm::k_Cpd_FocusOverrideWeight, InWeight);
    }

    private void AssertCpd(const FCk_Handle_UnrealComponent& InPart, int32 InIndex, float32 InExpected)
    {
        if (ck::Is_NOT_Valid(InPart))
        {
            FinishFailure("the wall is missing an instancer");
            return;
        }

        const auto Actual = utils_unreal_component::Get_CustomPrimitiveDataFloat(InPart, InIndex);
        Assert_True(Math::Abs(Actual - InExpected) < 0.01f,
            f"[{InPart.ToString()}] custom primitive data {InIndex} is [{InExpected}] (got [{Actual}])");
    }
}
