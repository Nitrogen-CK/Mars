// R14 (flee remains reachable). The den sits inside the flee ring (its mouth 72 cm from the ring point at -X). A loaded thief
// flees for 12 s of its clock (time dilation 4): every flee goal the drain admitted lies at least LoadedPortalKeepOutCm
// (150 cm) from both den portals, inside the encounter bounds, and whenever the navigator holds one of its moves the route
// is the provider's (PathMode Provider, never a straight line).
class UMars_AutoTest_PantryRat_FleeRejectsTheDenMouth : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private const float32 k_Dilation = 4.0f;
    private float32 _OriginalDilation = 1.0f;
    private bool _Watching = false;
    private FCk_Handle_PantryRat _Thief;
    private float32 _StartedAt = 0.0f;
    private int32 _StraightLineFrames = 0;
    private int32 _MovingFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(676000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("watch the flee for 12 s of its clock", n"Step_Start");
        Add_Step_WaitUntil("12 s passed", n"Check_Done", k_LongPolls, 50.0f);
        Add_Step("every flee goal kept out of the den mouth on a provider route", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Watching == false)
        { return; }

        const auto Navigator = _Thief.Get_Navigator();
        if (Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Moving && Navigator.Get_HasPendingRequests() == false)
        {
            ++_MovingFrames;
            if (Navigator.Get_PathMode() != EMars_SurfaceNavigator_PathMode::Provider)
            { ++_StraightLineFrames; }
        }
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Thief = Get_FirstRat();
        _StartedAt = _Thief.Get_Clock();
        _OriginalDilation = Gameplay::GetGlobalTimeDilation();
        Gameplay::SetGlobalTimeDilation(k_Dilation);
        _Watching = true;
    }

    UFUNCTION()
    private void Check_Done(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Thief.Get_Clock() - _StartedAt >= 12.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Gameplay::SetGlobalTimeDilation(_OriginalDilation);
        _Watching = false;

        const auto Goals = _Thief.Get_FleeGoals();
        Assert_True(Goals.Num() >= 2, f"the thief admitted several flee goals ({Goals.Num()})");
        const auto Entry = _Den.Get_PortalWorld(EMars_RatDen_Portal::EntryPortal);
        const auto Exit = _Den.Get_PortalWorld(EMars_RatDen_Portal::ExitPortal);
        const auto KeepOut = float64(_Spec.Routing.LoadedPortalKeepOutCm);
        for (const auto& Goal : Goals)
        {
            Assert_True(utils_pantry_raid::Get_PlanarDistance(Goal, Entry) >= KeepOut && utils_pantry_raid::Get_PlanarDistance(Goal, Exit) >= KeepOut,
                f"flee goal [{Goal.ToString()}] keeps out of the den mouth");
            Assert_True(_Raid.Get_IsInsideBounds(FVector(Goal.X, Goal.Y, _Origin.Z)), f"flee goal [{Goal.ToString()}] is inside the bounds");
        }

        Assert_True(_MovingFrames > 0, "the thief moved");
        Assert_Equals_Int(_StraightLineFrames, 0, "no flee move ever ran as a straight line");
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (_Watching)
        { Gameplay::SetGlobalTimeDilation(_OriginalDilation); }

        Super::DoEndPlay(InHandle);
    }
}
