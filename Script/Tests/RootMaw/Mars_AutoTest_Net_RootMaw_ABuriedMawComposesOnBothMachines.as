// The server spawns a Root Maw and holds: its copy lies buried with what decides and moves it (surface motion, a state
// machine, a dealer, the targeting and the drive) and no transform interpolation. The client's copy lies buried without
// any of those, follows its root through a transform interpolation, has no authority over its root, and carries the
// monster (body Health 140) and one hurtbox on the body zone, whose address is {its root, 0} and resolves back.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ABuriedMawComposesOnBothMachines
class UCk_AutoTest_Net_RootMaw_ABuriedMawComposesOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(570000.0, 0.0, 5000.0);
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_MawFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HoldSeconds, n"OnServerHeldBuried");
    }

    UFUNCTION()
    private void OnServerHeldBuried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Maw;
        Assert_True(_Maw.Get_IsBuried(), "the server's Maw lies buried");
        Assert_True(ck::IsValid(_Maw.Get_Motion()), "the server's Maw has a surface motion");
        Assert_True(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the server's Maw has a state machine");
        Assert_True(ck::IsValid(_Maw.Get_Fragment(FMars_Fragment_RootMaw).Dealer), "the server's Maw has a dealer");
        Assert_True(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Targeting), "the server's Maw has its targeting");
        Assert_True(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Drive), "the server's Maw has its drive");
        Assert_False(utils_transform_interpolation::Has(Root), "the server's Maw has no transform interpolation");
        Assert_True(Math::IsNearlyEqual(Get_MawBodyDrop(), k_BodyDropBuried, 0.5), "the server's root is 108 above the body node");
        Hold_MawServerRow("ABuriedMawComposesOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Maw;
        Assert_True(_Maw.Get_IsBuried(), "the client's Maw lies buried");
        Assert_False(ck::IsValid(_Maw.Get_Motion()), "the client's Maw has no surface motion");
        Assert_False(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the client's Maw has no state machine");
        Assert_False(ck::IsValid(_Maw.Get_Fragment(FMars_Fragment_RootMaw).Dealer), "the client's Maw has no dealer");
        Assert_False(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Targeting), "the client's Maw has no targeting");
        Assert_False(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Drive), "the client's Maw has no drive");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 140.0f, 0.01f), "the client's body Health reads 140");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 1, "the client's body zone has one hurtbox");

        const auto Address = _Zone.Get_Address();
        Assert_True(Address.Root == Root && Address.Index == 0, "the client's body zone's address is {its root, 0}");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == _Zone, "the client's body zone's address resolves back to it");
        Assert_False(utils_net::Get_HasAuthority(Root), "the client has no authority over its root");
        Assert_True(utils_transform_interpolation::Has(Root), "the client's root has a transform interpolation");
        Assert_True(Math::IsNearlyEqual(Get_MawBodyDrop(), k_BodyDropBuried, 0.5), "the client's root is 108 above the body node");
        Finish_MawRow("ABuriedMawComposesOnBothMachines", "");
    }
}
