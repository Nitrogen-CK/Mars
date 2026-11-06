// A key taken out of a Removable lock by a carrier with gloves leaves the keyhole only when the gloves close on it, and
// rides them home: every poll before the Grip the lock's key visual is drawn and no held visual exists; from the Grip on
// the held visual is drawn, starting at the keyhole, and travels to its hold offset in steps no larger than a fraction of
// the way (the lock's task acts at the Grip and times the held visual's arrival over the gloves' return). A poll with
// neither mesh is a blink, one with both a double. The key is put in the lock through the kernel first. Isolated origin
// (160000, -90000, -30000).
class UMars_AutoTest_KeyLock_ATakenKeyLeavesTheSocketAtTheGripAndRidesHome : UMars_AutoTestRig_KeyLock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(160000.0, -90000.0, -30000.0);
    private const FVector k_LockLocal = FVector(60.0, 0.0, 0.0);
    // The gloves' grab outruns the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    // The held visual's hold offset is reached when its node offset is within this (cm) of HeldOffset.
    private const float64 k_SettleCm = 0.5;
    // A single poll's travel beyond this fraction of the whole keyhole-to-hold distance is a jump, not a ride.
    private const float64 k_MaxStepFraction = 0.5;

    private FCk_Handle_KeyLock _Lock;
    private FVector _KeyholeWorld = FVector::ZeroVector;

    // The sampler's ledger from the take's start to the arrival's end.
    private int32 _Polls = 0;
    private int32 _BlinkPolls = 0;
    private int32 _DoublePolls = 0;
    private int32 _VisualPolls = 0;
    private int32 _SocketGonePollsBeforeGrip = 0;
    private int32 _VisualPollsBeforeGrip = 0;
    private TOptional<FVector> _FirstVisualWorld;
    private TOptional<FVector> _LastVisualWorld;
    private float64 _MaxStepCm = 0.0;

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
        Add_CarrierHands(Spec);

        _Lock = MakeLock(InHandle, FMars_AutoTestRig_KeyLockSetup(k_Origin + k_LockLocal, GameplayTags::Key_Mars_Red,
            EMars_KeyLock_Release::Removable, FGameplayTag()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Key_Red()));

        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step_WaitUntil("the red key's holder is seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step("stow the key into the carrier's hotbar", n"Step_StowKey");
        Add_Step_WaitUntil("the carrier holds the key", n"Check_KeyHeld", 0, 0);
        Add_Step("put the key in the lock through the kernel", n"Step_InsertThroughKernel");
        Add_Step_WaitUntil("the lock holds the key, draws it, and the hands are empty and at rest", n"Check_KeyInTheLock", k_SlowPolls, 0);
        Add_Step("the carrier focuses the lock", n"Step_Focus");
        Add_Step_WaitUntil("the lock's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier takes the key through the lock's interaction", n"Step_Take");
        Add_Step_WaitUntil("the grab ran its course and the held visual settled at its hold offset (sampling every poll)", n"Check_TakeDone", k_SlowPolls, 0);
        Add_Step("the key left the keyhole at the Grip, was drawn every poll and rode home", n"Step_AssertRodeHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StowKey(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_KeyHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Items.Num() == 1 && _HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_InsertThroughKernel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lock.Get_ActionFor(_Carrier) == EMars_KeyLock_Action::Insert, "a carrier holding the lock's key reads Insert");
        _Lock.Request_Insert(FMars_Request_KeyLock_Insert(_Items[0]));
    }

    UFUNCTION()
    private void Check_KeyInTheLock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lock.Get_Key() == _Items[0] && Get_HasDrawnMesh(_Lock.Get_Visual())
            && ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()) && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::Empty
            && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Interactable = _Lock.Get_Interactable();
        Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Interactable);
    }

    // What the player's resolver does on a press: the interaction starts, and its task asks the gloves for the reach.
    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lock.Get_ActionFor(_Carrier) == EMars_KeyLock_Action::Take, "an empty-handed carrier reads Take");
        _KeyholeWorld = utils_transform::Get_EntityCurrentTransform(_Lock.Get_KeyMount()).GetLocation();
        _HandPhases.Empty();

        auto Target = _Lock.Get_Interactable().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_TakeDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();

        const auto Gripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        const auto AtRest = _Hands.Get_Phase() == EMars_FPHands_Phase::None;
        const auto Held = _HeldItem.Get_CurrentItem() == _Items[0];

        auto Settled = false;
        auto Node = _HeldItem.Get_PresentationEntity().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (Held && ck::IsValid(Node))
        {
            const auto HeldOffset = _Items[0].Get_Presentation().Mounting.HeldOffset.GetLocation();
            Settled = utils_scene_node::Get_Offset(Node).GetLocation().Equals(HeldOffset, k_SettleCm);
        }

        auto Res = OutResult;
        Res.Set(Gripped && AtRest && Held && Settled);
    }

    // One poll of the ledger: which of the two meshes is drawn, whether the Grip has come, and where the held visual is.
    private void Sample()
    {
        ++_Polls;
        const auto Gripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        const auto SocketDrawn = Get_HasDrawnMesh(_Lock.Get_Visual());
        const auto VisualEntity = _HeldItem.Get_PresentationEntity();
        const auto VisualDrawn = Get_HasDrawnMesh(VisualEntity);

        if (SocketDrawn == false && VisualDrawn == false)
        { ++_BlinkPolls; }

        if (SocketDrawn && VisualDrawn)
        { ++_DoublePolls; }

        if (Gripped == false && SocketDrawn == false)
        { ++_SocketGonePollsBeforeGrip; }

        if (Gripped == false && VisualDrawn)
        { ++_VisualPollsBeforeGrip; }

        if (VisualDrawn == false)
        { return; }

        ++_VisualPolls;
        const auto VisualWorld = utils_transform::Get_EntityCurrentTransform(VisualEntity.As_Transform()).GetLocation();
        if (_FirstVisualWorld.IsSet() == false)
        { _FirstVisualWorld = TOptional<FVector>(VisualWorld); }

        if (_LastVisualWorld.IsSet())
        { _MaxStepCm = Math::Max(_MaxStepCm, _LastVisualWorld.GetValue().Distance(VisualWorld)); }

        _LastVisualWorld = TOptional<FVector>(VisualWorld);
    }

    UFUNCTION()
    private void Step_AssertRodeHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_VisualPolls > 1, f"the held visual was sampled over several polls (got {_VisualPolls} of {_Polls})");
        Assert_Equals_Int(_SocketGonePollsBeforeGrip, 0, "before the Grip the key stayed drawn in the keyhole");
        Assert_Equals_Int(_VisualPollsBeforeGrip, 0, "before the Grip no held visual existed");
        Assert_Equals_Int(_BlinkPolls, 0, "no poll of the take drew neither the keyhole's key nor the held visual");
        Assert_Equals_Int(_DoublePolls, 0, "no poll of the take drew both");

        const auto FirstVisual = _FirstVisualWorld.IsSet() ? _FirstVisualWorld.GetValue() : FVector::ZeroVector;
        Assert_True(FirstVisual.Equals(_KeyholeWorld, 5.0), f"the held visual started at the keyhole {_KeyholeWorld} (got {FirstVisual})");

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        const auto HoldWorld = (_Items[0].Get_Presentation().Mounting.HeldOffset * HandWorld).GetLocation();
        const auto Travel = _KeyholeWorld.Distance(HoldWorld);
        Assert_True(_MaxStepCm < Travel * k_MaxStepFraction,
            f"the visual's largest single-poll step ({_MaxStepCm} cm) is a fraction of the {Travel} cm from the keyhole to the hold: a ride, not a jump");
        Assert_True(ck::Is_NOT_Valid(_Lock.Get_Key()) && ck::Is_NOT_Valid(_Lock.Get_Visual()), "the lock is empty and draws no key");
    }
}
