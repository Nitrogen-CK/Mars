// The batter rig: a Batter kernel on a transform-only root at an isolated origin, its bowl node k_BowlLocal above the root.
// No meshes and no floor. The rig is the operator and the test feed: it dips and lifts, and Admit releases built piece
// Slot as piece {1, Slot} into the station's admission inbox, as the feed does. Pieces are the cooking kernels'
// parked boxes (UMars_AutoTestRig_CookingKernel): Build_FoodPieces makes whole pieces of a food, Build_BatteredPieces the
// same with a battered ledger. A take-out lands on a World-mode platter the
// heat-station fixture lays on a floor beside the station (Spawn_Tray). The handlers record every signal, the station's
// admission answers included.
UCLASS(Abstract)
class UMars_AutoTestRig_Batter : UMars_AutoTestRig_CookingKernel
{
    default _TimeoutSeconds = 20.0f;

    protected const FVector k_Origin = FVector(-60000.0, 58000.0, -60000.0);
    protected const FVector k_BowlLocal = FVector(0.0, 0.0, 90.0);
    // Where the tray's floor lies, clear of the bowl.
    protected const FVector k_TrayLocal = FVector(0.0, 300.0, 0.0);
    protected const float k_PieceMassKg = 0.08;
    // A short coat so a test fills it within its time; a dip that takes a few frames.
    protected const float32 k_CoatSeconds = 0.5f;
    protected const float32 k_DipSeconds = 0.1f;

    protected FCk_Handle_Batter _Batter;
    // The spec the station was built from, nodes included.
    protected FMars_Batter_Spec _Spec;
    protected FCk_Handle_Transform _BowlNode;
    protected UMars_AutoTestHelper_HeatStation _Fixture;

    // One entry per signal, in order (parallel arrays where a signal carries more than one value). Piece Slot of _Pieces is
    // released as {k_Generation, Slot}.
    protected TArray<FMars_CookingFeed_PieceId> _RefusedIds;
    protected TArray<EMars_Batter_AdmissionRefusal> _Refusals;
    protected TArray<EMars_Batter_Bowl> _Bowls;
    protected TArray<FMars_CookingFeed_PieceId> _StageIds;
    protected TArray<EMars_Batter_CoatStage> _Stages;
    protected TArray<FCk_Handle_FoodPiece> _TakenOut;
    protected TArray<EMars_Batter_TakeOutRefusal> _TakeOutRefusals;

    protected FMars_Batter_Spec Make_TestSpec() const
    {
        auto Spec = FMars_Batter_Spec();
        Spec.Coat.CoatSeconds = k_CoatSeconds;
        Spec.Coat.DipSeconds = k_DipSeconds;
        return Spec;
    }

    protected void BuildStation(FCk_Handle InHandle, FMars_Batter_Spec InSpec)
    {
        _Spec = InSpec;

        auto Root = Create_StationRoot(InHandle, k_Origin);
        _BowlNode = utils_scene_node::Create(Root, FTransform(k_BowlLocal)).As_Transform();

        _Spec.Nodes = FMars_Batter_Nodes(_BowlNode);
        _Batter = utils_batter::Add(_StationEntity, _Spec);

        _Batter.BindTo_OnPieceAdded(FMars_Delegate_Batter_OnPieceAdded(this, n"OnPieceAdded"));
        _Batter.BindTo_OnAdmissionRefused(FMars_Delegate_Batter_OnAdmissionRefused(this, n"OnAdmissionRefused"));
        _Batter.BindTo_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBowlChanged"));
        _Batter.BindTo_OnCoatStage(FMars_Delegate_Batter_OnCoatStage(this, n"OnCoatStage"));
        _Batter.BindTo_OnPieceTakenOut(FMars_Delegate_Batter_OnPieceTakenOut(this, n"OnPieceTakenOut"));
        _Batter.BindTo_OnTakeOutRefused(FMars_Delegate_Batter_OnTakeOutRefused(this, n"OnTakeOutRefused"));
    }

    // InCount whole box pieces of InFood, parked in a row beside the station; each is Ready once its import resolves.
    protected void Build_FoodPieces(int32 InCount, UMars_Food_Def InFood)
    {
        for (int32 Index = 0; Index < InCount; ++Index)
        { Build_ParkedPiece(Make_FoodSpec(k_PieceMassKg, InFood)); }
    }

