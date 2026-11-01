// A hostile target stands 390 uu ahead (just inside WakeRadius): the mimic wakes and chases it on its four floating feet.
// While it walks the first 200 uu: the root rides Clearance over the floor (within 5 uu), every foot lifts off the floor
// (over 5 uu) and lands on it again (planted within 3 uu of it), and the feet swing in diagonal pairs: frames with a
// diagonal pair (front-right with back-left, front-left with back-right) both in the air outnumber frames with a side or an
// end pair both in the air by at least 3 to 1.
class UMars_AutoTest_PickleMimic_TrotsOnDiagonalPairs : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 70000.0, 600.0);

    private const float64 k_WalkDistance = 200.0;

    private FVector _Start;
    private float64 _WorstHeight = 0.0;
    private TArray<float64> _MaxLift;
    private float64 _WorstPlanted = 0.0;
    private int32 _DiagonalFrames = 0;
    private int32 _OtherFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        SpawnTarget(InHandle, FVector(390.0, 0.0, 0.0));
        for (int32 Index = 0; Index < utils_pickle_mimic::Get_LegCount(); ++Index)
        { _MaxLift.Add(0.0); }

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the mimic stands and hunts", n"Check_Hunting", 0, 6.0f);
        Add_Step("start recording", n"Step_StartRecording");
        Add_Step_WaitUntil("200 uu walked", n"Check_Walked", 0, 6.0f);
        Add_Step("it trotted", n"Step_AssertTrotted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Hunting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Hunt);
    }

    UFUNCTION()
    private void Step_StartRecording(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = _Mimic.Get_Location();
    }

    UFUNCTION()
    private void Check_Walked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Here = _Mimic.Get_Location();
        _WorstHeight = Math::Max(_WorstHeight, Math::Abs(Here.Z - _Origin.Z - utils_pickle_mimic::Clearance));

        const auto Feet = _Mimic.Get_Feet();
        auto Swinging = TArray<bool>();
        for (int32 Index = 0; Index < Feet.Num(); ++Index)
        {
            const auto Lift = Feet[Index].Location.Z - _Origin.Z;
            _MaxLift[Index] = Math::Max(_MaxLift[Index], Lift);
            if (Feet[Index].Planted)
            { _WorstPlanted = Math::Max(_WorstPlanted, Math::Abs(Lift)); }

            Swinging.Add(Feet[Index].Planted == false);
        }

        // Legs: 0 front-right, 1 front-left, 2 back-right, 3 back-left.
        if ((Swinging[0] && Swinging[3]) || (Swinging[1] && Swinging[2]))
        { ++_DiagonalFrames; }

        if ((Swinging[0] && Swinging[1]) || (Swinging[2] && Swinging[3]) || (Swinging[0] && Swinging[2]) || (Swinging[1] && Swinging[3]))
        { ++_OtherFrames; }

        Res.Set(FVector(Here.X - _Start.X, Here.Y - _Start.Y, 0.0).Size() >= k_WalkDistance);
    }

    UFUNCTION()
    private void Step_AssertTrotted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WorstHeight <= 5.0, f"the root rode Clearance over the floor within 5 uu (worst {_WorstHeight})");
        for (int32 Index = 0; Index < _MaxLift.Num(); ++Index)
        { Assert_True(_MaxLift[Index] > 5.0, f"foot {Index} lifted off the floor (highest {_MaxLift[Index]} uu)"); }

        Assert_True(_WorstPlanted <= 3.0, f"planted feet stood on the floor within 3 uu (worst {_WorstPlanted})");
        Assert_True(_DiagonalFrames > 0 && _DiagonalFrames >= 3 * _OtherFrames,
            f"the feet swung in diagonal pairs ({_DiagonalFrames} diagonal frames, {_OtherFrames} side or end frames)");
    }
}
