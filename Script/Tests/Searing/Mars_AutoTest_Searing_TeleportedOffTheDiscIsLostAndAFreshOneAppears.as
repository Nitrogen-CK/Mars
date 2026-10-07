// A steak teleported beyond the pan (pan-local (PanRadius + 2 HalfSize, 0, 20): outside the lip, over the void) is lost:
// the pan empties, the lost steak lingers and falls, a fresh, different steak appears RespawnSeconds later, and the lost
// one is destroyed after LingerSeconds.
class UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private FCk_Handle _FirstSteak;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the steak landed on the pan", n"Check_OnPan", 0, 3.0f);
        Add_Step("teleport the steak off the disc", n"Step_TeleportOff");
        Add_Step_WaitUntil("the steak was lost", n"Check_Lost1", 0, 1.0f);
        Add_Step("the pan is empty and the lost steak lingers", n"Step_AssertLost");
        Add_Step_WaitUntil("a fresh steak spawned", n"Check_Spawned2", 0, 1.0f);
        Add_Step("the fresh steak is a different entity", n"Step_AssertFreshSteak");
        Add_Step_WaitUntil("the lost steak was destroyed", n"Check_LostDestroyed", 0, 1.5f);
        Add_Step("nothing lingers", n"Step_AssertNothingLingers");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportOff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstSteak = _Searing.Get_Steak();
        Assert_True(ck::IsValid(_FirstSteak), "a steak rests on the pan");

        // On the pan implies the body exists in the simulation; a teleport before that does nothing.
        const auto Body = _Searing.Get_SteakBody();
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the steak's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Location = PanBaseWorld.TransformPosition(FVector(_Spec.Loss.PanRadius + 2.0 * _Spec.Steak.HalfSize, 0.0, 20.0));
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, PanBaseWorld.Rotator()));
    }

    UFUNCTION()
    private void Step_AssertLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phase = _Searing.Get_Phase();
        Assert_True(Phase == EMars_Searing_Phase::NoSteak, f"the pan is empty after the loss (got {Phase :n})");
        Assert_Equals_Int(_Searing.Get_Tally().Losses, 1, "one loss counted");
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 1, "the lost steak lingers");
        Assert_Equals_Int(_Lost.Num(), 1, "OnSteakLost fired once");
        if (_Lost.Num() > 0)
        {
            Assert_True(_Lost[0] == _FirstSteak, "the lost steak is the one that was teleported");
            Assert_True(ck::IsValid(_Lost[0]), "the lost steak is still live while it lingers");
        }
    }

    UFUNCTION()
    private void Step_AssertFreshSteak(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Spawned.Num(), 2, "OnSteakSpawned fired a second time");
        if (_Spawned.Num() == 2)
        {
            Assert_True(_Spawned[1] != _FirstSteak, "the fresh steak is a different entity");
            Assert_True(ck::IsValid(_Spawned[1]), "the fresh steak is live");
        }
    }

    UFUNCTION()
    private void Step_AssertNothingLingers(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Searing.Get_LostSteakCount(), 0, "the lost steak left the list when it was destroyed");
        Assert_Equals_Int(_Lost.Num(), 1, "no second loss");
    }
}

class AMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TeleportedOffTheDiscIsLostAndAFreshOneAppears;
}
