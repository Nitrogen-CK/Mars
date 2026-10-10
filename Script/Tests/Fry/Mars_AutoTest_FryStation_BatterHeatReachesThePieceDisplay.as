// The fry station's heat reaches the piece's own display. A platter with a mushroom slice (dressed by the platter with its
// food's display) docks on the raw platter dock; an operator takes the station and one add-food press carries the slice
// into the oil. Once a face has heated past 0.05, at a frame a write lands (or the heat has stopped), the slice's display
// carries the kernel's six face heats in slots 0..5 and their mean, the batter's fry, in slot 10, within 0.03. The display
// follows on edges, never per frame: over a run of frames every change it shows is a jump of at least the write threshold
// in some slot, and frames whose heat moved by less show the same values as the frame before.
class UMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(16000.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    // The cook state's display slots: 0..12, the six face heats at 0..5, Fry at 10.
    private const int32 k_SlotCount = 13;
    private const int32 k_FrySlot = 10;
    // The write threshold (0.02) plus the frame or two a deferred write trails the kernel.
    private const float32 k_DisplayTolerance = 0.03f;
    private const float32 k_HeatedPast = 0.05f;
    // Below the write threshold: a change smaller than this would be a write off an edge.
    private const float32 k_EdgeFloor = 0.0199f;
    private const int32 k_WindowFrames = 30;

    private FCk_Handle _Raw;
    private FCk_Handle_FoodPiece _Slice;
    private FMars_CookingFeed_PieceId _PieceId;
    // The last poll's display slots and kernel face heats (empty before the first poll).
    private TArray<float32> _PolledSlots;
    private TArray<float32> _PolledHeats;
    // At the frame Check_DisplayCaughtUp passed.
    private TArray<float32> _SnapSlots;
    private TArray<float32> _SnapHeats;
    // Over the edge window: polls, display changes, changes smaller than an edge, and frames whose heat moved while the
    // display held.
    private int32 _WindowPolls = 0;
    private int32 _Rewrites = 0;
    private int32 _OffEdgeRewrites = 0;
    private int32 _HeldWhileHeating = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Fry(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars_items::Food_MushroomSlice());

        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the platter is constructed and the slice landed on it", n"Check_PlatterReady", 0, 10.0f);
        Add_Step("dock the mushroom platter as raw", n"Step_Dock");
        Add_Step_WaitUntil("the platter is docked and arrived", n"Check_Docked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 3.0f);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the kernel admitted the slice", n"Check_Admitted", 0, 5.0f);
        Add_Step("the fryer holds the slice, which wears its own display", n"Step_AssertAdmitted");
        Add_Step_WaitUntil("a face heated past 0.05 and the display caught up", n"Check_DisplayCaughtUp", 0, 10.0f);
        Add_Step("the slice's display carries its face heats and its fry", n"Step_AssertDisplayCarriesTheHeat");
        Add_Step_WaitUntil("a run of frames in the oil", n"Check_EdgeWindow", 0, 5.0f);
        Add_Step("the display changed only on edges", n"Step_AssertEdgesOnly");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Raw);
        _Slice = _Raw.As_Platter().Get_Held()[0];
        Dock(_InputDock, _Raw);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw));
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PieceId = Get_PieceIds()[0];
        Assert_True(Get_PieceHandle(_PieceId) == _Slice, "the fryer holds the slice from the raw platter");

        FCk_Handle Entity = _Slice;
        Assert_True(Entity.Is_RuntimeMeshDisplay(), "the slice wears its own display");
    }

    // Polled every frame. Passes once a face has heated past k_HeatedPast at a frame where a write has just landed (a slot
    // changed) or the heat has stopped moving: either way the display trails the kernel by at most the write threshold
    // plus a frame. Snapshots both sides for the next step.
    UFUNCTION()
    private void Check_DisplayCaughtUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Slots = Read_Slots();
        const auto Heats = Read_Heats();
        const auto Polled = _PolledSlots.Num() == k_SlotCount;
        const auto Wrote = Polled && Get_LargestChange(_PolledSlots, Slots) > 0.0f;
        const auto Stopped = Polled && Get_LargestChange(_PolledHeats, Heats) == 0.0f;
        _PolledSlots = Slots;
        _PolledHeats = Heats;

        auto Hottest = 0.0f;
        for (const auto& Heat : Heats)
        { Hottest = Math::Max(Hottest, Heat); }

        auto Res = OutResult;
        if (Hottest < k_HeatedPast || (Wrote == false && Stopped == false))
        {
            Res.Set(false);
            return;
        }

        _SnapSlots = Slots;
        _SnapHeats = Heats;
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertDisplayCarriesTheHeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SnapSlots.Num(), k_SlotCount, "the snapshot holds the 13 cook-state slots");
        Assert_Equals_Int(_SnapHeats.Num(), utils_searing::k_FaceCount, "the snapshot holds six face heats");
        if (_SnapSlots.Num() != k_SlotCount || _SnapHeats.Num() != utils_searing::k_FaceCount)
        { return; }

        auto HeatSum = 0.0f;
        auto Hottest = 0;
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        {
            Assert_Equals_Float(_SnapSlots[Face], _SnapHeats[Face], k_DisplayTolerance,
                f"display slot {Face} [{_SnapSlots[Face]}] is the kernel's face heat [{_SnapHeats[Face]}]");
            HeatSum += _SnapHeats[Face];
            if (_SnapHeats[Face] > _SnapHeats[Hottest])
            { Hottest = Face; }
        }

        const auto Fry = HeatSum / float32(utils_searing::k_FaceCount);
        Assert_Equals_Float(_SnapSlots[k_FrySlot], Fry, k_DisplayTolerance,
            f"display slot 10 [{_SnapSlots[k_FrySlot]}] is the batter's fry, the mean heat [{Fry}]");
        Assert_True(_SnapSlots[Hottest] >= k_HeatedPast - k_DisplayTolerance,
            f"the display carries the hottest face's heat [{_SnapSlots[Hottest]}], not the arrival's 0");

        _PolledSlots.Empty();
        _PolledHeats.Empty();
    }

    // Polled every frame for k_WindowFrames frames, each poll compared with the one before.
    UFUNCTION()
    private void Check_EdgeWindow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Slots = Read_Slots();
        const auto Heats = Read_Heats();
        if (_PolledSlots.Num() == k_SlotCount)
        {
            ++_WindowPolls;
            const auto SlotChange = Get_LargestChange(_PolledSlots, Slots);
            if (SlotChange > 0.0f)
            {
                ++_Rewrites;
                if (SlotChange < k_EdgeFloor)
                { ++_OffEdgeRewrites; }
            }
            else if (Get_LargestChange(_PolledHeats, Heats) > 0.0f)
            { ++_HeldWhileHeating; }
        }

        _PolledSlots = Slots;
        _PolledHeats = Heats;

        auto Res = OutResult;
        Res.Set(_WindowPolls >= k_WindowFrames);
    }

    UFUNCTION()
    private void Step_AssertEdgesOnly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ck::Trace(f"[FryStation] over {_WindowPolls} frames: {_Rewrites} display writes, {_OffEdgeRewrites} off an edge, {_HeldWhileHeating} held while heating");
        Assert_Equals_Int(_OffEdgeRewrites, 0, "every change the display showed was a jump of at least the write threshold");
        Assert_True(_HeldWhileHeating > 0, "a frame whose heat moved by less than the threshold shows the same values as the frame before");
    }

    // The 13 cook-state slots of the slice's display (0 until it is Ready).
    private TArray<float32> Read_Slots() const
    {
        FCk_Handle Entity = _Slice;
        const auto Display = Entity.As_RuntimeMeshDisplay();
        auto Slots = TArray<float32>();
        for (int32 Index = 0; Index < k_SlotCount; ++Index)
        { Slots.Add(utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Display, Index)); }

        return Slots;
    }

    private TArray<float32> Read_Heats() const
    {
        auto Heats = TArray<float32>();
        for (int32 Face = 0; Face < utils_searing::k_FaceCount; ++Face)
        { Heats.Add(_Fry.Get_FaceHeat(_PieceId, EMars_Searing_Face(Face))); }

        return Heats;
    }

    // The largest element-wise difference of two equal-length lists.
    private float32 Get_LargestChange(const TArray<float32>& InFrom, const TArray<float32>& InTo) const
    {
        auto Largest = 0.0f;
        for (int32 Index = 0; Index < InFrom.Num() && Index < InTo.Num(); ++Index)
        { Largest = Math::Max(Largest, Math::Abs(InTo[Index] - InFrom[Index])); }

        return Largest;
    }
}
