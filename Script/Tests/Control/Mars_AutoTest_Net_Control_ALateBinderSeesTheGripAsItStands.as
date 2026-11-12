// The server grants and releases a stand-in's grip on one lever, and grants it a grip on a second lever, before the
// client's copies bind: the client reads the first Released with an invalid gripper through the getter, the second Gripped
// by the stand-in, and raises no refusal.
// Surface: Ck.Control.Net.AS_Control_ALateBinderSeesTheGripAsItStands
class UCk_AutoTest_Net_Control_ALateBinderSeesTheGripAsItStands : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(134000.0, 0.0, 5000.0);
    private const FVector k_SecondLocation = FVector(134000.0, 400.0, 5000.0);

    private FCk_Handle_Control _Second;
    private int32 _SecondRefusals = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BothFoundAsTheyStand", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The lever at InLocation among this machine's tagged levers; invalid until it composed.
    private FCk_Handle_Control DoFind_LeverAt(FVector InLocation)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLever"))
        {
            auto Control = Candidate.As_Control(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Control))
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Control.As_Transform()).GetLocation();
            if ((Location - InLocation).Size() < 10.0)
            { return Control; }
        }

        return FCk_Handle_Control();
    }

    // Both levers and the stand-in found on this machine; the first time each lever is found its refusals are counted.
    private bool Get_AreBothFound()
    {
        if (ck::Is_NOT_Valid(_Control))
        {
            auto First = DoFind_LeverAt(k_Location);
            if (ck::IsValid(First))
            {
                _Control = First;
                _Control.BindTo_OnGripRefused(FMars_Delegate_Control_OnGripRefused(this, n"OnFirstGripRefused"));
                if (Get_IsServer())
                { Track_ForCleanup(First); }
            }
        }

        if (ck::Is_NOT_Valid(_Second))
        {
            auto Second = DoFind_LeverAt(k_SecondLocation);
            if (ck::IsValid(Second))
            {
                _Second = Second;
                _Second.BindTo_OnGripRefused(FMars_Delegate_Control_OnGripRefused(this, n"OnSecondGripRefused"));
                if (Get_IsServer())
                { Track_ForCleanup(Second); }
            }
        }

        return ck::IsValid(_Control) && ck::IsValid(_Second) && Get_IsStandInFound();
    }

    UFUNCTION()
    private void OnFirstGripRefused(FCk_Handle_Control InControl, FCk_Handle InRefused)
    {
        _GripRefusals.Add(InRefused);
    }

    UFUNCTION()
    private void OnSecondGripRefused(FCk_Handle_Control InControl, FCk_Handle InRefused)
    {
        _SecondRefusals += 1;
    }

    // Client: both copies show the server's state as it stands (the first released after one grip, the second held).
    UFUNCTION()
    private void Is_BothFoundAsTheyStand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_AreBothFound() && _Control.Get_GripSerial() == 1 && _Second.Get_GripSerial() == 1);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALateBinderSeesTheGripAsItStands client: first [{Get_GripText(_Control)}], second [{Get_GripText(_Second)}], refusalsRaised {_GripRefusals.Num()}/{_SecondRefusals}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsGripped() == false && ck::Is_NOT_Valid(_Control.Get_Gripper()),
            f"the first lever reads Released with no gripper (got {Get_WhoText(_Control.Get_Gripper())})");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended, "the first lever's grip was released as Ended");
        Assert_True(_Second.Get_IsGripped() && _Second.Get_Gripper() == _StandIn,
            f"the second lever reads Gripped by the stand-in (got {Get_WhoText(_Second.Get_Gripper())})");
        Assert_True(_GripRefusals.Num() == 0 && _SecondRefusals == 0, f"no refusal was raised (got {_GripRefusals.Num()}, {_SecondRefusals})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        Spawn_ServerLever(k_SecondLocation, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_BothFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BothFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_AreBothFound());
    }

    // Both levers are claimed together; the first is released once its grant shows.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        _Second.Request_Grip(FMars_Request_Control_Grip(_StandIn, EMars_Control_GripVerb::Begin));
        WaitUntil(n"Is_GrippedByStandIn", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitUntil(n"Is_GripReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALateBinderSeesTheGripAsItStands server: first [{Get_GripText(_Control)}], second [{Get_GripText(_Second)}], ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_GripSerial() == 1, "the server released the first lever's one grip");
        Assert_True(_Second.Get_Gripper() == _StandIn, "the stand-in holds the second lever");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
