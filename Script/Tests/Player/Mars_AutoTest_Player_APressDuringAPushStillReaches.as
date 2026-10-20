// A press during a push still reaches. The gloved carrier holds a rock while a second rock lies still beside it, focused and
// offered to its resolver. The carrier drops its rock (the held item's real drop: the gloves follow it through with a push)
// and presses Use while the gloves still push: the gloves enter Reach for the loose rock after the press, and the rock lands
// in a bag slot while they Grip it - the reach the pickup asked for, never a fallback without the gloves. Isolated origin
// (38200, -21000, -30000).
class UMars_AutoTest_Player_APressDuringAPushStillReaches : UMars_AutoTestRig_PickupByPress
{
    private const FVector k_Origin = FVector(38200.0, -21000.0, -30000.0);

    // How many phases the gloves had entered when Use was pressed.
    private int32 _PhasesBeforePress = 0;
    private TOptional<EMars_FPHands_Phase> _PhaseAtPress;
    // The gloves' phase, and whether they were on the loose rock, when a bag slot first took an item after the drop.
    private TOptional<EMars_FPHands_Phase> _PhaseAtStow;
    private bool _ReachingTheRockAtStow = false;
    // The dropped rock's new world item, tracked for cleanup once found.
    private FCk_Handle_WorldItem _Dropped;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _LooseRockLocal = FVector(90.0, 80.0, 20.0);
        Build_Rig(InHandle, k_Origin);

        Add_Steps_UpToALooseRockOfferedWhileHolding();
        Add_Step("watch the bag slots and drop the held rock", n"Step_WatchAndDrop");
        Add_Step_WaitUntil("the gloves follow the drop through with a push", n"Check_Pushing", 0, 0);
        Add_Step("press Use on the loose rock while the gloves push", n"Step_PressDuringThePush");
        Add_Step_WaitFrames("a tap", 2);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the loose rock is picked up", n"Check_LooseRockStowed", 0, 0);
        Add_Step("the gloves reached for it after the press and it landed at their Grip", n"Step_AssertReachedAtTheGrip");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WatchAndDrop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));
        _Use.Request_Drop(FMars_Request_HeldItemUse_Drop());
    }

    UFUNCTION()
    private void Check_Pushing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Push);
    }

    UFUNCTION()
    private void Step_PressDuringThePush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesBeforePress = _HandPhases.Num();
        _PhaseAtPress = TOptional<EMars_FPHands_Phase>(_Hands.Get_Phase());
        Step_PressUse(InHandle, InPayload);
    }

    // The drop empties a slot (no item); the pickup fills one.
    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        if (ck::Is_NOT_Valid(InMaybeItem) || _PhaseAtStow.IsSet())
        { return; }

        _PhaseAtStow = TOptional<EMars_FPHands_Phase>(_Hands.Get_Phase());
        _ReachingTheRockAtStow = _Hands.Get_IsReachTarget(_OfferedTarget);
    }

    // A transient rock's world item ends once its holder gives the item up. The dropped rock is found (and tracked) on the way.
    UFUNCTION()
    private void Check_LooseRockStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Track_TheDroppedRock(InHandle);

        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Landed) || ck::Is_NOT_Valid(_Landed.Get_HeldItem()));
    }

    // The drop spawns the held rock's world item under the world's transient entity: the World-mode world item near the
    // carrier that is not the loose rock.
    private void Track_TheDroppedRock(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Dropped))
        { return; }

        const auto WorldItems = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem");
        for (const auto& Entity : WorldItems)
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            FCk_Handle LandedEntity = _Landed;
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World || Entity == LandedEntity)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(k_Origin) >= 1000.0)
            { continue; }

            _Dropped = WorldItem;
            auto DroppedEntity = Entity;
            Track_ForCleanup(DroppedEntity);
            return;
        }
    }

    UFUNCTION()
    private void Step_AssertReachedAtTheGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PhaseAtPress == EMars_FPHands_Phase::Push, f"Use was pressed while the gloves pushed (phase then: {Describe_Phase(_PhaseAtPress)})");

        auto PhasesSincePress = FString();
        auto ReachIndex = -1;
        auto GripIndex = -1;
        for (int32 Index = _PhasesBeforePress; Index < _HandPhases.Num(); ++Index)
        {
            const auto Phase = _HandPhases[Index];
            PhasesSincePress = f"{PhasesSincePress} {Phase :n}";
            if (Phase == EMars_FPHands_Phase::Reach && ReachIndex < 0)
            { ReachIndex = Index; }

            if (Phase == EMars_FPHands_Phase::Grip && ReachIndex >= 0 && GripIndex < 0)
            { GripIndex = Index; }
        }

        Assert_True(ReachIndex >= 0 && GripIndex > ReachIndex,
            f"the gloves entered Reach and then Grip after the press (phases since the press:{PhasesSincePress})");
        Assert_True(_PhaseAtStow == EMars_FPHands_Phase::Grip && _ReachingTheRockAtStow,
            f"the loose rock landed in a bag slot while the gloves gripped it (phase then: {Describe_Phase(_PhaseAtStow)}, on the rock: {_ReachingTheRockAtStow})");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1)), "the loose rock is in a bag slot");
        Assert_True(ck::IsValid(_Dropped), "the dropped rock lies in the world");
    }

    private FString Describe_Phase(TOptional<EMars_FPHands_Phase> InPhase) const
    {
        if (InPhase.IsSet() == false)
        { return "unset"; }

        return f"{InPhase.GetValue() :n}";
    }
}
