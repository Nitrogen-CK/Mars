namespace constants_station
{
    // A carried piece's nominal half extent: the feed's glove holds a piece's middle this far under its palm.
    const float64 k_CarriedHalfExtent = 6.0;
}

// The station's record of one piece its kernel admitted. The piece wears its own display (or, battered, its food's battered
// shell: Write_Look); the station adds no part of its own to it.
struct FMars_Station_PieceDisplay
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // This piece's look; a frozen (lost) piece keeps its last one.
    UPROPERTY()
    FMars_CookState CookState;

    // The look last sent to the piece's display.
    UPROPERTY()
    FMars_CookState Written;

    FMars_Station_PieceDisplay() {}

    // InPiece's record, its look as its ledger says it arrived (utils_cookstate::Make_DisplayParams; Jolt owns its pose).
    FMars_Station_PieceDisplay(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        Id = InPieceId;
        Entity = InPiece;
        Piece = InPiece.As_FoodPiece();
        CookState = utils_cookstate::Make_DisplayParams(Piece.Get_CookState());
    }
}

// The display follows the look on its edges, never per frame: a write once any float has moved by the threshold since the
// last one.
mixin void Write(FMars_Station_PieceDisplay& Self)
{
    if (utils_cookstate::Get_HasMovedBeyond(Self.Written, Self.CookState, constants_cookstate::k_WriteThreshold))
    { Self.Write_Now(); }
}

// A piece without a display (a bare test piece) is legal and gets none.
mixin void Write_Now(FMars_Station_PieceDisplay& Self)
{
    if (Self.Piece.Write_Look(Self.CookState))
    { Self.Written = Self.CookState; }
}

// One dock on the counter top: SurfaceLocal in the station frame (Z above the top: 0 rests on it), what its prompt calls it,
// its prompt's reason when its Kind query refuses a piece (empty: the dock's own) and its marker's name.
struct FMars_FeedStation_DockSpot
{
    FVector SurfaceLocal = FVector::ZeroVector;
    FText Name;
    FText KindRejectedText;
    FName MarkerName;

    FMars_FeedStation_DockSpot() {}

    FMars_FeedStation_DockSpot(FVector InSurfaceLocal, FText InName, FName InMarkerName)
    {
        SurfaceLocal = InSurfaceLocal;
        Name = InName;
        MarkerName = InMarkerName;
    }
}

// The input platter's dock and the finished tray's.
struct FMars_FeedStation_DockLayout
{
    FMars_FeedStation_DockSpot Input;
    FMars_FeedStation_DockSpot Output;
}

// What each of a station's two docks lets a platter bring: the input platter it draws from and the finished tray it fills.
struct FMars_Station_DockPolicies
{
    UPROPERTY()
    FMars_PlatterDock_Policy Input;

    UPROPERTY()
    FMars_PlatterDock_Policy Output;
}

// The base of a counter station whose entity carries a CookingFeed beside its own kernel (the searing, fry, cutting,
// tumbler and batter stations). After the kernel it composes the feed (its release node, its glove's hand node and the
// hand geometry the feed moves that node by, Add_FeedHand) and the two docks (Get_DockLayout) with their markers; every
// frame it poses the left glove (the feed's pose override) and writes every admitted piece's look (Add_PieceRecord on the
// kernel's OnPieceAdded; the station says how the look follows its kernel: Get_HoldsPiece, Get_IsPieceFrozen,
// Make_PieceLook). Where the station's food goes is its kernels': the feed hands each release to the station's admission
// inbox, and the kernel loads what it hands back onto the tray and takes back what the tray refuses. The label (the counter
// base's) also flashes the feed's refusals and let-go pieces and the docks' failed interactions.
UCLASS(Abstract)
class UMars_FeedStation_EntityScript : UMars_CounterStation_EntityScript
{
    // The transfer's timing and release motion; its nodes and its held offset are set here. The stock is the platter docked
    // on the input dock.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    // The input platter's and the finished tray's dock policies; each station sets its own defaults.
    UPROPERTY(EditDefaultsOnly, Category = "Docks")
    FMars_Station_DockPolicies Docks;

    protected FCk_Handle_CookingFeed _FeedHandle;
    // Where the feed's glove lets a carried piece go (the station builds it in AddVisuals).
    protected FCk_Handle_Transform _ReleaseNode;

