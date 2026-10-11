// The player's hurtbox is the movement capsule's shape at every stance, on the production pawn in the lane's listen-server
// world (the receiver's composition and the world's net mode are asserted and logged first): standing, its top is the
// capsule's top and a sweep at standing chest height finds it (and the Probe.Mars.Player body probe, which still exists
// under that name); crouched, its top drops to the crouched capsule's and neither probe reaches chest height. Under a
// ceiling the uncrouch is blocked and the hurtbox stays crouched-size (no standing-height hurtbox floats above the
// crouched body); with the ceiling gone the character stands and both probes grow back to the capsule's top.
// Isolated origin (-210000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-210000.0, 210000.0, 8000.0);

    // Above the crouched capsule's top (crouched half height 52.5 -> 105 above the feet), below the standing one's (150).
    private const float64 k_StandingOnlyHeight = 140.0;
    private const float64 k_CrouchedWaistHeight = 50.0;
    // Between the crouched top (105) and the ceiling's underside (115).
    private const float64 k_UnderCeilingHeight = 111.0;

    private AStaticMeshActor _Ceiling;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step_WaitUntil("the hurtbox probe is in the physics world", n"Check_HurtboxTraceable", k_SlowPolls, 0);
        Add_Step("standing: both capsule probes reach chest height; crouch", n"Step_AssertStandingAndCrouch");
        Add_Step_WaitUntil("the character is crouched", n"Check_Crouched", k_SlowPolls, 0);
        Add_Step_WaitUntil("the capsule and the hurtbox are crouched-size", n"Check_HurtboxCrouched", k_SlowPolls, 0);
        Add_Step("crouched: nothing at standing chest height; put a ceiling overhead and uncrouch", n"Step_AssertCrouchedAndBlockUncrouch");
        // Deliberately a fixed window: a blocked uncrouch has no event to wait on; the positive assertions after it name
        // the crouched shape that must still hold.
        Add_Step_WaitSeconds("let the blocked uncrouch retry", 0.5f);
        Add_Step("the uncrouch stayed blocked and the hurtbox stayed crouched-size; remove the ceiling", n"Step_AssertStillCrouchedAndClear");
        Add_Step_WaitUntil("the character stands and the hurtbox reaches chest height again", n"Check_HurtboxStanding", k_SlowPolls, 0);
        Add_Step("standing again: the Probe.Mars.Player probe reaches chest height too", n"Step_AssertStandingAgain");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private bool Get_HurtboxReaches(float64 InHeightAboveFeet)
    {
        const auto Hurtbox = Get_Hurtbox();
        return ck::IsValid(Hurtbox)
            && SweepAcrossPawn(FeetZ() + InHeightAboveFeet, GameplayTags::Probe_Mars_HitZone).Get_HitEntity() == Hurtbox;
    }

    private FCk_Handle BodyProbeHitAt(float64 InHeightAboveFeet)
    {
        return SweepAcrossPawn(FeetZ() + InHeightAboveFeet, GameplayTags::Probe_Mars_Player).Get_HitEntity();
    }

    UFUNCTION()
    private void Step_AssertStandingAndCrouch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), 75.0, 0.01, "the capsule is standing-size");

        const auto Hurtbox = Get_Hurtbox();
        Assert_Valid(Hurtbox, "the zone has exactly one hurtbox");
        Assert_True(utils_hit_zone::TryGet_Zone(Hurtbox) == Get_Zone(), "the hurtbox links back to the player's zone");
        Assert_True(utils_probe::Get_Name(Hurtbox.As_Probe()) == GameplayTags::Probe_Mars_HitZone, "the hurtbox probe is named Probe.Mars.HitZone");
        Assert_True(Get_HurtboxReaches(k_StandingOnlyHeight), "standing: the hurtbox reaches chest height");
        Assert_True(Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_HitZone), "standing: the hurtbox's top is the capsule's top");

        auto BodyProbe = BodyProbeHitAt(k_StandingOnlyHeight);
        Assert_Valid(BodyProbe, "standing: the Probe.Mars.Player probe reaches chest height");
        if (ck::IsValid(BodyProbe))
        {
            Assert_True(BodyProbe != Hurtbox, "the body probe and the hurtbox are two probes");
            Assert_True(utils_probe::Get_Name(BodyProbe.As_Probe()) == GameplayTags::Probe_Mars_Player, "the body probe keeps its Probe.Mars.Player name");
        }

        _Pawn.Crouch();
    }

    UFUNCTION()
    private void Check_Crouched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pawn.bIsCrouched && Math::IsNearlyEqual(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), 52.5, 0.01));
    }

    UFUNCTION()
    private void Check_HurtboxCrouched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pawn.bIsCrouched
            && Math::IsNearlyEqual(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), 52.5, 0.01)
            && Get_HurtboxReaches(k_StandingOnlyHeight) == false
            && Get_HurtboxReaches(k_CrouchedWaistHeight));
    }

    UFUNCTION()
    private void Step_AssertCrouchedAndBlockUncrouch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HurtboxReaches(k_CrouchedWaistHeight), "crouched: the hurtbox reaches waist height");
        Assert_False(Get_HurtboxReaches(k_StandingOnlyHeight), "crouched: the hurtbox no longer reaches standing chest height");
        Assert_Invalid(BodyProbeHitAt(k_StandingOnlyHeight), "crouched: the body probe no longer reaches standing chest height");
        Assert_False(Get_HurtboxReaches(k_UnderCeilingHeight), "crouched: the hurtbox stops below the crouched capsule's top");
        Assert_True(Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_HitZone), "crouched: the hurtbox's top is the crouched capsule's top");

        // A 20 uu slab whose underside is 115 above the feet: under the standing capsule's top (150), over the crouched one's.
        const auto Feet = FeetZ();
        _Ceiling = SpawnBlock(FVector(PawnLocation().X, PawnLocation().Y, Feet + 125.0), FVector(4.0, 4.0, 0.2));
        _Pawn.UnCrouch();
    }

    UFUNCTION()
    private void Step_AssertStillCrouchedAndClear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Pawn.bIsCrouched, "the ceiling blocked the uncrouch");
        Assert_Equals_Float(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), 52.5, 0.01, "the capsule is still crouched-size");
        Assert_True(Get_HurtboxReaches(k_CrouchedWaistHeight), "blocked: the hurtbox still reaches waist height");
        Assert_False(Get_HurtboxReaches(k_UnderCeilingHeight), "blocked: no hurtbox above the crouched capsule's top");
        Assert_False(Get_HurtboxReaches(k_StandingOnlyHeight), "blocked: no standing-height hurtbox");
        Assert_True(Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_HitZone), "blocked: the hurtbox's top is the crouched capsule's top");

        if (ck::IsValid(_Ceiling))
        { _Ceiling.DestroyActor(); }
    }

    UFUNCTION()
    private void Check_HurtboxStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pawn.bIsCrouched == false && Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_HitZone));
    }

    UFUNCTION()
    private void Step_AssertStandingAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // UnCrouch restores the capsule height of the class default, not the size the pawn was spawned at, so the standing
        // capsule after a crouch is whatever the movement component says; the probes must match that capsule.
        const auto HalfHeight = _Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight();
        ck::Trace(f"[PlayerCombat] standing again: capsule half height {HalfHeight :.2}");
        Assert_True(Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_HitZone),
            f"standing again: the hurtbox's top is the capsule's top (half height {HalfHeight :.2})");
        Assert_True(Get_ProbeTopMatchesCapsule(GameplayTags::Probe_Mars_Player),
            f"standing again: the body probe's top is the capsule's top (half height {HalfHeight :.2})");
    }

    // A sweep 8 below the movement capsule's top finds the probe and one 8 above it does not.
    private bool Get_ProbeTopMatchesCapsule(FGameplayTag InProbeName)
    {
        const auto Top = 2.0 * _Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight();
        return ck::IsValid(SweepAcrossPawn(FeetZ() + Top - 8.0, InProbeName).Get_HitEntity())
            && ck::Is_NOT_Valid(SweepAcrossPawn(FeetZ() + Top + 8.0, InProbeName).Get_HitEntity());
    }
}

class AMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_CrouchAndBlockedUncrouch;
}
