// A coated piece the tray refuses goes back into the bowl and is announced again. Two whole batterable pieces are
// admitted, dipped until both coats complete and lifted back to rest. A take-out of up to two onto a tray with room for
// one hands both back: the first, in admission order, lands on the tray (its holder); the tray refuses the second Full and
// the bowl readopts it: in the bowl under its own id, fully coated, at rest, the bowl its holder, its landing record gone,
// and OnPieceAdded fires for it a second time (the admission's, then the readopt's). The readout lists it again.
// The pickup's Ledger claim is not observed: rig pieces are no world items, so the claim requests are no-ops on them.
class UMars_AutoTest_Batter_ATakeOutRefusedByTheTrayIsReadopted : UMars_AutoTestRig_Batter
{
    // The one-piece tray beside the bowl, clear of the parked pieces.
    private const FVector k_OnePieceTrayLocal = FVector(0.0, 150.0, 60.0);

    private FCk_Handle_Platter _Tray;
    // One entry per OnLoaded and OnLoadRefused of the tray.
    private TArray<FCk_Handle_FoodPiece> _TrayLoaded;
    private TArray<FCk_Handle_FoodPiece> _TrayRefusedPieces;
    private TArray<EMars_Platter_LoadRefusal> _TrayRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(2, mars::Food_TestBatterableBox_Mars);
        Build_OnePieceTray(InHandle);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release both pieces", n"Step_AdmitBoth");
        Add_Step_WaitUntil("both are in the bowl", n"Check_BothAdmitted", 0, 0);
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("both coats complete", n"Check_BothCoated", k_SlowPolls, 0);
        Add_Step("lift", n"Step_Lift");
        Add_Step_WaitUntil("both rose back to rest and the readout lists them", n"Check_BothTakeable", k_SlowPolls, 0);
        Add_Step("take out up to two onto the one-piece tray", n"Step_TakeOut");
        Add_Step_WaitUntil("one landed, one was refused and is back in the bowl", n"Check_LandedAndReadopted", k_SlowPolls, 0);
        Add_Step_WaitFrames("the readout is rewritten", 2);
        Add_Step("the tray holds the first; the bowl holds the second again and announced it", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // A one-piece tray standing on a kinematic floor box that rides its root (a platter item's tray body plays that part).
    private void Build_OnePieceTray(FCk_Handle InOwner)
    {
        auto Bounds = FMars_Platter_Bounds(FVector2D(15.0, 15.0), 40.0f, 25.0f);
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin + k_OnePieceTrayLocal), ECk_Replication::DoesNotReplicate);
        auto FloorNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -1.0)));

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(Bounds.InnerHalfExtents.X + 5.0, Bounds.InnerHalfExtents.Y + 5.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Kinematic);
        FloorSpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        FloorSpec.Set_MassKg(1.0f);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(FloorNode.H(), FloorSpec);

        _Tray = utils_platter::Add(Entity, FMars_Platter_Spec(1, Bounds));
        _Tray.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        _Tray.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnTrayLoadRefused"));
    }

    UFUNCTION()
    private void Step_AdmitBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
        Admit(1);
    }

    UFUNCTION()
    private void Check_BothAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() >= 2);
    }

    UFUNCTION()
    private void Check_BothCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_PieceCoat(Make_Id(0)) >= 1.0f && _Batter.Get_PieceCoat(Make_Id(1)) >= 1.0f);
    }

    UFUNCTION()
    private void Check_BothTakeable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_cooking_feed::Get_Takeable(_StationEntity).Num() == 2);
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_AddedIds.Num(), 2, "the admissions announced both pieces once");
        TakeOut(_Tray, 2);
    }

    UFUNCTION()
    private void Check_LandedAndReadopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TrayLoaded.Num() >= 1 && _TrayRefusals.Num() >= 1 && _Batter.Get_HasPiece(Make_Id(1)));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto First = _Pieces[0];
        const auto Second = _Pieces[1];

        Assert_Equals_Int(_TakenOut.Num(), 2, "the take-out handed both back");
        Assert_True(_TrayLoaded.Num() == 1 && _TrayLoaded[0] == First, "the first piece in admission order landed on the tray");
        Assert_True(_TrayRefusals.Num() == 1 && _TrayRefusedPieces[0] == Second && _TrayRefusals[0] == EMars_Platter_LoadRefusal::Full,
            "the tray refused the second piece Full");
        Assert_True(First.TryGet_Holder() == _Tray, "the tray is the first piece's holder");
        Assert_False(_Batter.Get_HasPiece(Make_Id(0)), "the first piece left the bowl");

        Assert_True(_Batter.Get_HasPiece(Make_Id(1)) && _Batter.Get_PieceHandle(Make_Id(1)) == Second, "the second piece is back under its own id");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 1, "one piece in the bowl");
        Assert_Equals_Float(_Batter.Get_PieceCoat(Make_Id(1)), 1.0, 0.0, "fully coated");
        Assert_Equals_Float(_Batter.Get_PieceImmersion(Make_Id(1)), 0.0, 0.0, "at rest");
        Assert_True(Second.TryGet_Holder() == _StationEntity, "the bowl is its holder again");
        Assert_False(Second.Has_Fragment(FMars_Fragment_StationLanding), "its landing record is gone");

        Assert_Equals_Int(_AddedIds.Num(), 3, "OnPieceAdded fired three times: two admissions and the readopt");
        if (_AddedIds.Num() == 3)
        { Assert_True(_AddedIds[2].Get_IsSame(Make_Id(1)), "the third OnPieceAdded names the readopted id"); }

        Assert_Equals_Int(_Admissions.Num(), 2, "the readopt sends no admission answer");
        const auto Takeable = utils_cooking_feed::Get_Takeable(_StationEntity);
        Assert_True(Takeable.Num() == 1 && Takeable[0] == Second, "the readout lists the readopted piece alone");
    }

    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        _TrayLoaded.Add(InPiece);
    }

    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        _TrayRefusedPieces.Add(InPiece);
        _TrayRefusals.Add(InRefusal);
    }
}