    // Build_FoodPieces, each arriving with a battered ledger.
    protected void Build_BatteredPieces(int32 InCount, UMars_Food_Def InFood)
    {
        for (int32 Index = 0; Index < InCount; ++Index)
        {
            auto Spec = Make_FoodSpec(k_PieceMassKg, InFood);
            Spec.Data.CookState.Battered = 1.0f;
            Build_ParkedPiece(Spec);
        }
    }

    // An empty platter on a floor beside the station; constructed when Get_IsTrayReady says so.
    protected FCk_Handle Spawn_Tray(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(_Fixture))
        { _Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation)); }

        return _Fixture.Spawn_EmptyPlatter(InHandle, k_Origin + k_TrayLocal, mars_items::Platter());
    }

    protected bool Get_IsTrayReady(FCk_Handle InTray, int32 InHeld) const
    {
        return ck::IsValid(_Fixture) && _Fixture.Get_IsPlatterReady(InTray, InHeld);
    }

    // Piece InSlot released at rest over the bowl as piece {k_Generation, InSlot}.
    protected FMars_CookingFeed_PieceId Admit(int32 InSlot)
    {
        return Admit_Piece(InSlot, _Pieces[InSlot]);
    }

    // InPiece released at rest over the bowl as piece {k_Generation, InSlot}.
    protected FMars_CookingFeed_PieceId Admit_Piece(int32 InSlot, FCk_Handle_FoodPiece InPiece)
    {
        const auto PieceId = FMars_CookingFeed_PieceId(k_Generation, InSlot);
        auto Release = FMars_CookingFeed_Release(PieceId, FTransform(_Batter.Get_BowlWorld().GetLocation() + FVector(0.0, 0.0, 30.0)), FVector::ZeroVector);
        Release.Piece = InPiece;
        auto Station = _StationEntity;
        utils_cooking_feed::Request_Admit(Station, Release);
        return PieceId;
    }

    protected FMars_CookingFeed_PieceId Make_Id(int32 InSlot) const
    {
        return FMars_CookingFeed_PieceId(k_Generation, InSlot);
    }

    protected void Dip()
    {
        _Batter.Request_Dip(FMars_Request_Batter_Dip());
    }

    protected void Lift()
    {
        _Batter.Request_Lift(FMars_Request_Batter_Lift());
    }

    // A take-out onto InTray (invalid = none) with room for InMaxPieces.
    protected void TakeOut(FCk_Handle_Platter InTray, int32 InMaxPieces)
    {
        auto Station = _StationEntity;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(InMaxPieces, InTray));
    }

    protected int32 Count_Stages(const FMars_CookingFeed_PieceId& InPieceId, EMars_Batter_CoatStage InStage) const
    {
        auto Count = 0;
        for (int32 Index = 0; Index < _StageIds.Num(); ++Index)
        {
            if (_StageIds[Index].Get_IsSame(InPieceId) && _Stages[Index] == InStage)
            { Count += 1; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnPieceAdded(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _AddedIds.Add(InPieceId);
    }

    UFUNCTION()
    protected void OnAdmissionRefused(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal)
    {
        _RefusedIds.Add(InPieceId);
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    protected void OnBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl)
    {
        _Bowls.Add(InBowl);
    }

    UFUNCTION()
    protected void OnCoatStage(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_CoatStage InStage)
    {
        _StageIds.Add(InPieceId);
        _Stages.Add(InStage);
    }

    UFUNCTION()
    protected void OnPieceTakenOut(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }

    UFUNCTION()
    protected void OnTakeOutRefused(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal)
    {
        _TakeOutRefusals.Add(InRefusal);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Answered1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    protected void Step_Dip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dip();
    }

    UFUNCTION()
    protected void Step_Lift(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Lift();
    }

    // The first piece's coat is complete.
    UFUNCTION()
    protected void Check_FirstCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_HasPiece(Make_Id(0)) && _Batter.Get_PieceCoat(Make_Id(0)) >= 1.0f);
    }

    // The first piece has risen back to rest.
    UFUNCTION()
    protected void Check_FirstAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_HasPiece(Make_Id(0)) && _Batter.Get_PieceImmersion(Make_Id(0)) <= 0.0f);
    }
}
