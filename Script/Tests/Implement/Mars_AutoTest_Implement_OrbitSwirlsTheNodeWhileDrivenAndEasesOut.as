// An orbit (Radius 3, Hz 1, EaseSeconds 0.2) shows nothing while Idle; Driven, it eases in to its radius and turns (a
// quarter of a turn in 0.25 s at 1 Hz: two samples that far apart are roughly perpendicular) and the node's offset carries
// it; Idle again, it eases out to the rest location.
class UMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 6.0f;

    private const float32 k_Radius = 3.0f;
    private const FVector k_RestLocation = FVector(0.0, 0.0, 100.0);

    private FVector _FirstSample = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Implement_Spec();
        Spec.Orbit = FMars_Implement_OrbitSpec(k_Radius, 1.0f, 0.2f);
        BuildImplement(InHandle, Spec);

        Add_Step_WaitFrames("the idle implement ticks", 4);
        Add_Step("an idle implement shows no orbit; drive it", n"Step_AssertNoOrbitThenDrive");
        Add_Step_WaitUntil("the orbit eased in to its radius", n"Check_OrbitAtRadius", 0, 0.5f);
        Add_Step("sample the orbit", n"Step_FirstSample");
        Add_Step_WaitSeconds("a quarter of a turn", 0.25f);
        Add_Step("the orbit turned and the node shows it; idle it", n"Step_AssertTurnedThenIdle");
        Add_Step_WaitUntil("the orbit eased out", n"Check_OrbitGone", 0, 0.5f);
        Add_Step_WaitFrames("the last write lands", 3);
        Add_Step("the node is back at its rest location", n"Step_AssertAtRest");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNoOrbitThenDrive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement), "the feature composed");
        Assert_Equals_Float(_Implement.Get_OrbitOffset().Size(), 0.0, 0.0001, "an idle implement does not orbit");
        Assert_Equals_Float((utils_scene_node::Get_Offset(_Node).GetLocation() - k_RestLocation).Size(), 0.0, 0.01,
            "the idle node sits at its rest location");

        Drive();
    }

    UFUNCTION()
    private void Check_OrbitAtRadius(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Implement.Get_OrbitOffset().Size() - k_Radius) <= 0.3);
    }

    UFUNCTION()
    private void Step_FirstSample(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstSample = _Implement.Get_OrbitOffset();
        Assert_Equals_Float(_FirstSample.Z, 0.0, 0.0001, "the orbit stays in the rest frame's XY plane");
    }

    UFUNCTION()
    private void Step_AssertTurnedThenIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Second = _Implement.Get_OrbitOffset();
        Assert_Equals_Float(Second.Size(), k_Radius, 0.3, "the driven orbit holds its radius");

        const auto Dot = _FirstSample.DotProduct(Second) / float64(k_Radius * k_Radius);
        const auto Degrees = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Dot, -1.0, 1.0)));
        ck::Trace(f"[Implement] orbit: {_FirstSample} then {Second} 0.25 s later, {Degrees :.1} degrees apart");
        Assert_True(Dot < 0.3, f"a quarter of a turn later the offset is roughly perpendicular (dot / r^2 {Dot :.3})");

        const auto NodeOffset = utils_scene_node::Get_Offset(_Node).GetLocation() - k_RestLocation;
        Assert_Equals_Float(FVector(NodeOffset.X, NodeOffset.Y, 0.0).Size(), k_Radius, 0.5, "the node's offset carries the orbit");
        Assert_Equals_Float(NodeOffset.Z, 0.0, 0.01, "the orbit does not lift the node");

        _Implement.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Idle));
    }

    UFUNCTION()
    private void Check_OrbitGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_OrbitOffset().Size() < 0.1);
    }

    UFUNCTION()
    private void Step_AssertAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Implement.Get_IsDriven(), "the implement is Idle");
        Assert_Equals_Float(_Implement.Get_OrbitOffset().Size(), 0.0, 0.0001, "the orbit eased out completely");
        Assert_Equals_Float((utils_scene_node::Get_Offset(_Node).GetLocation() - k_RestLocation).Size(), 0.0, 0.01,
            "the node is back at its rest location");
    }
}
