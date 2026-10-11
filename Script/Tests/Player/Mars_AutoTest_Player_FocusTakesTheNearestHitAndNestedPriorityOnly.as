// A world item's pickup probe: its BoundsFit box about the pickup's world pose (utils_world_item::Make_ProbeFit).
struct FMars_AutoTest_Player_ProbeBox
{
    FTransform World;
    FVector HalfExtents;
}

// Focus takes the nearest hit along the view ray, and priority only among what is nested in it. The player-path carrier
// looks down from an eye 100 cm up, through the player's interaction trace, over three scenes on its floor:
// - a lever's probe 100 cm along the ray to a meat slab lying further out: the lever is focused, though the slab (a food,
//   FocusPriority 20 over the lever's 0) lies under the same ray behind it;
// - a meat slab lying in a large platter: looking at the slab's middle, the slab is focused, not the platter;
// - a second meat slab lying on the floor of a second large platter (turned so its long side runs along the tray's, between
//   the platter's walls), seen along a ray that enters the platter's probe first and the slab's a few centimetres behind
//   it (within constants_player_sm::k_NestingToleranceCm), found from the two probe boxes as they lie: the slab's side below
//   the platter's rim, from this eye. The trace's own hit distances prove the platter's is the nearer, and the slab is
//   focused all the same: it wins by nesting (FocusPriority 20 over the platter's 0), not by distance.
// Isolated origin (92000, -40000, -30000).
class UMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly : UMars_AutoTestRig_PlayerPath
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(92000.0, -40000.0, -30000.0);
    private const FVector k_FarSlabLocal = FVector(170.0, 0.0, 10.0);
    private const FVector k_PlatterLocal = FVector(70.0, -90.0, 0.0);
    private const FVector k_NestedPlatterLocal = FVector(-70.0, -90.0, 0.0);
    // How far along the ray to the far slab the lever's probe sits, and its radius.
    private const float64 k_LeverAlongRay = 100.0;
    private const float32 k_LeverRadius = 8.0f;
    private const int32 k_SettlePolls = 900;
    // The nested scene's aim puts the slab's hit this far behind the platter's: clear of zero (the platter is the nearer)
    // and of the nesting tolerance (the slab is nested), as near the middle as the grid allows.
    private const float64 k_MinLeadCm = 2.0;
    private const float64 k_MaxLeadCm = 5.0;
    private const float64 k_WantedLeadCm = 3.5;
    // Aim candidates per slab face edge, from -0.9 to 0.9 of the half extent.
    private const int32 k_AimGrid = 13;

    private FCk_Handle _FarSlabEntity;
    private FCk_Handle _PlatterEntity;
    private FCk_Handle _PlatterSlabEntity;
    private FCk_Handle _NestedPlatterEntity;
    private FCk_Handle _NestedSlabEntity;
    private FCk_Handle_Interactable _Lever;

    // Per scene entity (the slabs and the platters): its last location and how many polls it has moved less than 1.5 mm.
    private TArray<FVector> _LastLocations;
    private TArray<int32> _StillPolls;

    // The nested scene's aim, the entry distances the probe boxes predict for it, and the trace's latest hit distance on
    // each pickup since the aim (measured as the focus task measures it: the hit point's distance from the viewpoint).
    private FVector _NestedAim;
    private float64 _PredictedPlatterHitCm = 0.0;
    private float64 _PredictedSlabHitCm = 0.0;
    private bool _IsRecordingHits = false;
    private TOptional<float64> _PlatterHitCm;
    private TOptional<float64> _SlabHitCm;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _EyeHeight = 100.0;
        Build_PlayerPath(InHandle, k_Origin);

        auto Owner = InHandle;
        _FarSlabEntity = Spawn_Slab(k_FarSlabLocal);
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterLocal + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));
        _PlatterSlabEntity = Spawn_Slab(k_PlatterLocal + FVector(0.0, 0.0, 25.0));
        _NestedPlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + k_NestedPlatterLocal + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));
        _NestedSlabEntity = Spawn_SlabAlongY(k_NestedPlatterLocal + FVector(0.0, 0.0, 25.0));

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the slabs and the platters are constructed and lie still", n"Check_ScenesStill", k_SettlePolls, 0);
        Add_Step("put a lever's probe on the ray to the far slab and look at the slab", n"Step_LeverOnTheRayToTheFarSlab");
        Add_Step_WaitUntil("the lever is focused", n"Check_LeverFocused", 0, 0);
        Add_Step("the far slab lies under the ray behind the lever and is not focused", n"Step_AssertTheNearestWins");
        Add_Step("look at the slab lying in the platter", n"Step_LookAtThePlatterSlab");
        Add_Step_WaitUntil("the slab in the platter is focused", n"Check_PlatterSlabFocused", 0, 0);
        Add_Step("the platter is not focused", n"Step_AssertTheNestedSlabWins");
        Add_Step("look away from everything", n"Step_LookAway");
        Add_Step_WaitUntil("nothing is focused", n"Check_NothingFocused", 0, 0);
        Add_Step("look onto the second slab through its platter's probe: the platter's probe first on the ray, the slab's just behind", n"Step_AimThroughThePlatterOntoTheSlab");
        Add_Step_WaitUntil("the trace hits the second platter and its slab, and the slab is focused", n"Check_NestedSlabFocused", 0, 0);
        Add_Step("the platter's hit is the nearer, the slab's is nested behind it, and the slab is focused by its priority", n"Step_AssertTheSlabWinsByNesting");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ScenesStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        TArray<FCk_Handle> Entities;
        Entities.Add(_FarSlabEntity);
        Entities.Add(_PlatterEntity);
        Entities.Add(_PlatterSlabEntity);
        Entities.Add(_NestedPlatterEntity);
        Entities.Add(_NestedSlabEntity);

        if (_LastLocations.Num() != Entities.Num())
        {
            _LastLocations.SetNum(Entities.Num());
            _StillPolls.SetNum(Entities.Num());
        }

        auto AllStill = true;
        for (int32 Index = 0; Index < Entities.Num(); ++Index)
        {
            if (Get_IsConstructedWorldItem(Entities[Index]) == false)
            {
                AllStill = false;
                continue;
            }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entities[Index].As_Transform()).GetLocation();
            _StillPolls[Index] = _LastLocations[Index].Equals(Location, 0.15) ? _StillPolls[Index] + 1 : 0;
            _LastLocations[Index] = Location;
            AllStill = AllStill && _StillPolls[Index] >= 10;
        }

        auto Res = OutResult;
        Res.Set(AllStill);
    }

    UFUNCTION()
    private void Step_LeverOnTheRayToTheFarSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto SlabAt = Get_PickupWorld(_FarSlabEntity);
        const auto Direction = (SlabAt - Get_EyeWorld()).GetSafeNormal();
        _Lever = Build_ProbedLever(InHandle, Get_EyeWorld() + Direction * k_LeverAlongRay, k_LeverRadius);
        Aim_ViewAt(SlabAt);
    }

    UFUNCTION()
    private void Check_LeverFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Lever) && _Lever.Get_CurrentFocuser() == _Carrier);
    }

    UFUNCTION()
    private void Step_AssertTheNearestWins(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto FarSlabPickup = _FarSlabEntity.As_WorldItem().Get_Pickup();
        Assert_True(Get_IsUnderTheTrace(FarSlabPickup), "the far slab's pickup lies under the ray behind the lever");
        Assert_False(FarSlabPickup.Get_IsFocused(), "the far slab is not focused: priority does not reach past the nearest hit");
        Assert_True(FarSlabPickup.Get_FocusPriority() > _Lever.Get_FocusPriority(), "the far slab outranks the lever by priority");
    }

    UFUNCTION()
    private void Step_LookAtThePlatterSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(Get_PickupWorld(_PlatterSlabEntity));
    }

    UFUNCTION()
    private void Check_PlatterSlabFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterSlabEntity.As_WorldItem().Get_Pickup().Get_CurrentFocuser() == _Carrier);
    }

    UFUNCTION()
    private void Step_AssertTheNestedSlabWins(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PlatterPickup = _PlatterEntity.As_WorldItem().Get_Pickup();
        Log(f"[FocusTest] the platter's pickup is under the ray beside the slab: {Get_IsUnderTheTrace(PlatterPickup)}");
        Assert_False(PlatterPickup.Get_IsFocused(), "the platter is not focused");
        Assert_False(_Lever.Get_IsFocused(), "the lever lost the focus");
    }

    UFUNCTION()
    private void Step_LookAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAway();
    }

    // The nested scene's slab is focused by its own aim, from a view that focuses nothing.
    UFUNCTION()
    private void Check_NothingFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterSlabEntity.As_WorldItem().Get_Pickup().Get_IsFocused() == false
            && _PlatterEntity.As_WorldItem().Get_Pickup().Get_IsFocused() == false
            && _NestedSlabEntity.As_WorldItem().Get_Pickup().Get_IsFocused() == false
            && _NestedPlatterEntity.As_WorldItem().Get_Pickup().Get_IsFocused() == false
            && _FarSlabEntity.As_WorldItem().Get_Pickup().Get_IsFocused() == false
            && _Lever.Get_IsFocused() == false);
    }

    // Searches a grid of points over every face of the slab's probe box for the ray from the eye whose entry into the slab's
    // box lies k_MinLeadCm..k_MaxLeadCm behind its entry into the platter's box, nearest k_WantedLeadCm; then starts recording
    // the trace's hits and turns the eye onto that point.
    UFUNCTION()
    private void Step_AimThroughThePlatterOntoTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PlatterBox = Make_PickupBox(_NestedPlatterEntity);
        const auto SlabBox = Make_PickupBox(_NestedSlabEntity);
        const auto Eye = Get_EyeWorld();

        TArray<float64> Halves;
        Halves.Add(SlabBox.HalfExtents.X);
        Halves.Add(SlabBox.HalfExtents.Y);
        Halves.Add(SlabBox.HalfExtents.Z);

        auto IsFound = false;
        auto BestError = 0.0;
        TArray<float64> Coords;
        Coords.SetNum(3);
        for (int32 Axis = 0; Axis < 3; ++Axis)
        {
            for (int32 Side = -1; Side <= 1; Side += 2)
            {
                for (int32 U = 0; U < k_AimGrid; ++U)
                {
                    for (int32 V = 0; V < k_AimGrid; ++V)
                    {
                        const auto AxisU = (Axis + 1) % 3;
                        const auto AxisV = (Axis + 2) % 3;
                        Coords[Axis] = float64(Side) * Halves[Axis];
                        Coords[AxisU] = (-0.9 + 1.8 * float64(U) / float64(k_AimGrid - 1)) * Halves[AxisU];
                        Coords[AxisV] = (-0.9 + 1.8 * float64(V) / float64(k_AimGrid - 1)) * Halves[AxisV];
                        const auto Target = SlabBox.World.TransformPosition(FVector(Coords[0], Coords[1], Coords[2]));

                        const auto PlatterHit = TryGet_RayEntry(PlatterBox, Eye, Target);
                        const auto SlabHit = TryGet_RayEntry(SlabBox, Eye, Target);
                        if (PlatterHit.IsSet() == false || SlabHit.IsSet() == false)
                        { continue; }

                        const auto Lead = SlabHit.GetValue() - PlatterHit.GetValue();
                        const auto IsInReach = SlabHit.GetValue() <= float64(k_TraceDistance) - 10.0;
                        if (Lead < k_MinLeadCm || Lead > k_MaxLeadCm || IsInReach == false)
                        { continue; }

                        const auto Error = Math::Abs(Lead - k_WantedLeadCm);
                        if (IsFound && Error >= BestError)
                        { continue; }

                        IsFound = true;
                        BestError = Error;
                        _NestedAim = Target;
                        _PredictedPlatterHitCm = PlatterHit.GetValue();
                        _PredictedSlabHitCm = SlabHit.GetValue();
                    }
                }
            }
        }

        if (IsFound == false)
        {
            FinishFailure(f"precondition: no ray from the eye {Eye} onto the slab's probe box (centre {SlabBox.World.GetLocation()}, half {SlabBox.HalfExtents}) enters it {k_MinLeadCm}..{k_MaxLeadCm} cm behind the platter's (centre {PlatterBox.World.GetLocation()}, half {PlatterBox.HalfExtents})");
            return;
        }

        Log(f"[FocusTest] nested aim {_NestedAim}: the boxes predict the platter's hit at {_PredictedPlatterHitCm :.2} cm and the slab's at {_PredictedSlabHitCm :.2} cm");

        auto Trace = _Carrier.As_PlayerViewpoint().Get_InteractionTrace();
        Trace.BindTo_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
        Trace.BindTo_OnOverlapUpdated(FCk_Delegate_ProbeTrace_OnOverlapUpdated(this, n"OnTraceOverlapUpdated"));
        _PlatterHitCm.Reset();
        _SlabHitCm.Reset();
        _IsRecordingHits = true;

        Aim_ViewAt(_NestedAim);
    }

    UFUNCTION()
    private void Check_NestedSlabFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterHitCm.IsSet() && _SlabHitCm.IsSet()
            && _NestedSlabEntity.As_WorldItem().Get_Pickup().Get_CurrentFocuser() == _Carrier);
    }

    UFUNCTION()
    private void Step_AssertTheSlabWinsByNesting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The pieces end with the test before the carrier's trace does: stop listening while they are still here.
        _IsRecordingHits = false;
        auto Trace = _Carrier.As_PlayerViewpoint().Get_InteractionTrace();
        Trace.UnbindFrom_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
        Trace.UnbindFrom_OnOverlapUpdated(FCk_Delegate_ProbeTrace_OnOverlapUpdated(this, n"OnTraceOverlapUpdated"));

        const auto PlatterHit = _PlatterHitCm.GetValue();
        const auto SlabHit = _SlabHitCm.GetValue();
        Log(f"[FocusTest] the trace hit the platter at {PlatterHit :.2} cm and the slab at {SlabHit :.2} cm (predicted {_PredictedPlatterHitCm :.2} and {_PredictedSlabHitCm :.2})");

        Assert_True(PlatterHit < SlabHit,
            f"the platter's probe is hit nearer than the slab's along the ray (platter {PlatterHit :.2} cm, slab {SlabHit :.2} cm)");
        const auto Tolerance = constants_player_sm::k_NestingToleranceCm;
        Assert_True(SlabHit - PlatterHit <= Tolerance,
            f"the slab's hit is nested: within {Tolerance} cm behind the platter's ({SlabHit - PlatterHit :.2} cm)");

        const auto SlabPickup = _NestedSlabEntity.As_WorldItem().Get_Pickup();
        const auto PlatterPickup = _NestedPlatterEntity.As_WorldItem().Get_Pickup();
        Assert_True(SlabPickup.Get_FocusPriority() > PlatterPickup.Get_FocusPriority(), "the slab outranks the platter by FocusPriority");
        Assert_True(SlabPickup.Get_CurrentFocuser() == _Carrier, "the slab is focused: it wins by nesting, not by distance");
        Assert_False(PlatterPickup.Get_IsFocused(), "the platter, the nearer hit, is not focused");
    }

    UFUNCTION()
    private void OnTraceBeginOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        Record_Hit(InPayload.Get_OtherEntity(), InPayload.Get_ContactPoints());
    }

    UFUNCTION()
    private void OnTraceOverlapUpdated(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnOverlapUpdated InPayload)
    {
        Record_Hit(InPayload.Get_OtherEntity(), InPayload.Get_ContactPoints());
    }

    // The hit point's distance from the viewpoint the trace is cast from: the focus task's measure of a hit.
    private void Record_Hit(FCk_Handle InEntity, const TArray<FVector>& InContactPoints)
    {
        if (_IsRecordingHits == false || InContactPoints.Num() == 0)
        { return; }

        const auto ViewLocation = utils_transform::Get_EntityCurrentTransform(_Eye.As_Transform()).GetLocation();
        const auto Distance = TOptional<float64>((InContactPoints[0] - ViewLocation).Size());

        FCk_Handle PlatterPickup = _NestedPlatterEntity.As_WorldItem().Get_Pickup();
        FCk_Handle SlabPickup = _NestedSlabEntity.As_WorldItem().Get_Pickup();
        if (InEntity == PlatterPickup)
        { _PlatterHitCm = Distance; }
        else if (InEntity == SlabPickup)
        { _SlabHitCm = Distance; }
    }

    // Spawn_Slab with the slab turned a quarter about Z: its 36.6 cm long side along the large tray's 44.5 cm one fits between
    // the platter's walls, where along the 37.3 cm side it would not.
    private FCk_Handle Spawn_SlabAlongY(FVector InLocal)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator(0.0, 90.0, 0.0), _Origin + InLocal);
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto Entity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(Entity);
        return Entity;
    }

    // Where a world item's pickup probe sits (its bounds' centre).
    private FVector Get_PickupWorld(FCk_Handle InWorldItemEntity) const
    {
        FCk_Handle Pickup = InWorldItemEntity.As_WorldItem().Get_Pickup();
        return utils_transform::Get_EntityCurrentTransform(Pickup.As_Transform()).GetLocation();
    }

    private FMars_AutoTest_Player_ProbeBox Make_PickupBox(FCk_Handle InWorldItemEntity) const
    {
        FCk_Handle Pickup = InWorldItemEntity.As_WorldItem().Get_Pickup();
        const auto PickupWorld = utils_transform::Get_EntityCurrentTransform(Pickup.As_Transform());

        auto Box = FMars_AutoTest_Player_ProbeBox();
        Box.World = FTransform(PickupWorld.Rotator(), PickupWorld.GetLocation());
        Box.HalfExtents = InWorldItemEntity.As_WorldItem().Get_BoundsFit().HalfExtents;
        return Box;
    }

    // How far from InFrom, toward InThrough, the ray enters InBox; unset when it misses (the slab test in the box's frame).
    private TOptional<float64> TryGet_RayEntry(const FMars_AutoTest_Player_ProbeBox& InBox, FVector InFrom, FVector InThrough) const
    {
        const auto Origin = InBox.World.InverseTransformPosition(InFrom);
        const auto Direction = InBox.World.InverseTransformPosition(InFrom + (InThrough - InFrom).GetSafeNormal()) - Origin;

        TArray<float64> Origins;
        Origins.Add(Origin.X);
        Origins.Add(Origin.Y);
        Origins.Add(Origin.Z);

        TArray<float64> Directions;
        Directions.Add(Direction.X);
        Directions.Add(Direction.Y);
        Directions.Add(Direction.Z);

        TArray<float64> Halves;
        Halves.Add(InBox.HalfExtents.X);
        Halves.Add(InBox.HalfExtents.Y);
        Halves.Add(InBox.HalfExtents.Z);

        auto Enter = -1000000.0;
        auto Exit = 1000000.0;
        for (int32 Axis = 0; Axis < 3; ++Axis)
        {
            if (Math::Abs(Directions[Axis]) < 0.000001)
            {
                if (Math::Abs(Origins[Axis]) > Halves[Axis])
                { return TOptional<float64>(); }

                continue;
            }

            const auto Near = (-Halves[Axis] - Origins[Axis]) / Directions[Axis];
            const auto Far = (Halves[Axis] - Origins[Axis]) / Directions[Axis];
            Enter = Math::Max(Enter, Math::Min(Near, Far));
            Exit = Math::Min(Exit, Math::Max(Near, Far));
        }

        if (Exit < Math::Max(Enter, 0.0))
        { return TOptional<float64>(); }

        return TOptional<float64>(Math::Max(Enter, 0.0));
    }
}
