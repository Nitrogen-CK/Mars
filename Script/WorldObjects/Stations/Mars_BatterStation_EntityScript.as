// The batter station: a counter (depth along local X, width along local Y; the operator at -X, +Y their right) with a
// stone batter bowl on its centre (PrepBowl_Mars_SM scaled up, a pale batter surface inside it), the raw platter's dock on
// the LEFT and the finished tray's dock on the RIGHT. The bowl node (the kernel's, at the bowl's inner floor centre) is
// where the Batter kernel seats every whole, batterable, unbattered piece it admits; while the operator holds the dip the
// kernel sinks the pieces under the batter and runs their coat clocks, and a take-out writes each fully coated piece's
// ledger battered and lands it on the docked finished tray. The Batter feature lives on the station entity and its own
// state machine (UMars_SmState_Batter_Idle) reads the operator. A CookingFeed on the same entity draws the pieces of the
// docked raw platter: its station-feed tasks turn the operator's add-food press into a left-hand transfer whose release
// over the bowl lands in the station's admission inbox. The base builds the feed's nodes and the docks and keeps the label;
// this script builds the bowl and, every frame, dresses every piece (the wet batter's sheen as its coat grows, then its
// food's battered shell once its ledger says battered, through Write_Look) and lowers the right glove with the dip.

// A piece a take-out handed back, waiting for its ledger's dip to dress its battered shell.
struct FMars_BatterStation_Departing
{
    FMars_Station_PieceDisplay Display;

    // Frames waited so far.
    int32 Frames = 0;
}

class UMars_BatterStation_EntityScript : UMars_FeedStation_EntityScript
{
    default _ShowInPlaceActors = true;

    // A cut piece never docks as raw: the bowl takes full ingredients only (the kernel refuses the rest by name).
    default Docks.Input.WholeOnly = true;

    // The bowl's coat and dip timing; its slot geometry and Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Batter_Spec Batter;

    // cm, in the station frame (the root; Z 0 is the floor).
    private const float64 CounterWidth = 230.0;
    private const float64 CounterDepth = 110.0;
    private const float64 CounterHeight = constants_station::k_CounterHeight;

    // PrepBowl_Mars_SM (station_spec.py): 30 across, 12 tall, inner radius 12.5 at the rim, rim 9 above its pivot (the inner
    // floor centre), base 3 below it. Scaled BowlScale it holds whole prep foods: 60 across, inner radius 25, 18 deep.
    private const float64 BowlScale = 2.0;
    private const float64 BowlMeshBaseBelowPivot = 3.0;
    private const float64 BowlMeshInnerRadius = 12.5;
    private const float64 BowlMeshRimAbovePivot = 9.0;
    // The batter fills the bowl to BatterDepth over the inner floor: a flat pale disc there (radius a little inside the wall
    // at that height).
    private const float64 BatterDepth = 12.0;
    private const float64 BatterDiscRadiusFraction = 0.9;
    private const float64 BatterDiscThickness = 0.4;
    // The slots: three round a ring of SlotRadius; a piece's middle rests RestAbove the batter and sinks DipDepth when dipped
    // (a 10 cm-tall piece then lies just under the surface).
    private const int32 BowlCapacity = 3;
    private const float32 SlotRadius = 11.0f;
    private const float32 RestAbove = 9.0f;
    private const float32 DipDepth = 15.0f;
    // The feed lets a carried piece go ReleaseAboveRim over the bowl's middle.
    private const float64 ReleaseAboveRim = 14.0;

    // The right glove's dipper grip: over the bowl's right rim, GripAboveRim up; the dressing lowers it by the deepest
    // piece's immersion times DipDepth, so the glove pushes the batch under.
    private const float64 GripAboveRim = 8.0;
    private const float64 GripInFromRim = 6.0;

    // The operating view, pitched onto the batter from ViewDistance back along the CameraPitch line (station frame).
    private const float32 CameraPitch = -52.0f;
    private const float64 ViewDistance = 135.0;

    // The raw platter's dock on the left, the finished tray's on the right; the left glove rests in front of the raw one.
    private const FVector InputDockLocal = FVector(0.0, -80.0, 0.0);
    private const FVector OutputDockLocal = FVector(0.0, 80.0, 0.0);
    private const FVector FeedRestFromPlatter = FVector(-32.0, -2.0, 0.0);

    // The label over the bowl's far rim, facing the operator.
    private const float64 LabelBack = 34.0;
    private const float64 LabelHeight = 16.0;
    private const float32 LabelWorldSize = 7.0f;

    // A taken-out piece's record waits at most this many frames for its ledger to say battered before it is dropped.
    private const int32 DepartFrames = 30;