    // The left glove's grip (Station.Node.Feed): the feed moves it through each transfer by _FeedHandGeometry and carries its
    // piece under it.
    private FCk_Handle_SceneNode _FeedHandNode;
    private FMars_CookingFeed_HandGeometry _FeedHandGeometry;
    // The carried piece's middle under the hand node (the feed's Motion.HeldOffset).
    private FTransform _FeedHeldLocal;
    // The left glove's pose override.
    private FMars_StationFeed_Presentation _FeedPresentation;
    private FCk_Handle_PlatterDock _InputDock;
    private FCk_Handle_PlatterDock _OutputDock;
    // One per piece the kernel announced and still holds, in admission order.
    private TArray<FMars_Station_PieceDisplay> _PieceRecords;

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FeedHandle))
        {
            _FeedHandle.UnbindFrom_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnFeedTransferRefused"));
            _FeedHandle.UnbindFrom_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnFeedPieceLetGo"));
        }

        _FeedPresentation.Clear(FCk_Handle());
        // The pieces wear their own displays; only the records go.
        _PieceRecords.Empty();

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The stand and the station's own operation (the counter base's), then the left glove's grip: the feed node lays it palm
    // down (at rest, and through each transfer).
    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        Super::Configure_Spec(InOutSpec);
        InOutSpec.Grips.Add(Make_NodeGrip(EMars_Hand::Left, GameplayTags::Station_Node_Feed, EMars_HandGripPose::Open));
    }

    // A station adds its tool's node and calls this.
    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Feed, _FeedHandNode.As_Transform()));
    }

    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Compose_Feed(InHandle);
    }

    // The left glove's pose override follows the feed (the feed moves the glove's node and the piece rides it); then every
    // piece's look.
    protected void Advance_Presentation(float32 InDeltaSeconds) override
    {
        if (ck::IsValid(_FeedHandle))
        { _FeedPresentation.Advance(_FeedHandle, _Root.H().As_Station().Get_Operator()); }

        Advance_PieceRecords(InDeltaSeconds);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Feed station hooks (each station overrides what differs)
    //----------------------------------------------------------------------------------------------------------------------

    protected FMars_FeedStation_DockLayout Get_DockLayout() const
    {
        return FMars_FeedStation_DockLayout();
    }

    // What the label says when the station's own gate refused an add-food press.
    protected FString Get_StationGateText() const
    {
        return "station busy";
    }

    // The kernel still holds the piece: false drops its record.
    protected bool Get_HoldsPiece(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return false;
    }

    // The piece's look stops following the kernel (a lost piece keeps its last look).
    protected bool Get_IsPieceFrozen(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return false;
    }

    // The piece's look this frame, from its kernel; InRecord.CookState is last frame's.
    protected FMars_CookState Make_PieceLook(const FMars_Station_PieceDisplay& InRecord, float32 InDeltaSeconds) const
    {
        return InRecord.CookState;
    }

    // The look must reach the display this frame, under the write threshold (a face that has just seared through).
    protected bool Get_IsPieceLookUrgent(const FMars_Station_PieceDisplay& InRecord) const
    {
        return false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Building blocks for the stations
    //----------------------------------------------------------------------------------------------------------------------

    // The feed node the left glove follows, at rest palm down with fingers forward k_PalmLift over InPalmRestLocal (station
    // frame, on the surface it rests on); the feed carries a piece's middle k_CarriedHalfExtent under the palm,
    // world-aligned, and moves the node itself (the glove stops so that middle lands on the piece and on the release node).
    // Called from AddVisuals, after _Root is set.
    protected void Add_FeedHand(FVector InPalmRestLocal)
    {
        const auto HandRotation = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        auto Geometry = FMars_StationFeed_Geometry();
        Geometry.RestLocal = FTransform(HandRotation, InPalmRestLocal + FVector(0.0, 0.0, constants_station::k_PalmLift));
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(),
            FVector(0.0, 0.0, constants_station::k_PalmLift + constants_station::k_CarriedHalfExtent));

        _FeedHandGeometry = Geometry.Make_HandGeometry();
        _FeedHeldLocal = Geometry.HeldLocal;
        _FeedHandNode = utils_scene_node::Create(_Root, Geometry.RestLocal);
    }

    // InPiece's record from the kernel's OnPieceAdded, its arrival look sent at once.
    protected void Add_PieceRecord(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto Record = FMars_Station_PieceDisplay(InPieceId, InPiece);
        Record.Write_Now();
        _PieceRecords.Add(Record);
    }

    // InPieceId's record, taken off the books (a piece the station keeps dressing after its kernel let it go); unset when
    // there is none.
    protected TOptional<FMars_Station_PieceDisplay> TryTake_PieceRecord(const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = _PieceRecords.Num() - 1; Index >= 0; --Index)
        {
            if (_PieceRecords[Index].Id.Get_IsSame(InPieceId) == false)
            { continue; }

            const auto Record = _PieceRecords[Index];
            _PieceRecords.RemoveAt(Index);
            return TOptional<FMars_Station_PieceDisplay>(Record);
        }

        return TOptional<FMars_Station_PieceDisplay>();
    }

    // A take-out that handed nothing back, as the label says it.
    protected void Flash_TakeOutRefusal(EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        if (InRefusal == EMars_CookingFeed_TakeOutRefusal::NoRoom)
        {
            Flash_Refusal(Get_NoRoomText());
            return;
        }

        Flash_Refusal("nothing ready");
    }

    // A hand-off capped at nothing: the tray is full, or there is none.
    protected FString Get_NoRoomText() const
    {
        if (Get_HasTray())
        { return "tray full"; }

        return "no tray";
    }

    // The platter docked on the finished tray's dock; invalid with none.
    protected FCk_Handle_Platter Get_Tray() const
    {
        if (ck::Is_NOT_Valid(_OutputDock))
        { return FCk_Handle_Platter(); }

        return _OutputDock.Get_Platter();
    }

    protected bool Get_HasTray() const
    {
        return ck::IsValid(Get_Tray());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Composition
    //----------------------------------------------------------------------------------------------------------------------

    private void Compose_Feed(FCk_Handle& InHandle)
    {
        // A rejected feed spec already ensured in utils_cooking_feed::Add; the kernel still works without a platter.
        auto FeedSpec = Feed;
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode, _FeedHandNode.As_Transform());
        FeedSpec.Motion.HeldOffset = _FeedHeldLocal;
        FeedSpec.Hand = TOptional<FMars_CookingFeed_HandGeometry>(_FeedHandGeometry);
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);
        if (ck::IsValid(_FeedHandle))
        {
            _FeedHandle.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnFeedTransferRefused"));
            _FeedHandle.BindTo_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnFeedPieceLetGo"));
        }

        const auto Layout = Get_DockLayout();
        _InputDock = Add_Dock(EMars_PlatterDock_Role::Input, Layout.Input);
        _OutputDock = Add_Dock(EMars_PlatterDock_Role::Output, Layout.Output);

        if (ck::IsValid(_InputDock))
        { Watch_Failures(_InputDock.Get_Interactable()); }

        if (ck::IsValid(_OutputDock))
        { Watch_Failures(_OutputDock.Get_Interactable()); }
    }

    // A dock on the counter top, a child of the root (it dies with the station), lifted so a docked platter's underside rests
    // on the top, with its marker. A rejected spec already ensured in utils_platter_dock::Create.
    private FCk_Handle_PlatterDock Add_Dock(EMars_PlatterDock_Role InRole, const FMars_FeedStation_DockSpot& InSpot)
    {
        auto Policy = Docks.Input;
        if (InRole == EMars_PlatterDock_Role::Output)
        { Policy = Docks.Output; }

        const auto DockLift = FVector(0.0, 0.0, constants_station::k_CounterHeight + constants_platter::k_FloorAboveBase);
        auto Spec = FMars_PlatterDock_Spec(InRole, Policy, FTransform(FRotator::ZeroRotator, InSpot.SurfaceLocal + DockLift));
        Spec.Prompt = utils_platter_dock::Make_PromptSpec();

        auto Dock = utils_platter_dock::Create(_Root, Spec);
        if (ck::IsValid(Dock))
        {
            utils_platter_dock::Add_Prompt(Dock, FMars_PlatterDock_PromptWords(InSpot.Name, InSpot.KindRejectedText));
            Dock.Add_Marker(this, InSpot.MarkerName);
        }

        return Dock;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the kernel is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // A record whose piece the kernel no longer holds (taken out, or destroyed at the end of its linger) or whose entity is
    // gone is dropped; a frozen one keeps its last look.
    private void Advance_PieceRecords(float32 InDeltaSeconds)
    {
        for (int32 Index = _PieceRecords.Num() - 1; Index >= 0; --Index)
        {
            auto Record = _PieceRecords[Index];
            if (ck::Is_NOT_Valid(Record.Entity) || Get_HoldsPiece(Record.Id) == false)
            {
                _PieceRecords.RemoveAt(Index);
                continue;
            }

            if (Get_IsPieceFrozen(Record.Id))
            { continue; }

            Record.CookState = Make_PieceLook(Record, InDeltaSeconds);
            if (Get_IsPieceLookUrgent(Record))
            { Record.Write_Now(); }
            else
            { Record.Write(); }

            _PieceRecords[Index] = Record;
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // The station's gate, or a hand mid-transfer or a source pile re-settling (Busy); an empty source is the add-food row's.
    UFUNCTION()
    private void OnFeedTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        if (InRefusal == EMars_CookingFeed_Refusal::StationGate)
        {
            Flash_Refusal(Get_StationGateText());
            return;
        }

        if (InRefusal != EMars_CookingFeed_Refusal::Busy)
        { return; }

        if (InFeed.Get_IsBusy())
        {
            Flash_Refusal("hand busy");
            return;
        }

        Flash_Refusal("settling");
    }

    UFUNCTION()
    private void OnFeedPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece)
    {
        Flash_Refusal("dropped: no platter to take it back");
    }
}
