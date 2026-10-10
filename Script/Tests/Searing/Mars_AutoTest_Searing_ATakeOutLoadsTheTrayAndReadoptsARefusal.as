// The pan lands what a station take-out hands back on the take-out's tray, and takes back what the tray refuses. Two pieces
// seared on every face arrive Ready, and the station's take-out readout lists both. A take-out of up to two onto a tray
// with room for one hands both back (OnPieceTakenOut twice): the first, in admission order, lands on the tray (the tray is
// its holder, its landing record is gone); the tray refuses the second Full and the pan readopts it where it lies (on the
// pan's books again, Ready, the station its holder, no landing record). The summary counts one taken out and the readout
// lists the readopted piece alone.
class UMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_FirstLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_SecondLocal = FVector(8.0, 0.0, 8.0);
    // The tray beside the pan, below it, clear of the parked pieces.
    private const FVector k_TrayLocal = FVector(0.0, 150.0, 60.0);

    private FCk_Handle_Platter _Tray;
    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _SecondId;
    // One entry per OnLoaded and OnLoadRefused of the tray.
    private TArray<FCk_Handle_FoodPiece> _TrayLoaded;
    private TArray<FCk_Handle_FoodPiece> _TrayRefusedPieces;
    private TArray<EMars_Platter_LoadRefusal> _TrayRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(2);
        Build_Tray(InHandle);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("sear both pieces on every face", n"Step_Sear");
        Add_Step_WaitUntil("both cook states are applied", n"Check_Seared", 0, 0);
        Add_Step("release both onto the pan", n"Step_AddBoth");
        Add_Step_WaitUntil("both are Ready on the pan and the readout lists them", n"Check_BothTakeable", k_SlowPolls, 0);
        Add_Step("take out up to two onto the one-piece tray", n"Step_TakeOut");
        Add_Step_WaitUntil("one landed, one was refused and readopted", n"Check_LandedAndReadopted", k_SlowPolls, 0);
        Add_Step_WaitFrames("the readout is rewritten", 2);
        Add_Step("the tray holds the first; the pan holds the second again", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // A one-piece tray standing on a kinematic floor box that rides its root (a platter item's tray body plays that part).
    private void Build_Tray(FCk_Handle InOwner)
    {
        auto Bounds = FMars_Platter_Bounds(FVector2D(15.0, 15.0), 40.0f, 25.0f);
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin + k_TrayLocal), ECk_Replication::DoesNotReplicate);
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
    private void Step_Sear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The default cook state holds the six face sears, raw.
        auto CookState = FMars_FoodPiece_CookState();
        for (int32 Index = 0; Index < CookState.Sear.Num(); ++Index)
        { CookState.Sear[Index] = 1.0f; }

        for (int32 Index = 0; Index < _Pieces.Num(); ++Index)
        {
            auto Piece = _Pieces[Index];
            Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        }
    }

    UFUNCTION()
    private void Check_Seared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeared = true;
        for (const auto& Piece : _Pieces)
        {
            const auto CookState = Piece.Get_CookState();
            if (CookState.Sear.Num() != utils_searing::k_FaceCount)
            {
                AllSeared = false;
                continue;
            }

            for (const auto Sear : CookState.Sear)
            {
                if (Sear < 1.0f)
                { AllSeared = false; }
            }
        }

        auto Res = OutResult;
        Res.Set(AllSeared);
    }

    UFUNCTION()
    private void Step_AddBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstId = AddPieceAt(k_FirstLocal);
        _SecondId = AddPieceAt(k_SecondLocal);
    }

    UFUNCTION()
    private void Check_BothTakeable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 2 && utils_cooking_feed::Get_Takeable(_StationEntity).Num() == 2);
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_PieceStatus(_FirstId) == EMars_Searing_PieceStatus::Ready, "the first piece arrived Ready");
        Assert_True(_Searing.Get_PieceStatus(_SecondId) == EMars_Searing_PieceStatus::Ready, "the second piece arrived Ready");
        const auto Takeable = utils_cooking_feed::Get_Takeable(_StationEntity);
        Assert_True(Takeable.Contains(_Pieces[0]) && Takeable.Contains(_Pieces[1]), "the readout lists both pieces");

        utils_cooking_feed::Request_StationTakeOut(_StationEntity, FMars_Request_StationTakeOut(2, _Tray));
    }

    UFUNCTION()
    private void Check_LandedAndReadopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TrayLoaded.Num() >= 1 && _TrayRefusals.Num() >= 1 && _Searing.Get_HasPiece(_SecondId));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto First = _Pieces[0];
        const auto Second = _Pieces[1];

        Assert_Equals_Int(_TakenOut.Num(), 2, "the take-out handed both back");
        Assert_Equals_Int(_TrayLoaded.Num(), 1, "one landed on the tray");
        if (_TrayLoaded.Num() == 1)
        { Assert_True(_TrayLoaded[0] == First, "the first piece in admission order landed"); }

        Assert_Equals_Int(_TrayRefusals.Num(), 1, "the tray refused one");
        if (_TrayRefusals.Num() == 1)
        {
            Assert_True(_TrayRefusedPieces[0] == Second, "the tray refused the second piece");
            Assert_True(_TrayRefusals[0] == EMars_Platter_LoadRefusal::Full, f"refused Full (got {_TrayRefusals[0] :n})");
        }

        Assert_True(_Tray.Get_Held().Contains(First), "the tray holds the first piece");
        Assert_True(First.TryGet_Holder() == _Tray, "the tray is the first piece's holder");
        Assert_False(First.Has_Fragment(FMars_Fragment_StationLanding), "the first piece's landing record is gone");
        Assert_False(_Searing.Get_HasPiece(_FirstId), "the first piece left the pan's books");

        Assert_True(_Searing.Get_HasPiece(_SecondId), "the second piece is on the pan's books again");
        Assert_True(_Searing.Get_PieceStatus(_SecondId) == EMars_Searing_PieceStatus::Ready, "readopted Ready");
        Assert_True(Second.TryGet_Holder() == _StationEntity, "the station is the second piece's holder again");
        Assert_False(Second.Has_Fragment(FMars_Fragment_StationLanding), "the second piece's landing record is gone");

        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, 1, "the summary counts one taken out");
        const auto Takeable = utils_cooking_feed::Get_Takeable(_StationEntity);
        Assert_Equals_Int(Takeable.Num(), 1, "the readout lists one piece");
        if (Takeable.Num() == 1)
        { Assert_True(Takeable[0] == Second, "the readout lists the readopted piece"); }
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

class AMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_ATakeOutLoadsTheTrayAndReadoptsARefusal;
}
