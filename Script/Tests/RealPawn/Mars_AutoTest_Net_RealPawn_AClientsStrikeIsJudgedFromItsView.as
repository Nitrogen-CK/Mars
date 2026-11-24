// A client in the production pawn holds a cleaver and claims two blows on a combat target, through the Strike cue as its
// strike task's sweep would. The authority judges reach from the striker's view, never from its copy of the hand (the
// body's hand there): the server stands the target on the line from its copy of the view through its copy of the hand,
// k_PastTheHandCm short of the reach limit (Reach + Radius + k_StrikeReachSlack) beyond the hand, so the target is in
// reach from the hand and out of it from the view. The first claim lies k_InsideTheLimitCm inside the limit from the
// client's view along that line and is applied; the second is the target's root and is refused OutOfReach: the server
// applies exactly one strike. Both machines log the view-to-claim and hand-to-claim distances.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsStrikeIsJudgedFromItsView
class UCk_AutoTest_Net_RealPawn_AClientsStrikeIsJudgedFromItsView : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(938000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsStrikeIsJudgedFromItsView";
    private const float64 k_PastTheHandCm = 30.0;
    private const float64 k_InsideTheLimitCm = 50.0;
    // The view must be this much farther from the hand than k_PastTheHandCm, or the target is in reach from both.
    private const float64 k_MinViewToHandMarginCm = 15.0;
    private const float64 k_NearTargetCm = 800.0;
    private const float32 k_HoldSettleSeconds = 1.0f;
    private const float32 k_ClaimSpacingSeconds = 0.6f;
    private const float32 k_WatchSeconds = 7.0f;

    private FVector _ServerTargetAt = FVector::ZeroVector;
    private FString _ServerGeometry;

    private FCk_Handle_WorldItem _Cleaver;
    private FCk_Handle _Target;
    private FVector _ClaimAt = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerJoltFloor(InHandle);
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    // Reach + Radius + k_StrikeReachSlack of the held cleaver; -1 without one.
    private float64 Get_ReachLimit()
    {
        const auto Item = Get_HeldItem().Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_Strike() == false)
        { return -1.0; }

        const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
        return Strike.Reach + Strike.Radius + constants_held_item_use::k_StrikeReachSlack;
    }

    private FVector Get_ViewLocation()
    {
        return utils_held_item_use::Get_ViewTransform(_Player).GetLocation();
    }

    private FVector Get_HandLocation()
    {
        return Get_RootLocation(Get_HeldItem().Get_HandAttachPoint());
    }

    // This machine's distances to InAt: from the view (what the authority measures) and from the hand (what it used to).
    private FString Describe_From(FVector InAt)
    {
        return f"viewToClaim={(InAt - Get_ViewLocation()).Size() :.1} handToClaim={(InAt - Get_HandLocation()).Size() :.1} limit={Get_ReachLimit() :.1}";
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        Spawn_ServerWorldItem(mars_items::Cleaver(), _Base + k_ItemFromBase);
        Mark_Deadline(14.0);
        WaitUntil(n"Is_ServerHoldsTheCleaver", n"OnServerHoldsTheCleaver", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldsTheCleaver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsHolding(mars_items::Cleaver()));
    }

    UFUNCTION()
    private void OnServerHoldsTheCleaver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsHolding(mars_items::Cleaver()) == false)
        { FinishFailure("the server's copy of the client's HeldItem never held the cleaver"); return; }

        WaitSeconds(k_HoldSettleSeconds, n"OnServerHoldSettled");
    }

    // The target on the line from the server's view through its hand, k_PastTheHandCm short of the limit past the hand.
    UFUNCTION()
    private void OnServerHoldSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto View = Get_ViewLocation();
        const auto Hand = Get_HandLocation();
        const auto Limit = Get_ReachLimit();
        const auto ViewToHand = (Hand - View).Size();
        _ServerGeometry = f"view={View} hand={Hand} viewToHand={ViewToHand :.1} limit={Limit :.1}";
        if (ViewToHand < k_PastTheHandCm + k_MinViewToHandMarginCm)
        {
            Log_RealPawnRow(k_Row, _ServerGeometry);
            FinishFailure(f"the server's copy of the hand is only {ViewToHand :.1} cm from its view: no target is in reach from one and not the other");
            return;
        }

        _ServerTargetAt = Hand + (Hand - View).GetSafeNormal() * (Limit - k_PastTheHandCm);
        auto Params = FMars_NetCombat_Target_SpawnParams(FTransform(FRotator::ZeroRotator, _ServerTargetAt), 100.0f);
        Params.Team = ECk_Team_ID::Two;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Target_EntityScript, Params);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Find_Target();
        if (ck::IsValid(_Target))
        { Track_ForCleanup(_Target); }

        const auto Tally = _Player.As_HeldItemUse().Get_StrikeTally();
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        // The first claim, as the client places it from its own view (the server's stands where the client's does).
        const auto View = Get_ViewLocation();
        const auto FirstClaim = View + (_ServerTargetAt - View).GetSafeNormal() * (Get_ReachLimit() - k_InsideTheLimitCm);
        Log_RealPawnRow(k_Row, f"{_ServerGeometry} tally=[applied {Tally.Applied} refused {Tally.Refused} last {Refusal}] "
            + f"first=[{Describe_From(FirstClaim)}] second=[{Describe_From(_ServerTargetAt)}]");
        Assert_Equals_Int(Tally.Applied, 1, "the server applied exactly one of the client's two claims");
        Assert_Equals_Int(Tally.Refused, 1, "the server refused the other");
        Assert_True(Tally.LastRefusal.IsSet() && Tally.LastRefusal.GetValue() == EMars_HeldItemUse_StrikeRefusal::OutOfReach,
            f"the refused claim was out of reach from the client's view (last refusal {Refusal}; {Describe_From(_ServerTargetAt)})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientCleaverFound", n"OnClientCleaverFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCleaverFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Cleaver = Find_WorldItemNear(mars_items::Cleaver(), _Base + k_ItemFromBase, 150.0);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || ck::IsValid(_Cleaver));
    }

    UFUNCTION()
    private void OnClientCleaverFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Cleaver))
        { FinishFailure("the client never saw the cleaver the server spawned in front of its pawn"); return; }

        utils_cue_generic::Request_ExecuteCue(_Cleaver, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(16.0);
        WaitUntil(n"Is_ClientArmedWithATarget", n"OnClientArmedWithATarget", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientArmedWithATarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Find_Target();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Cleaver()) && ck::IsValid(_Target)));
    }

    UFUNCTION()
    private void OnClientArmedWithATarget(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsHolding(mars_items::Cleaver()) == false || ck::Is_NOT_Valid(_Target))
        {
            Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Cleaver())} target={ck::IsValid(_Target)}");
            FinishFailure("the client never held the cleaver with the server's target in sight");
            return;
        }

        const auto View = Get_ViewLocation();
        const auto TargetAt = Get_RootLocation(_Target);
        _ClaimAt = View + (TargetAt - View).GetSafeNormal() * (Get_ReachLimit() - k_InsideTheLimitCm);
        Log_RealPawnRow(k_Row, f"claim=first {Describe_From(_ClaimAt)}");
        Fire_ClaimAt(_ClaimAt);
        WaitSeconds(k_ClaimSpacingSeconds, n"OnClientSecondClaim");
    }

    UFUNCTION()
    private void OnClientSecondClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClaimAt = Get_RootLocation(_Target);
        Log_RealPawnRow(k_Row, f"claim=second {Describe_From(_ClaimAt)}");
        Fire_ClaimAt(_ClaimAt);
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // A blow on this machine's copy of the target's zone at InAt, with the cleaver, along the view's line to the target.
    private void Fire_ClaimAt(FVector InAt)
    {
        const auto Zone = _Target.As_HitZone(ECk_SanityCheck::UnChecked);
        const auto Address = Zone.Get_Address();
        const auto Direction = (Get_RootLocation(_Target) - Get_ViewLocation()).GetSafeNormal();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = InAt;
        Claim.Normal = Direction * -1.0;
        Claim.Impulse = Direction;
        utils_cue_generic::Request_ExecuteCue(_Player, GameplayTags::Cue_Mars_HeldItemUse_Strike, Claim,
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    // This machine's copy of the combat target within k_NearTargetCm of the pawn, with its zone composed.
    private void Find_Target()
    {
        if (ck::IsValid(_Target) || ck::Is_NOT_Valid(_Pawn))
        { return; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetCombatTarget"))
        {
            const auto Zone = Candidate.As_HitZone(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Zone) || (Get_RootLocation(Candidate) - _Pawn.GetActorLocation()).Size() > k_NearTargetCm)
            { continue; }

            _Target = Candidate;
            return;
        }
    }
}