    private const FLinearColor k_BatterColor = FLinearColor(0.93f, 0.84f, 0.62f, 1.0f);

    // Batter as exposed, with the slot geometry and the node set (Prepare_Kernel, Compose_Kernel); what the feature and the
    // visuals read.
    private FMars_Batter_Spec _BatterSpec;
    private FCk_Handle_Batter _BatterHandle;
    // The kernel's bowl node: the inner floor centre.
    private FCk_Handle_SceneNode _BowlNode;
    // The right glove's grip (Station.Node.Tool) at its rest offset.
    private FCk_Handle_SceneNode _DipperNode;
    private FTransform _DipperRest;
    // Pieces a take-out handed back, waiting for their ledger's dip to dress their battered shell.
    private TArray<FMars_BatterStation_Departing> _Departing;

    protected void Prepare_Kernel() override
    {
        // Before the base: its AddVisuals places the bowl node and the release from it. The slot ring, the rest height and
        // the dip are this station's geometry, so the exposed spec cannot set them.
        _BatterSpec = Batter;
        _BatterSpec.Bowl.Capacity = BowlCapacity;
        _BatterSpec.Bowl.SlotRadius = SlotRadius;
        _BatterSpec.Bowl.RestZ = float32(BatterDepth) + RestAbove;
        _BatterSpec.Bowl.DipDepthCm = DipDepth;
    }

