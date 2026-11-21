// The hand mount's rebind keeps a held lit lantern whole: the unpossessed pawn holds a lantern, lit, on its body's
// grip; once the local player possesses it and the mount moves under the gloves (flip after the mount), for 30 frames
// no scene node under the lantern is deeper than 8, the light sits half the flame over the flame node within 0.1 cm,
// the flame node stands the flame height over the lantern's root within 0.5 cm at the last of them (the bail may swing
// from the flip), and no ensure was raised since the row began (UMars_AutoTestHelper_HeldFlameDepth). Isolated origin
// (-204000, 218000, 8000).
class UMars_AutoTest_FPHands_ARebindKeepsAHeldLitLanternWhole : UMars_AutoTestRig_PlayerHandRebind
{
    default _Origin = FVector(-204000.0, 218000.0, 8000.0);

    private const int32 k_DeepestDepth = 8;
    private const float64 k_LightToleranceCm = 0.1;
    private const float64 k_FlameNodeToleranceCm = 0.5;
    private const int32 k_WatchFrames = 30;
    // About 3 s at a lane's frame rate.
    private const int32 k_RestPolls = 180;

    private UMars_AutoTestHelper_HeldFlameDepth _Watch;
    private int32 _EnsuresAtStart = 0;
    private int32 _WatchedFrames = 0;
    private int32 _RestPolls = 0;
    private float64 _WorstLightError = 0.0;
    private float64 _WorstFlameNodeError = 0.0;
    private float64 _LastFlameNodeError = -1.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _Watch = Cast<UMars_AutoTestHelper_HeldFlameDepth>(NewObject(this, UMars_AutoTestHelper_HeldFlameDepth));
        _Definition = mars_items::Lantern();

        Spawn_PawnAndSlab(InHandle);
        Spawn_Item(_Definition);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the lantern is composed", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step("the pawn picks the lantern up", n"Step_GiveItem");
        Add_Step_WaitUntil("the pawn holds the lantern, settled on the body's hand", n"Check_ItemHeld", k_SlowPolls, 0);
        Add_Step("light it", n"Step_Light");
        Add_Step_WaitUntil("the lantern is lit", n"Check_Lit", k_SlowPolls, 0);
        Add_Step("watch it on the body's grip; possess", n"Step_WatchAndPossess");
        Add_Step_WaitUntil("the mount moves under the gloves' hand node", n"Check_MountOnHandNode", k_SlowPolls, 0);
        Add_Step_WaitUntil("30 frames in the first-person hand", n"Check_Watched", k_SlowPolls, 0);
        Add_Step_WaitUntil("the bail comes to rest (or 3 s pass)", n"Check_BailAtRest", k_SlowPolls, 0);
        Add_Step("the lantern is whole in the first-person hand", n"Step_AssertWhole");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Light(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Flame = _WorldItem.H().As_Flame();
        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    private void Check_Lit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Flame = _WorldItem.H().As_Flame(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(Flame) && Flame.Get_IsLit());
    }

    UFUNCTION()
    private void Step_WatchAndPossess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_MountParent() == Get_BodyGripTransform(), f"unpossessed: the mount rides BodyGrip ({Describe_Mount()})");
        _Watch.Watch(_Pawn, _WorldItem);
        _Watch.Sample();
        PossessPawn();
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Watch.Sample();
        _WatchedFrames += 1;
        _WorstLightError = Math::Max(_WorstLightError, Get_ErrorOrLarge(_Watch.Get_LightErrorCm()));
        _LastFlameNodeError = _Watch.Get_FlameNodeErrorCm();
        _WorstFlameNodeError = Math::Max(_WorstFlameNodeError, Get_ErrorOrLarge(_LastFlameNodeError));
        auto Result = OutResult;
        Result.Set(_WatchedFrames >= k_WatchFrames);
    }

    UFUNCTION()
    private void Check_BailAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Watch.Sample();
        _RestPolls += 1;
        _WorstLightError = Math::Max(_WorstLightError, Get_ErrorOrLarge(_Watch.Get_LightErrorCm()));
        _LastFlameNodeError = _Watch.Get_FlameNodeErrorCm();
        auto Result = OutResult;
        Result.Set(_RestPolls >= k_RestPolls || (_LastFlameNodeError >= 0.0 && _LastFlameNodeError <= k_FlameNodeToleranceCm));
    }

    private float64 Get_ErrorOrLarge(float64 InError) const
    {
        return InError < 0.0 ? 1000000.0 : InError;
    }

    UFUNCTION()
    private void Step_AssertWhole(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        Log(f"[HandMount] ARebindKeepsAHeldLitLanternWhole {_Watch.Describe()} worstLightError={_WorstLightError :.3} "
            + f"worstFlameNodeError={_WorstFlameNodeError :.3} lastFlameNodeError={_LastFlameNodeError :.3} frames={_WatchedFrames} restPolls={_RestPolls} ensures={NewEnsures}");
        Assert_True(_Watch.ParentAtMount == "heldBeforeWatch" && _Watch.FlipFrame >= 0,
            f"the lantern was held on the body before the flip (at the watch [{_Watch.ParentAtMount}], flip frame {_Watch.FlipFrame})");
        Assert_True(_Watch.HeldSamples > 0 && _Watch.Deepest >= 0 && _Watch.Deepest <= k_DeepestDepth,
            f"the deepest scene node under the held lantern is at most {k_DeepestDepth} (deepest {_Watch.Deepest})");
        Assert_True(_WorstLightError <= k_LightToleranceCm,
            f"the light sat half the flame over the flame node every frame (worst {_WorstLightError} cm off)");
        Assert_True(_LastFlameNodeError >= 0.0 && _LastFlameNodeError <= k_FlameNodeToleranceCm,
            f"the flame node stands the flame height over the lantern's root ({_LastFlameNodeError} cm off)");
        Assert_Equals_Int(NewEnsures, 0, "no ensure since the row began");
    }
}

class AMars_AutoTest_FPHands_ARebindKeepsAHeldLitLanternWhole_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_FPHands_ARebindKeepsAHeldLitLanternWhole;
}
