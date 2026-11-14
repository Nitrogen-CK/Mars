// The server spawns a Pickle Mimic and holds: its copy sits disguised with what decides and moves it (surface motion, a
// state machine, a dealer, the targeting and the drive), a Ready gait and no transform interpolation. The client's copy
// sits disguised without any of those but with a Ready gait of its own that trusts at least one contact on the client's
// floor, follows its root through a transform interpolation, has no authority over its root, reads ungrounded with its
// root's up as the surface's, and carries the monster (body Health 120) and one hurtbox on the body zone, whose address
// is {its root, 0} and resolves back.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ADisguisedMimicComposesOnBothMachines
class UCk_AutoTest_Net_PickleMimic_ADisguisedMimicComposesOnBothMachines : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(610000.0, 0.0, 5000.0);
    private const float32 k_HoldSeconds = 4.0f;
    // Long enough for the copy's walker to set its legs up on this machine's floor.
    private const float32 k_ClientSettleSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_MimicFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_HoldSeconds, n"OnServerHeldTucked");
    }

    UFUNCTION()
    private void OnServerHeldTucked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Mimic;
        Assert_True(_Mimic.Get_IsTucked(), "the server's mimic sits tucked");
        Assert_True(ck::IsValid(_Mimic.Get_Motion()), "the server's mimic has a surface motion");
        Assert_True(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the server's mimic has a state machine");
        Assert_True(ck::IsValid(_Mimic.Get_Fragment(FMars_Fragment_PickleMimic).Dealer), "the server's mimic has a dealer");
        Assert_True(_Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Targeting), "the server's mimic has its targeting");
        Assert_True(_Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Drive), "the server's mimic has its drive");
        Assert_True(Get_MimicGaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the server's gait reads Ready");
        Assert_False(utils_transform_interpolation::Has(Root), "the server's mimic has no transform interpolation");
        Assert_True(Math::IsNearlyEqual(Get_MimicBodyDrop(), k_BodyDropTucked, 0.5), "the server's root is 19 above the body node");
        Assert_True(Get_HasMimicLedger(), "the server's mimic has its ledger");
        const auto Ledger = Get_MimicLedger();
        Assert_True(Ledger.Stance == EMars_PickleMimic_Stance::Tucked && Ledger.Gape == 0.0f, "the server's ledger reads Tucked and 0");
        Hold_MimicServerRow("ADisguisedMimicComposesOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Mimic;
        const auto RootUp = _Mimic.Get_RootTransform().GetRotation().GetUpVector();
        Assert_True(_Mimic.Get_IsTucked(), "the client's mimic sits tucked");
        Assert_False(ck::IsValid(_Mimic.Get_Motion()), "the client's mimic has no surface motion");
        Assert_False(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the client's mimic has no state machine");
        Assert_False(ck::IsValid(_Mimic.Get_Fragment(FMars_Fragment_PickleMimic).Dealer), "the client's mimic has no dealer");
        Assert_False(_Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Targeting), "the client's mimic has no targeting");
        Assert_False(_Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Drive), "the client's mimic has no drive");
        Assert_True(Get_MimicGaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_True(Get_MimicTrusted() >= 1, f"the client's gait trusts at least one contact (reads {Get_MimicTrusted()})");
        Assert_False(_Mimic.Get_IsGrounded(), "the client's mimic reads ungrounded without a surface motion");
        Assert_True(_Mimic.Get_SurfaceUp().Equals(RootUp, 0.0001), "the client's surface up is its root's up");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 120.0f, 0.01f), "the client's body Health reads 120");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 1, "the client's body zone has one hurtbox");

        const auto Address = _Zone.Get_Address();
        Assert_True(Address.Root == Root && Address.Index == 0, "the client's body zone's address is {its root, 0}");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == _Zone, "the client's body zone's address resolves back to it");
        Assert_False(utils_net::Get_HasAuthority(Root), "the client has no authority over its root");
        Assert_True(utils_transform_interpolation::Has(Root), "the client's root has a transform interpolation");
        Assert_True(Math::IsNearlyEqual(Get_MimicBodyDrop(), k_BodyDropTucked, 0.5), "the client's root is 19 above the body node");
        Finish_MimicRow("ADisguisedMimicComposesOnBothMachines", "");
    }
}
