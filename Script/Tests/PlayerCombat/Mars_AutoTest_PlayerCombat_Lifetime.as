// Destroying the production pawn while it is Downed and its hurtbox is registered tears the receiver down cleanly: the
// player's entity, its zone and the hurtbox probe all go invalid, a sweep where the hurtbox was finds nothing, and the
// Downed lockdown's exit runs against a dying character without an ensure or a script error (either would fail this
// test through the harness's log capture). Isolated origin (-185000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_Lifetime : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-185000.0, 210000.0, 8000.0);

    private FCk_Handle _Hurtbox;
    private FCk_Handle_HitZone _Zone;
    private FVector _HurtboxLocation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step_WaitUntil("the hurtbox probe is in the physics world", n"Check_HurtboxTraceable", k_SlowPolls, 0);
        Add_Step("down the player", n"Step_Down");
        Add_Step_WaitUntil("the player is Downed with movement disabled", n"Check_DownedAndLocked", k_SlowPolls, 0);
        Add_Step("destroy the Downed pawn with its hurtbox registered", n"Step_DestroyPawn");
        Add_Step_WaitUntil("the player's entity, zone and hurtbox are gone", n"Check_AllGone", k_SlowPolls, 0);
        Add_Step("nothing of the receiver is left in the physics world", n"Step_AssertNoProbe");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Down(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetDownedFlag(true);
    }

    UFUNCTION()
    private void Check_DownedAndLocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsInDowned() && Get_MovementMode() == EMovementMode::MOVE_None);
    }

    UFUNCTION()
    private void Step_DestroyPawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Zone = Get_Zone();
        _Hurtbox = Get_Hurtbox();
        Assert_Valid(_Zone, "the zone is live before the destroy");
        Assert_Valid(_Hurtbox, "the hurtbox is registered before the destroy");
        _HurtboxLocation = PawnLocation();

        TearDown();
    }

    UFUNCTION()
    private void Check_AllGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Player) && ck::Is_NOT_Valid(_Zone) && ck::Is_NOT_Valid(_Hurtbox));
    }

    UFUNCTION()
    private void Step_AssertNoProbe(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Settings = FCk_ShapeCast_Settings(
            _HurtboxLocation - FVector(200.0, 0.0, 0.0),
            _HurtboxLocation + FVector(200.0, 0.0, 0.0),
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(5.0f)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        const auto Result = utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);
        Assert_Invalid(Result.Get_HitEntity(), "a sweep where the hurtbox was finds no hurtbox");
    }
}

class AMars_AutoTest_PlayerCombat_Lifetime_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_Lifetime;
}
