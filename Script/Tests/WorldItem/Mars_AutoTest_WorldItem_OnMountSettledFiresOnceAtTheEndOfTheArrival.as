// OnMountSettled fires once per mount, at the end of its arrival, naming the committed mount and carrier. A carrier puts on
// a backpack (its holder -> the backpack slot: Carried on the Back, arriving over the presentation's ArriveSeconds),
// raises it (the backpack slot selected: Held on the Hand, the same) and releases it (World, no travel). Each mount
// settles exactly once, in order Carried, Held, World. A mount with travel settles no sooner than ArriveSeconds after its
// OnMountChanged, with no arrival left in flight and Get_IsSettled reading true in the handler; the release settles in the
// frame it commits. Isolated origin (48400, -12000, -30000).
class UMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(48400.0, -12000.0, -30000.0);
    private const FVector k_PackOffset = FVector(200.0, 0.0, 0.0);
    // The travel accumulates frame deltas; float rounding only.
    private const float64 k_TimeSlackSeconds = 0.005;

    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_Item _Item;
    private float64 _ArriveSeconds = 0.0;

    // In parallel: one entry per OnMountSettled, with what the world item read in the handler.
    private TArray<EMars_WorldItem_Mount> _SettledMounts;
    private TArray<FCk_Handle> _SettledCarriers;
    private TArray<float64> _SettledAt;
    private TArray<bool> _SettledWithArrival;
    private TArray<bool> _SettledReadSettled;
    // In parallel: one entry per OnMountChanged.
    private TArray<EMars_WorldItem_Mount> _ChangedTo;
    private TArray<float64> _ChangedAt;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        const UMars_ItemTrait_Presentation Presentation = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
        _ArriveSeconds = Presentation.Mounting.ArriveSeconds;

        Spawn_Floor(InHandle, k_Origin + k_PackOffset);
        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnPackConstructed"));

        Add_Step_WaitUntil("the backpack is constructed and its item linked", n"Check_Linked", 0, 0);
        Add_Step("put it on: its holder -> the backpack slot", n"Step_Wear");
        Add_Step_WaitUntil("it settles Carried", n"Check_OneSettle", 0, 0);
        Add_Step_WaitSeconds("a second settle would fire in this window", 0.5f);
        Add_Step("one Carried settle, after the arrival; raise it", n"Step_AssertCarriedAndRaise");
        Add_Step_WaitUntil("it settles Held", n"Check_TwoSettles", 0, 0);
        Add_Step_WaitSeconds("a second settle would fire in this window", 0.5f);
        Add_Step("one Held settle, after the arrival; release it", n"Step_AssertHeldAndRelease");
        Add_Step_WaitUntil("it settles in the World", n"Check_ThreeSettles", 0, 0);
        Add_Step_WaitSeconds("a second settle would fire in this window", 0.5f);
        Add_Step("one World settle, in the frame it committed", n"Step_AssertWorld");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void OnPackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Pack = InEntityScriptHandle.As_WorldItem();
        _Pack.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));
        _Pack.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnMountSettled"));
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        _ChangedTo.Add(InNew);
        _ChangedAt.Add(System::GetGameTimeInSeconds());
    }

    UFUNCTION()
    private void OnMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        _SettledMounts.Add(InMount);
        _SettledCarriers.Add(InCarrier);
        _SettledAt.Add(System::GetGameTimeInSeconds());
        _SettledWithArrival.Add(InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_Arrival));
        _SettledReadSettled.Add(InWorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void Check_Linked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Pack) && ck::IsValid(_Pack.Get_Item()));
    }

    UFUNCTION()
    private void Step_Wear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _Pack.Get_Item();
        Assert_Equals_Int(_SettledMounts.Num(), 0, "a world item lying where it spawned has not settled anywhere yet");

        auto Holder = _Pack.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_OneSettle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SettledMounts.Num() >= 1);
    }

    UFUNCTION()
    private void Check_TwoSettles(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SettledMounts.Num() >= 2);
    }

    UFUNCTION()
    private void Check_ThreeSettles(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SettledMounts.Num() >= 3);
    }

    // The InIndex-th settle and change name InMount (and the carrier); a mount with travel settled after its arrival.
    private void Assert_Settle(int32 InIndex, EMars_WorldItem_Mount InMount, bool InHasTravel)
    {
        Assert_True(_SettledMounts[InIndex] == InMount && _ChangedTo[InIndex] == InMount,
            f"settle {InIndex} names [{InMount :n}] (settled [{_SettledMounts[InIndex] :n}], changed to [{_ChangedTo[InIndex] :n}])");
        Assert_False(_SettledWithArrival[InIndex], f"settle {InIndex}: no arrival is in flight");
        Assert_True(_SettledReadSettled[InIndex], f"settle {InIndex}: the world item reads settled in the handler");

        const auto Waited = _SettledAt[InIndex] - _ChangedAt[InIndex];
        if (InHasTravel)
        {
            Assert_True(Waited >= _ArriveSeconds - k_TimeSlackSeconds,
                f"settle {InIndex} came after the arrival: {Waited :.3} s after the mount changed (ArriveSeconds {_ArriveSeconds :.3})");
        }
        else
        { Assert_True(Waited <= k_TimeSlackSeconds, f"settle {InIndex} came in the frame the mount changed ({Waited :.3} s after)"); }
    }

    UFUNCTION()
    private void Step_AssertCarriedAndRaise(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SettledMounts.Num(), 1, "one settle so far");
        Assert_Equals_Int(_ChangedTo.Num(), 1, "one mount change so far");
        if (_SettledMounts.Num() != 1 || _ChangedTo.Num() != 1)
        { return; }

        Assert_Settle(0, EMars_WorldItem_Mount::Carried, true);
        Assert_True(_SettledCarriers[0] == _Carrier, "the Carried settle names the carrier");

        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(_Hotbar.Get_BackpackIndex().GetValue()));
    }

    UFUNCTION()
    private void Step_AssertHeldAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SettledMounts.Num(), 2, "two settles so far");
        Assert_Equals_Int(_ChangedTo.Num(), 2, "two mount changes so far");
        if (_SettledMounts.Num() != 2 || _ChangedTo.Num() != 2)
        { return; }

        Assert_Settle(1, EMars_WorldItem_Mount::Held, true);
        Assert_True(_SettledCarriers[1] == _Carrier, "the Held settle names the carrier");

        _Pack.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Step_AssertWorld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SettledMounts.Num(), 3, "three settles in all");
        Assert_Equals_Int(_ChangedTo.Num(), 3, "three mount changes in all");
        if (_SettledMounts.Num() != 3 || _ChangedTo.Num() != 3)
        { return; }

        Assert_Settle(2, EMars_WorldItem_Mount::World, false);
        Assert_True(ck::Is_NOT_Valid(_SettledCarriers[2]), "the World settle names no carrier");
        Assert_True(_Pack.Get_HeldItem() == _Item, "the item is back in its holder");
    }
}
