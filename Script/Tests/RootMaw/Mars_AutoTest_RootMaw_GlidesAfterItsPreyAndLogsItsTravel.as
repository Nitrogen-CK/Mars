// A hostile target stands 420 uu ahead, inside the Maw's WakeRadius but beyond its bite's reach: the Maw bursts up, goes
// Hunt and glides toward it (no legs: the surface motion carries the root). While it glides the kernel's travel ledger
// follows it: the ground velocity points at the target at a chasing speed, and the distance travelled matches how far
// the root has moved along the ground (what the root trail grows from). It eases to a stop within the bite's reach.
class UMars_AutoTest_RootMaw_GlidesAfterItsPreyAndLogsItsTravel : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-250000.0, 80000.0, 600.0);

    private FVector _HuntStart;
    private float64 _DistanceAtStart = 0.0;
    private float64 _BestHeading = -1.0;
    private float64 _TopSpeed = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        SpawnTarget(InHandle, FVector(420.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("it is up and hunting", n"Check_Hunting", 0, 5.0f);
        Add_Step("note where the hunt starts", n"Step_MarkStart");
        Add_Step_WaitUntil("it glided into the bite's reach", n"Check_InReach", 0, 6.0f);
        Add_Step("the ledger followed the glide", n"Step_AssertTravel");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Hunting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Maw.Get_IsEmerged() && _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Hunt);
    }

    UFUNCTION()
    private void Step_MarkStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HuntStart = _Maw.Get_Location();
        _DistanceAtStart = _Maw.Get_DistanceTravelled();
    }

    UFUNCTION()
    private void Check_InReach(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Velocity = _Maw.Get_GroundVelocity();
        const auto Toward = _Maw.Get_TargetLocation() - _Maw.Get_Location();
        const auto Speed = Velocity.Size();
        if (Speed > 50.0)
        { _BestHeading = Math::Max(_BestHeading, Velocity.GetSafeNormal().DotProduct(FVector(Toward.X, Toward.Y, 0.0).GetSafeNormal())); }

        _TopSpeed = Math::Max(_TopSpeed, Speed);
        const auto Gap = FVector(Toward.X, Toward.Y, 0.0).Size();
        Res.Set(Gap <= _Maw.Get_Spec().Bite.Range && Speed < 5.0);
    }

    UFUNCTION()
    private void Step_AssertTravel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Moved = _Maw.Get_Location() - _HuntStart;
        const auto Along = FVector(Moved.X, Moved.Y, 0.0).Size();
        const auto Logged = _Maw.Get_DistanceTravelled() - _DistanceAtStart;
        Assert_True(Along >= 150.0, f"it glided toward the target ({Along} uu)");
        Assert_True(Math::Abs(Logged - Along) <= Math::Max(5.0, Along * 0.05), f"the ledger's distance ({Logged}) matches the glide ({Along})");
        Assert_True(_BestHeading > 0.95, f"its ground velocity pointed at the target (best cosine {_BestHeading})");
        Assert_True(_TopSpeed > 100.0, f"it glided at a chasing speed (top {_TopSpeed} uu/s)");
    }
}
