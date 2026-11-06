// A carrier holding a one-handed key in its right glove reaches for a lock with that glove, carrying the key to the keyhole
// with its fingers still closed on it, while the free left glove stays at rest: the lock's target names ReachHand Holding
// (utils_key_lock::Make_InteractTarget), and the reach any task or resolver bind asks for it (utils_fphands::Make_TargetReach)
// carries it. The lock stands left of the hand, where a Free reach would send the left glove. Isolated origin
// (160000, -86000, -30000).
class UMars_AutoTest_KeyLock_InsertReachesWithTheHoldingGlove : UMars_AutoTestRig_KeyLock
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(160000.0, -86000.0, -30000.0);
    // Left of the hand node (its -Y), well past Focus.SideSwitchMarginCm.
    private const FVector k_LockLocal = FVector(60.0, -40.0, 0.0);
    // The gloves' reach outruns the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_KeyLock _Lock;
    // The held key's distance from the lock before the reach.
    private float64 _RestDistanceCm = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.3f;
        Spec.Reach.Grab.GripSeconds = 0.3f;
        Spec.Reach.Grab.BackSeconds = 0.3f;
        Spec.Reach.Hold.ReachSeconds = 0.3f;
        Add_CarrierHands(Spec);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(k_Origin + k_LockLocal, GameplayTags::Key_Mars_Red,
            EMars_KeyLock_Release::Kept, FGameplayTag()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Red()));

        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the red key's holder is seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step("stow the key into the carrier's hotbar", n"Step_StowKey");
        Add_Step_WaitUntil("the right glove holds the key", n"Check_HoldingOneHanded", 0, 0);
        Add_Step("the lock reads Insert; ask the gloves for its target's reach", n"Step_ReachForTheLock");
        Add_Step_WaitUntil("the gloves reach out", n"Check_IsReachingOut", k_SlowPolls, 0);
        Add_Step("the right glove carries the key to the lock, fingers closed; the left stays", n"Step_AssertRightGloveCarries");
        Add_Step_WaitUntil("the gloves close on the lock", n"Check_IsGripping", k_SlowPolls, 0);
        Add_Step("the key's visual rode the glove to the keyhole", n"Step_AssertKeyAtTheLock");
        Run_Steps(InHandle);
    }

    // Where the held key's visual is in the world; zero when there is none.
    private FVector Get_KeyVisualWorld() const
    {
        auto Visual = _HeldItem.Get_PresentationEntity().As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Visual))
        { return FVector::ZeroVector; }

        return utils_transform::Get_EntityCurrentTransform(Visual).GetLocation();
    }

    UFUNCTION()
    private void Check_IsGripping(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Grip);
    }

    // At rest the key sits at the hand, 72 cm from the lock; at the Grip it rides the glove's grip, which stops a standoff
    // short of the lock's point (the hold follow, UMars_Processor_FPHands_Tick).
    UFUNCTION()
    private void Step_AssertKeyAtTheLock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LockWorld = k_Origin + k_LockLocal;
        const auto Distance = Get_KeyVisualWorld().Distance(LockWorld);
        Assert_True(_RestDistanceCm > 50.0, f"at rest the key was away from the lock ({_RestDistanceCm} cm)");
        Assert_True(Distance < 30.0, f"at the Grip the key's visual is at the lock ({Distance} cm from its point, from {_RestDistanceCm} cm at rest)");
    }

    UFUNCTION()
    private void Step_StowKey(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_HoldingOneHanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_HeldItem.Get_CurrentItem()) && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::OneHanded);
    }

    UFUNCTION()
    private void Step_ReachForTheLock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lock.Get_ActionFor(_Carrier) == EMars_KeyLock_Action::Insert, "a carrier holding the lock's key reads Insert");

        _RestDistanceCm = Get_KeyVisualWorld().Distance(k_Origin + k_LockLocal);

        auto Target = _Lock.Get_Interactable().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        const auto Request = utils_fphands::Make_TargetReach(Target);
        Assert_True(Request.ReachHand == EMars_FPHands_ReachHand::Holding, "the lock's target asks for the holding glove");
        _Hands.Request_StartReach(Request);
    }

    UFUNCTION()
    private void Check_IsReachingOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Phase = _Hands.Get_Phase();
        auto Res = OutResult;
        Res.Set(Phase == EMars_FPHands_Phase::Reach || Phase == EMars_FPHands_Phase::Grip || Phase == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    private void Step_AssertRightGloveCarries(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Right), "the right glove, which holds the key, reaches for the lock");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Left), "the free left glove stays at rest, though the lock is on its side");
        Assert_False(_Hands.TryGet_ReachPose(EMars_Hand::Right).IsSet(), "the holding glove plays no reach pose: its fingers stay on the key");
    }
}
