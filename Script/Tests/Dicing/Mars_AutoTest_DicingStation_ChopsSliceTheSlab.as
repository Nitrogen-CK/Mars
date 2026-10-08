// The real dicing station's meat slab: once the station stands, its tagged slab component carries the joint's two sections
// (flesh, fat cap) built from the baked table. A chop at the board's centre splits the joint: the hosted piece gains a cut
// face section and a sibling procedural mesh appears on its owner; a second chop, with the hand nudged along the board,
// splits again (three pieces). A Reset puts the whole joint back: one piece, no cut face, no siblings.
class UMars_AutoTest_DicingStation_ChopsSliceTheSlab : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(0.0, 0.0, 0.0);
    // cm the hand moves along the board between the two chops (well inside the 36.8 cm joint's half length).
    private const float32 k_SecondChopLateral = 8.0f;
    // Sections of the whole joint and of a cut piece (flesh, fat cap, then the cut face).
    private const int32 k_WholeSections = 2;
    private const int32 k_CutSections = 3;

    private FCk_Handle_EntityScript _Station;
    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_UnrealComponent _SlabPart;
    private int32 _ChopsResolved = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto SpawnParams = UMars_DicingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_DicingStation_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnStationConstructed"));

        Add_Step_WaitUntil("the station composed its Dicing", n"Check_StationReady", 0, 5.0f);
        Add_Step("find the tagged slab part", n"Step_FindSlab");
        Add_Step_WaitUntil("the slab's component exists and holds the whole joint", n"Check_SlabBuilt", 0, 3.0f);
        Add_Step("one piece: the joint's two sections, no siblings", n"Step_AssertWhole");
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the chop resolved", n"Check_OneChop", 0, 2.0f);
        Add_Step("the joint is in two: the hosted piece shows a cut face and a sibling piece exists", n"Step_AssertTwoPieces");
        // A chop requested while the cleaver still recovers from the last is ignored (ChopWhileChoppingIsIgnored).
        Add_Step_WaitSeconds("the cleaver recovers", 0.5f);
        Add_Step("nudge the hand along the board", n"Step_Nudge");
        Add_Step_WaitFrames("the nudge applies", 2);
        Add_Step("chop again", n"Step_Chop2");
        Add_Step_WaitUntil("the second chop resolved", n"Check_TwoChops", 0, 2.0f);
        Add_Step("three pieces", n"Step_AssertThreePieces");
        Add_Step("reset the pile", n"Step_Reset");
        Add_Step_WaitFrames("the reset applies and the slab rebuilds", 3);
        Add_Step("the whole joint is back: one piece, two sections", n"Step_AssertWhole");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        _Station = InEntityScriptHandle;
        _Dicing = InEntityScriptHandle.As_Dicing();
        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        _ChopsResolved += 1;
    }

    UFUNCTION()
    private void Check_StationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Dicing));
    }

    UFUNCTION()
    private void Step_FindSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Slabs = utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsDicingSlab");
        Assert_Equals_Int(Slabs.Num(), 1, "one tagged slab part");
        if (Slabs.Num() == 1)
        { _SlabPart = Slabs[0].As_UnrealComponent(); }
    }

    UFUNCTION()
    private void Check_SlabBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Proc = Get_Slab();
        auto Res = OutResult;
        Res.Set(ck::IsValid(Proc) && Proc.GetNumSections() >= k_WholeSections);
    }

    UFUNCTION()
    private void Step_AssertWhole(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Proc = Get_Slab();
        Assert_True(ck::IsValid(Proc), "the slab's procedural mesh component exists");
        if (ck::Is_NOT_Valid(Proc))
        { return; }

        Assert_Equals_Int(Proc.GetNumSections(), k_WholeSections, "the whole joint: flesh and fat cap, no cut face");
        Assert_Equals_Int(Get_PieceCount(), 1, "one piece on the owner");
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Dicing.Get_HandLateral(), 0.0, 0.01, "the hand starts at the board's centre");
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Check_OneChop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsResolved >= 1);
    }

    UFUNCTION()
    private void Step_AssertTwoPieces(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Proc = Get_Slab();
        Assert_True(ck::IsValid(Proc), "the slab's procedural mesh component exists");
        if (ck::Is_NOT_Valid(Proc))
        { return; }

        Assert_Equals_Int(Proc.GetNumSections(), k_CutSections, "the hosted piece gained its cut face section");
        Assert_Equals_Int(Get_PieceCount(), 2, "two pieces on the owner after one chop");
    }

    UFUNCTION()
    private void Step_Nudge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge(k_SecondChopLateral / _Dicing.Get_Spec().LateralPerDegree));
    }

    UFUNCTION()
    private void Step_Chop2(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Math::Abs(_Dicing.Get_HandLateral() - k_SecondChopLateral) < 0.5,
            f"the hand moved to the second chop (lateral {_Dicing.Get_HandLateral()})");
        _Dicing.Request_Chop(FMars_Request_Dicing_Chop());
    }

    UFUNCTION()
    private void Check_TwoChops(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsResolved >= 2);
    }

    UFUNCTION()
    private void Step_AssertThreePieces(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_PieceCount(), 3, "three pieces on the owner after two chops");
    }

    UFUNCTION()
    private void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Dicing.Request_Reset(FMars_Request_Dicing_Reset());
    }

    // The hosted slab component, null until the Ck host creates it.
    private UProceduralMeshComponent Get_Slab() const
    {
        if (ck::Is_NOT_Valid(_SlabPart))
        { return nullptr; }
        return Cast<UProceduralMeshComponent>(utils_unreal_component::Get_Component(_SlabPart));
    }

    // Every procedural mesh component on the slab's owner: the hosted piece plus the halves the slicing split off.
    private int32 Get_PieceCount() const
    {
        auto Proc = Get_Slab();
        if (ck::Is_NOT_Valid(Proc) || ck::Is_NOT_Valid(Proc.GetOwner()))
        { return 0; }

        TArray<UActorComponent> Components;
        Proc.GetOwner().GetAllComponents(UProceduralMeshComponent, Components);
        return Components.Num();
    }
}
