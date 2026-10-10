// A platter whose root slides at 60 cm/s (a tray in a hand, on its way to a dock) drops nothing: a piece loaded onto it stays
// queued, bodiless and where it was for a whole second. Once the root stops, the drop happens and the piece lands.
class UMars_AutoTest_Platter_AMovingTrayDropsNothing : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -22000.0, -30000.0);
    private const float64 k_Speed = 60.0;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FTransform _PBefore;
    private float64 _MoveStart = 0.0;
    private bool _IsMoving = false;
    private float64 _LoadedAt = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        auto Owner = InHandle;
        utils_timer::Create_Tick(Owner, FCk_Delegate_Timer(this, n"OnMoveTick"));

        Add_Step_WaitUntil("P is Ready", n"Check_Ready");
        Add_Step("start the platter sliding along Y, then load P", n"Step_MoveAndLoad");
        Add_Step_WaitUntil("one second of sliding", n"Check_SecondPassed", 0, 3.0f);
        Add_Step("P is still queued: no drop, no body, not moved", n"Step_AssertQueuedAndStop");
        Add_Step_WaitUntil("P landed once the platter stopped", n"Check_Landed", 0, 5.0f);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("P is frozen on the stopped platter", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    // The root's location this frame: k_Speed along +Y since the start, while moving.
    UFUNCTION()
    private void OnMoveTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_IsMoving == false)
        { return; }

        const auto Elapsed = float64(System::GetGameTimeInSeconds()) - _MoveStart;
        Move_Platter(_Platter, k_Origin + FVector(0.0, k_Speed * Elapsed, 0.0));
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_MoveAndLoad(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _MoveStart = float64(System::GetGameTimeInSeconds());
        _IsMoving = true;
        _PBefore = Get_World(_P);
        Load(_Platter, _P);
        _LoadedAt = float64(System::GetGameTimeInSeconds());
    }

    UFUNCTION()
    private void Check_SecondPassed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(float64(System::GetGameTimeInSeconds()) - _LoadedAt >= 1.0);
    }

    UFUNCTION()
    private void Step_AssertQueuedAndStop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Travelled = Get_PlatterWorld(_Platter).GetLocation().Distance(k_Origin);
        Assert_True(Travelled > 50.0, f"the platter slid ({Travelled} cm)");
        Assert_True(_P.TryGet_Platter() == _Platter, "P was accepted");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 1, "P is still pending");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "nothing landed");
        Assert_False(TryGet_Motion(_P).IsSet(), "P was never dropped: it has no body");
        Assert_True(Get_World(_P).GetLocation().Equals(_PBefore.GetLocation(), 0.01), "P has not moved");

        _IsMoving = false;
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is frozen on the root");
        Assert_True(Get_IsInsideWalls(_Platter, _P), "P lies inside the walls");
    }
}