    // A rejected Batter spec already ensured (utils_batter::Add): the station stands with nothing to batter in.
    protected bool Compose_Kernel(FCk_Handle& InHandle) override
    {
        _BatterSpec.Nodes = FMars_Batter_Nodes(_BowlNode.As_Transform());
        _BatterHandle = utils_batter::Add(InHandle, _BatterSpec);
        if (ck::Is_NOT_Valid(_BatterHandle))
        { return false; }

        _BatterHandle.BindTo_OnPieceAdded(FMars_Delegate_Batter_OnPieceAdded(this, n"OnPieceAdded"));
        _BatterHandle.BindTo_OnPieceTakenOut(FMars_Delegate_Batter_OnPieceTakenOut(this, n"OnPieceTakenOut"));
        _BatterHandle.BindTo_OnAdmissionRefused(FMars_Delegate_Batter_OnAdmissionRefused(this, n"OnAdmissionRefused"));
        _BatterHandle.BindTo_OnTakeOutRefused(FMars_Delegate_Batter_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        return true;
    }

    // Every part is a hosted component: it dies with its entity.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_BatterHandle))
        {
            _BatterHandle.UnbindFrom_OnPieceAdded(FMars_Delegate_Batter_OnPieceAdded(this, n"OnPieceAdded"));
            _BatterHandle.UnbindFrom_OnPieceTakenOut(FMars_Delegate_Batter_OnPieceTakenOut(this, n"OnPieceTakenOut"));
            _BatterHandle.UnbindFrom_OnAdmissionRefused(FMars_Delegate_Batter_OnAdmissionRefused(this, n"OnAdmissionRefused"));
            _BatterHandle.UnbindFrom_OnTakeOutRefused(FMars_Delegate_Batter_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        }

        // The pieces wear their own displays; only the records go.
        _Departing.Empty();

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The dipper node carries the right glove, open over the bowl's right rim; the dressing lowers it with the dip.
    protected void Configure_Operation(FMars_Station_Spec& InOutSpec) override
    {
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(Make_NodeGrip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, EMars_HandGripPose::Open));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera = Make_CapturedCamera(FVector(0.0, 0.0, Get_BowlPivotZ() + BatterDepth), CameraPitch, ViewDistance);
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "BatterBatchPrompt", "Batter the batch"),
            NSLOCTEXT("MarsInteraction", "BatterStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Batter_Idle;
    }

    protected FVector2D Get_CounterFootprint() const override
    {
        return FVector2D(CounterDepth, CounterWidth);
    }

    // Engine cube and cylinder are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, CounterHeight * 0.5), FVector(CounterDepth, CounterWidth, CounterHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"BatterStation_Counter"));

        AddBowl(InRoot);
        AddDipper(InRoot);

        // The left glove rests in front of the raw platter's dock; the docked raw platter is the stock's only visual.
        Add_FeedHand(FVector(InputDockLocal.X + FeedRestFromPlatter.X, InputDockLocal.Y + FeedRestFromPlatter.Y, CounterHeight));

        _ReleaseNode = utils_scene_node::Create(InRoot,
            FTransform(FVector(0.0, 0.0, Get_BowlRimZ() + ReleaseAboveRim))).As_Transform();

        AddLabel(FTransform(FRotator(0.0, 180.0, 0.0), FVector(LabelBack, 0.0, Get_BowlRimZ() + LabelHeight)),
            EVerticalTextAligment::EVRTA_TextCenter, n"BatterStation_Label");
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _DipperNode.As_Transform()));
        Super::Register_GripNodes(OutNodes);
    }

    protected FMars_FeedStation_DockLayout Get_DockLayout() const override
    {
        auto Layout = FMars_FeedStation_DockLayout();
        Layout.Input = FMars_FeedStation_DockSpot(InputDockLocal, FText::FromString("raw platter"), n"BatterStation_InputDockMarker");
        Layout.Output = FMars_FeedStation_DockSpot(OutputDockLocal, FText::FromString("finished tray"), n"BatterStation_OutputDockMarker");
        return Layout;
    }

    protected float32 Get_LabelWorldSize() const override
    {
        return LabelWorldSize;
    }

    // Why the bowl would not take a piece now (the add-food press's gate, the kernel's load refusal).
    protected FString Get_StationGateText() const override
    {
        if (ck::Is_NOT_Valid(_BatterHandle))
        { return "station busy"; }

        const auto Refusal = _BatterHandle.TryGet_LoadRefusal();
        if (Refusal == EMars_Batter_LoadRefusal::Full)
        { return "bowl full"; }

        if (Refusal == EMars_Batter_LoadRefusal::TransferInFlight)
        { return "wait for the piece"; }

        return "station busy";
    }

    // The stone bowl (scaled PrepBowl), the kernel's bowl node at its inner floor centre and the batter's pale surface.
    private void AddBowl(FCk_Handle_Transform& InRoot)
    {
        const auto PivotZ = Get_BowlPivotZ();
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotZ), FVector(BowlScale, BowlScale, BowlScale)),
            assets::load::PrepBowl_Mars_SM(), nullptr, collision::profile::NoCollision, n"BatterStation_Bowl"));

        _BowlNode = utils_scene_node::Create(InRoot, FTransform(FVector(0.0, 0.0, PivotZ)));

        const auto DiscRadius = BowlMeshInnerRadius * BowlScale * BatterDiscRadiusFraction;
        auto Surface = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotZ + BatterDepth),
                FVector(DiscRadius * 0.02, DiscRadius * 0.02, BatterDiscThickness * 0.01)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"BatterStation_BatterSurface");
        Surface.PrimaryColor = TOptional<FLinearColor>(k_BatterColor);
        Surface.Tint = EMars_MeshPart_Tint::ProtoGrid;
        Surface.CastShadow = false;
        InRoot.Add_MeshPart(this, Surface);
    }

    // The right glove's grip over the bowl's right rim: palm down, fingers toward the bowl's middle (-Y).
    private void AddDipper(FCk_Handle_Transform& InRoot)
    {
        const auto RimY = BowlMeshInnerRadius * BowlScale - GripInFromRim;
        _DipperRest = FTransform(utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::RightVector, -FVector::UpVector),
            FVector(0.0, RimY, Get_BowlRimZ() + GripAboveRim));
        _DipperNode = utils_scene_node::Create(InRoot, _DipperRest);
    }

    // The bowl's inner floor centre (the mesh pivot), station frame Z.
    private float64 Get_BowlPivotZ() const
    {
        return CounterHeight + BowlMeshBaseBelowPivot * BowlScale;
    }

    private float64 Get_BowlRimZ() const
    {
        return Get_BowlPivotZ() + BowlMeshRimAbovePivot * BowlScale;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Batter feature and the feed are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // After the base wrote the pieces' looks and before it refreshes the label.
    protected void Dress(float32 InDeltaSeconds) override
    {
        if (ck::Is_NOT_Valid(_BatterHandle))
        { return; }

        Advance_Departing();
        Apply_DipperPose();
    }

    protected bool Get_HoldsPiece(const FMars_CookingFeed_PieceId& InPieceId) const override
    {
        return ck::IsValid(_BatterHandle) && _BatterHandle.Get_HasPiece(InPieceId);
    }

    // The ledger's look (utils_cookstate::Make_DisplayParams) with the wet batter's sheen (the oil-coat slot) at its coat so
    // far: the dip reads on the raw display as it coats.
    protected FMars_CookState Make_PieceLook(const FMars_Station_PieceDisplay& InRecord, float32 InDeltaSeconds) const override
    {
        auto Look = utils_cookstate::Make_DisplayParams(InRecord.Piece.Get_CookState());
        Look.OilCoat = _BatterHandle.Get_PieceCoat(InRecord.Id);
        return Look;
    }

    // A taken-out piece's ledger turns battered a drain after its take-out: its look is written from the ledger then (the
    // battered shell appears, the display hides), once; a record whose entity is gone or whose ledger never says battered
    // within DepartFrames is dropped.
    private void Advance_Departing()
    {
        for (int32 Index = _Departing.Num() - 1; Index >= 0; --Index)
        {
            auto Departing = _Departing[Index];
            Departing.Frames += 1;
            const auto Piece = Departing.Display.Piece;
            const auto IsGone = ck::Is_NOT_Valid(Departing.Display.Entity) || ck::Is_NOT_Valid(Piece);
            const auto IsBattered = IsGone == false && utils_batter::Get_IsBattered(Piece.Get_CookState());
            if (IsBattered)
            { Piece.Write_Look(utils_cookstate::Make_DisplayParams(Piece.Get_CookState())); }
            else if (IsGone == false && Departing.Frames < DepartFrames)
            {
                _Departing[Index] = Departing;
                continue;
            }

            _Departing.RemoveAt(Index);
        }
    }

    // The dipper follows the deepest piece down (its offset written only when it moves).
    private void Apply_DipperPose()
    {
        if (ck::Is_NOT_Valid(_DipperNode))
        { return; }

        auto Deepest = 0.0f;
        for (const auto& Id : _BatterHandle.Get_PieceIds())
        { Deepest = Math::Max(Deepest, _BatterHandle.Get_PieceImmersion(Id)); }

        auto Offset = _DipperRest;
        Offset.SetLocation(_DipperRest.GetLocation() - FVector(0.0, 0.0, float64(DipDepth) * float64(Deepest)));
        if ((utils_scene_node::Get_Offset(_DipperNode).GetLocation() - Offset.GetLocation()).Size() <= 0.01)
        { return; }

        utils_scene_node::Request_UpdateOffset(_DipperNode, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The label
    //----------------------------------------------------------------------------------------------------------------------

    // What the label reads: how many pieces are in, the batch's mean coat and how many are ready. A station whose bowl was
    // not built says so.
    protected FText Get_StateLabel() const override
    {
        if (ck::Is_NOT_Valid(_BatterHandle))
        { return FText::FromString("batter bowl not built"); }

        const auto Ids = _BatterHandle.Get_PieceIds();
        auto CoatSum = 0.0f;
        for (const auto& Id : Ids)
        { CoatSum += _BatterHandle.Get_PieceCoat(Id); }

        const auto MeanPercent = Ids.Num() > 0 ? Math::RoundToInt(100.0f * CoatSum / float32(Ids.Num())) : 0;
        const FString Dip = _BatterHandle.Get_Bowl() == EMars_Batter_Bowl::Dipped ? " - dipping" : "";
        return FText::FromString(f"{Ids.Num()} in - coat {MeanPercent}% - {_BatterHandle.Get_CoatedCount()} ready{Dip}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's record: the piece wears its own display, and its look starts as the piece arrived.
    UFUNCTION()
    private void OnPieceAdded(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Add_PieceRecord(InPieceId, InPiece);
    }

    // The piece leaves the bowl battered: its record waits for the ledger's dip to dress its shell.
    UFUNCTION()
    private void OnPieceTakenOut(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        const auto Record = TryTake_PieceRecord(InPieceId);
        if (Record.IsSet() == false)
        { return; }

        auto Departing = FMars_BatterStation_Departing();
        Departing.Display = Record.GetValue();
        _Departing.Add(Departing);
    }

    // The piece went back to the raw platter: the label says why.
    UFUNCTION()
    private void OnAdmissionRefused(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal)
    {
        Flash_Refusal(Get_AdmissionRefusalText(InRefusal));
    }

    UFUNCTION()
    private void OnTakeOutRefused(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal)
    {
        if (InRefusal == EMars_Batter_TakeOutRefusal::NoRoom)
        {
            Flash_Refusal(Get_NoRoomText());
            return;
        }

        if (InRefusal == EMars_Batter_TakeOutRefusal::Empty)
        {
            Flash_Refusal("nothing in the bowl");
            return;
        }

        if (InRefusal == EMars_Batter_TakeOutRefusal::StillInTheBatter)
        {
            Flash_Refusal("lift it out first");
            return;
        }

        Flash_Refusal("still coating: keep dipping");
    }

    private FString Get_AdmissionRefusalText(EMars_Batter_AdmissionRefusal InRefusal) const
    {
        if (InRefusal == EMars_Batter_AdmissionRefusal::NotWhole)
        { return "whole ingredients only"; }

        if (InRefusal == EMars_Batter_AdmissionRefusal::NotBatterable)
        { return "that does not take batter"; }

        if (InRefusal == EMars_Batter_AdmissionRefusal::AlreadyBattered)
        { return "already battered"; }

        if (InRefusal == EMars_Batter_AdmissionRefusal::Full)
        { return "bowl full"; }

        return "not now";
    }
}
