// The dicing station: a table (width along local Y, depth along local X) with a cutting board on top, an herb pile on the
// board, a highlighted band the cleaver must be over to chop usefully, and a cleaver that slides along the board under the
// operator's hand. The operator stands StandGap uu in front of the table's -X edge facing +X; the view is Captured (the
// look delta slides the hand). The Dicing feature lives on the station entity and its own state machine
// (UMars_SmState_Dicing_Idle) reads the operator; this script only builds the nodes and moves visuals from the Dicing
// signals. While operating, the right glove holds the cleaver handle (riding the slide and the chop) and the left rests
// flat near the board's left edge, outside the cleaver's travel (the script sets the Dicing spec's BoardHalfWidth to
// HandHalfTravel).
//
// The meat slab on the board is a procedural mesh the station builds from the baked table in
// Script/Generated/Mars_MeatSlabMesh.as and slices itself at every chop (the AngelScript binder exposes none of
// UKismetProceduralMeshLibrary): a piece is a triangle soup in the slab node's frame (three positions per triangle and the
// triangle's section) plus the component that shows it; a cut clips every triangle against the blade's plane, caps the
// cut polygon with a fan and moves the halves apart.
struct FMars_DicingSlab_Piece
{
    // Three positions per triangle, slab-node space, cm.
    TArray<FVector> Positions;
    // Per triangle: 0 flesh, 1 fat cap, 2 cut face.
    TArray<int> Sections;
    UProceduralMeshComponent Component;
}

class UMars_DicingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Dicing_Spec Dicing;

    // PrepTable_Mars_SM: 160 wide (the blockout was 140), the extra 10 cm a side making room for the ingredient bowl and
    // the finished tray beside the 90 cm board (station_spec.py PROPS["PrepTable"], CuttingStation_Layout.json).
    private const float64 TableWidth = 160.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the table edge.
    private const float64 StandGap = 43.0;
    // The ingredient bowl (left, -Y) and the finished tray (right, +Y) sit beside the board at the table's Input / Output
    // sockets; both meshes pivot at the centre of their inner floor, so they are placed their floor thickness above the top.
    private const float64 BowlY = 62.0;
    private const float64 BowlFloor = 3.0;
    private const float64 TrayFloor = 1.5;
    // The operating view, pitched hard onto the board from ViewGap uu off the table edge and ViewAboveBoard uu over the
    // board top. It lives in the station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -48.0f;
    private const float64 ViewGap = 38.0;
    private const float64 ViewAboveBoard = 58.0;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    private const float64 BoardWidth = 90.0;
    private const float64 BoardDepth = 50.0;
    private const float64 BoardThickness = 4.0;
    private const float64 BoardX = -5.0;

    // The hand's (and the cleaver's) lateral travel each side of the board centre: the Dicing spec's BoardHalfWidth, set
    // here because it is bound to the geometry - the cleaver (and the band table's extreme fraction of it) must stop
    // short of the left glove at -(BoardWidth / 2) + LeftGripEdgeInset.
    private const float32 HandHalfTravel = 28.0f;
    // The left glove's grip, in from the board's left (-Y) edge.
    private const float64 LeftGripEdgeInset = 6.0;

    // The left glove's grip bone above the board (the palm's thickness, FMars_FPHands_Spec.PalmSurfaceOffset).
    private const float64 PalmLift = 2.5;

    // The pile and the cleaver sit over the board's middle; the band marks the strip in front of the pile (operator side),
    // just above the board so it never z-fights it.
    private const float64 PileX = 0.0;
    private const float64 BandX = -24.0;
    private const float64 BandDepth = 10.0;
    private const float64 BandLift = 0.5;
    private const float64 CleaverX = 0.0;

    // Blade 30 long (X), 2 thick (Y), 12 tall, pivot at its centre: contact puts its bottom on the board.
    private const float64 BladeHalfHeight = 6.0;
    private const float64 CleaverRaise = 25.0;
    // The handle runs from the blade's near end toward the operator, near the blade's top.
    // The cleaver mesh's Strike socket (edge centre) from its rear-grip pivot: MeatCleaver_Mars_SM.json.
    private const FVector CleaverEdgeFromGrip = FVector(38.55, 0.0, -11.9);
    // The slab (MeatSlab_Mars_SM: 36.8 x 20.2 x 12.1, pivot at its base centre, long axis +X) lies at PileX on the board,
    // yawed so its long axis runs along the board's width (local Y), across the cleaver's travel: each chop at the hand's
    // lateral position slices it with the blade's plane (normal local Y). The halves part by SlabNudgeCm each so the cut
    // shows. Its two static mesh sections are Flesh (0) and the fat cap (1); the slicer caps cuts with the cut material.
    private const float64 SlabYaw = 90.0;
    private const float64 SlabNudgeCm = 0.75;
    private const int32 k_SlabFlesh = 0;
    private const int32 k_SlabFat = 1;
    private const int32 k_SlabCut = 2;
    private const int32 k_SlabSectionCount = 3;
    // A vertex within this of the plane is on it (no sliver triangles); cap points closer than this are one point.
    private const float64 k_SlabPlaneEpsilon = 0.02;

    // The state label above the board's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 40.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const int32 k_ChopBurstBehavior = 13; // SparksBurst
    private const float64 ChopBurstLift = 1.0;
    private const float32 ChopBurstSize = 0.35f;
    private const float32 ChopBurstColorIntensity = 0.8f;
    private const float32 ChopBurstPlaybackSpeed = 1.6f;

    private FCk_Handle_Transform _Root;
    // Dicing with the geometry-bound fields set (DoConstruct); what the feature and the visuals read.
    private FMars_Dicing_Spec _DicingSpec;
    private FCk_Handle_Dicing _DicingHandle;
    // The meat slab: a procedural copy of MeatSlab_Mars_SM on the board that every chop slices along the blade's plane.
    // _SlabPieces[0] is the hosted component; the halves the slicing splits off are its siblings, created by the slicer.
    private FCk_Handle_SceneNode _SlabNode;
    private FCk_Handle_UnrealComponent _SlabPart;
    private TArray<FMars_DicingSlab_Piece> _SlabPieces;
    // Component names must be unique on the owner for its whole life (a destroyed piece's name lingers until GC).
    private int32 _SlabPieceSerial = 0;
    private FCk_Handle_SceneNode _BandNode;
    private FCk_Handle_SceneNode _LateralNode;
    private FCk_Handle_Mover _ChopMover;
    // The right glove's grip: the cleaver handle, under the Mover node so it rides the chop and the lateral slide.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip: flat near the board's left edge, outside the cleaver's travel.
    private FCk_Handle_Transform _BoardGripNode;
    private FCk_Handle_UnrealComponent _Label;
    private UNiagaraComponent _ChopBurst;
    private bool _OutlineClaimed = false;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the minigame needs the station, so it is composed after.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the band and the strike from it.
        _DicingSpec = Dicing;
        _DicingSpec.BoardHalfWidth = HandHalfTravel;

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to dice on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected Dicing spec already ensured in utils_dicing::Add.
        _DicingSpec.Nodes = FMars_Dicing_Nodes(_LateralNode, _ChopMover);
        _DicingHandle = utils_dicing::Add(InHandle, _DicingSpec);
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_SlabPart))
        { utils_unreal_component::BindTo_OnAdded(_SlabPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnSlabPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Set_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag(), ECk_Usf_OutlineScope::EntityAndDependents);
            _OutlineClaimed = true;
        }

        if (ck::Is_NOT_Valid(_DicingHandle))
        { return; }

        _DicingHandle.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _DicingHandle.BindTo_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
        _DicingHandle.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
        _DicingHandle.BindTo_OnReset(FMars_Delegate_Dicing_OnReset(this, n"OnReset"));

        Refresh_Pile();
        Refresh_Label();
        Move_Band(_DicingHandle.Get_BandCenter());
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_DicingHandle))
        {
            _DicingHandle.UnbindFrom_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
            _DicingHandle.UnbindFrom_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
            _DicingHandle.UnbindFrom_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
            _DicingHandle.UnbindFrom_OnReset(FMars_Delegate_Dicing_OnReset(this, n"OnReset"));
        }

        if (_OutlineClaimed && ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Clear_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag());
        }

        _OutlineClaimed = false;

        if (ck::IsValid(_ChopBurst))
        { _ChopBurst.DestroyComponent(); }

        _ChopBurst = nullptr;

        // The slicing's own components go with the station; the hosted first piece is the Ck host's to tear down.
        Destroy_SplitPieces();
        _SlabPieces.Empty();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the handle node wraps the right glove around the horizontal handle, the
        // board node lays the left glove flat on the board.
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(TableDepth * 0.5 + ViewGap), 0.0, Get_BoardTop() + ViewAboveBoard)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "DiceHerbsPrompt", "Dice herbs"),
            NSLOCTEXT("MarsInteraction", "DicingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Dicing_Idle;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(TableDepth * 0.5 + ProbePadding, TableWidth * 0.5 + ProbePadding, TableHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube and sphere are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        auto CubeMesh = engine::load::Cube();
        const auto BoardTop = Get_BoardTop();

        // The station props (station_spec.py): the table pivots at its floor contact, the board at the centre of its
        // underside (exactly the blockout board's 50 x 90 x 4 at BoardX), the bowl and the tray at their inner floor.
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            assets::load::PrepTable_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_Table"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, 0.0, TableHeight)),
            assets::load::CuttingBoard_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_Board"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, -BowlY, TableHeight + BowlFloor)),
            assets::load::PrepBowl_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_InputBowl"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, BowlY, TableHeight + TrayFloor)),
            assets::load::PrepTray_Mars_SM(), nullptr, collision::profile::BlockAll, n"DicingStation_OutputTray"));

        // The slab: a procedural mesh component (filled from MeatSlab_Mars_SM once it exists, OnSlabPartAdded) on a node
        // at the board's centre, yawed so the joint lies across the cleaver's travel.
        _SlabNode = utils_scene_node::Create(InRoot, FTransform(FRotator(0.0, SlabYaw, 0.0), FVector(PileX, 0.0, BoardTop)));
        auto SlabArchetype = NewObject(this, UProceduralMeshComponent);
        SlabArchetype.SetMobility(EComponentMobility::Movable);
        SlabArchetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        auto SlabParams = utils_unreal_component::Make_Params_FromArchetype(
            SlabArchetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"DicingStation_Slab");
        _SlabPart = utils_unreal_component::Add(_SlabNode.H(), SlabParams);
        if (ck::IsValid(_SlabPart))
        { utils_entity_tag::Add(_SlabPart, n"TAG_MarsDicingSlab"); }

        // The band: a flat slab across the strip in front of the pile, centred on the band; outlined in DoBeginPlay.
        _BandNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(BandX, utils_dicing::Get_BandCenterAt(_DicingSpec, 0), BoardTop + BandLift)));
        auto BandTransform = _BandNode.As_Transform();
        BandTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(BandDepth * 0.01, _DicingSpec.BandHalfWidth * 0.02, 0.01)),
            CubeMesh, assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"DicingStation_Band"));

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, BoardTop + LabelHeight)));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): a left hand flat on the board with its
        // fingers forward has its index side to the right (+Y) and its palm down (-Z); the grip bone sits a palm's
        // thickness above the surface.
        _BoardGripNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::MakeFromXZ(FVector::RightVector, -FVector::UpVector),
                FVector(BoardX, -BoardWidth * 0.5 + LeftGripEdgeInset, BoardTop + PalmLift))).As_Transform();

        AddCleaver(InRoot);
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _BoardGripNode));
    }

    // The cleaver: a lateral node the hand slides along the board (Y), a Mover node under it for the chop (Z), the blade
    // and handle parts, and the handle's grip node, all under the Mover node so they ride both.
    private void AddCleaver(FCk_Handle_Transform& InRoot)
    {
        _LateralNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(CleaverX, 0.0, Get_BoardTop())));
        auto LateralTransform = _LateralNode.As_Transform();
        auto CleaverNode = utils_scene_node::Create(LateralTransform,
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise)));

        // One Duration for both directions: the recover takes ChopDownSeconds too.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise);
        MoverSpec.EndLocation = FVector(0.0, 0.0, BladeHalfHeight);
        MoverSpec.Duration = _DicingSpec.ChopDownSeconds;
        MoverSpec.Easing = ECk_TweenEasing::InQuad;
        _ChopMover = utils_mover::Add(CleaverNode, MoverSpec);

        // MeatCleaver_Mars_SM: pivot at the rear grip, blade along +X, edge down; its Strike socket (the edge's centre) is
        // CleaverEdgeFromGrip from the pivot. The mesh is placed so that edge centre sits BladeHalfHeight under the cleaver
        // node: the chop's contact puts the edge on the board, as the blockout blade's bottom was.
        auto CleaverTransform = CleaverNode.As_Transform();
        const auto GripLocal = FVector(-CleaverEdgeFromGrip.X, 0.0, -CleaverEdgeFromGrip.Z - BladeHalfHeight);
        CleaverTransform.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, GripLocal),
            assets::load::MeatCleaver_Mars_SM(), nullptr, collision::profile::NoCollision, n"DicingStation_Cleaver"));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): along the handle toward the blade
        // (+X), palm facing the operator's left (-Y) - a handshake grip on the rear grip, blade edge down.
        _HandleGripNode = utils_scene_node::Create(CleaverTransform,
            FTransform(FRotator::MakeFromXZ(FVector::ForwardVector, -FVector::RightVector), GripLocal)).As_Transform();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Dicing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    private float64 Get_BoardTop() const
    {
        return TableHeight + BoardThickness;
    }

    // A fresh pile puts the whole joint back on the board. The kernel's OnReset is the trigger (a Reset before the chops
    // changed the texture leaves the state at WholeLeaves, so a state change alone would miss it); a cut joint is one
    // the slicing split, so a whole one is never rebuilt.
    private void Refresh_Pile()
    {
        if (ck::Is_NOT_Valid(_DicingHandle))
        { return; }

        if (_SlabPieces.Num() > 1)
        { Build_Slab(); }
    }

    // The whole joint from the baked table into the hosted procedural mesh: the one piece. Any halves a previous cutting
    // split off go first. The table carries no colours; the sections wear the flat MeatSlab tints (Accent_Mars_M).
    private void Build_Slab()
    {
        auto Proc = Cast<UProceduralMeshComponent>(utils_unreal_component::Get_Component(_SlabPart));
        if (ck::Is_NOT_Valid(Proc))
        { return; }

        Destroy_SplitPieces();
        _SlabPieces.Empty();

        auto Piece = FMars_DicingSlab_Piece();
        Piece.Component = Proc;
        const auto Vertices = mars_meatslab_mesh::Make_Vertices();
        const auto Triangles = mars_meatslab_mesh::Make_Triangles();
        const auto Sections = mars_meatslab_mesh::Make_Sections();
        const auto Centre = (mars_meatslab_mesh::k_BoundsMin + mars_meatslab_mesh::k_BoundsMax) * 0.5;
        Piece.Positions.Reserve(Triangles.Num());
        Piece.Sections.Reserve(Sections.Num());
        for (int32 Triangle = 0; Triangle < Sections.Num(); ++Triangle)
        {
            const auto Index = Triangle * 3;
            auto A = Vertices[Triangles[Index]];
            auto B = Vertices[Triangles[Index + 1]];
            auto C = Vertices[Triangles[Index + 2]];
            // Outward winding (the joint is star-shaped about its centre): a face whose normal points in is turned over.
            if ((Get_FaceNormal(A, B, C)).DotProduct((A + B + C) / 3.0 - Centre) < 0.0)
            {
                const auto Swap = B;
                B = C;
                C = Swap;
            }
            Piece.Positions.Add(A);
            Piece.Positions.Add(B);
            Piece.Positions.Add(C);
            Piece.Sections.Add(Sections[Triangle]);
        }
        _SlabPieces.Add(Piece);
        Write_Piece(_SlabPieces[0]);
    }

    // The components the slicing created (every piece but the hosted first one).
    private void Destroy_SplitPieces()
    {
        for (int32 Index = 1; Index < _SlabPieces.Num(); ++Index)
        {
            if (ck::IsValid(_SlabPieces[Index].Component))
            { _SlabPieces[Index].Component.DestroyComponent(); }
        }
    }

    // Unreal is left-handed and winds front faces clockwise seen from outside: for such a triangle (C - A) x (B - A)
    // points out (the stock ProceduralMesh floor quad (0,0,0) (0,100,0) (100,0,0) faces +Z). (B - A) x (C - A) is the
    // right-handed habit and turned the whole joint inside out.
    private FVector Get_FaceNormal(FVector InA, FVector InB, FVector InC) const
    {
        return (InC - InA).CrossProduct(InB - InA).GetSafeNormal();
    }

    // The piece's soup into its component: one section per material, every triangle flat (its own three corners).
    private void Write_Piece(const FMars_DicingSlab_Piece& InPiece)
    {
        auto Proc = InPiece.Component;
        if (ck::Is_NOT_Valid(Proc))
        { return; }

        Proc.ClearAllMeshSections();
        TArray<FVector2D> NoUVs;
        TArray<FLinearColor> NoColours;
        TArray<FProcMeshTangent> NoTangents;
        for (int32 Section = 0; Section < k_SlabSectionCount; ++Section)
        {
            TArray<FVector> Vertices;
            TArray<int32> Triangles;
            TArray<FVector> Normals;
            TArray<FVector2D> UVs;
            for (int32 Triangle = 0; Triangle < InPiece.Sections.Num(); ++Triangle)
            {
                if (InPiece.Sections[Triangle] != Section)
                { continue; }

                const auto A = InPiece.Positions[Triangle * 3];
                const auto B = InPiece.Positions[Triangle * 3 + 1];
                const auto C = InPiece.Positions[Triangle * 3 + 2];
                const auto Normal = Get_FaceNormal(A, B, C);
                const auto Base = Vertices.Num();
                Vertices.Add(A);
                Vertices.Add(B);
                Vertices.Add(C);
                for (int32 Corner = 0; Corner < 3; ++Corner)
                {
                    Normals.Add(Normal);
                    UVs.Add(FVector2D::ZeroVector);
                    Triangles.Add(Base + Corner);
                }
            }
            if (Vertices.Num() == 0)
            { continue; }

            Proc.CreateMeshSection_LinearColor(Section, Vertices, Triangles, Normals, UVs, NoUVs, NoUVs, NoUVs, NoColours, NoTangents, false, false);
            Proc.SetMaterial(Section, Get_SlabMaterial(Section));
        }
    }

    private UMaterialInterface Get_SlabMaterial(int32 InSection) const
    {
        if (InSection == k_SlabFat)
        { return assets::load::MeatSlabFat_Mars_MI(); }
        if (InSection == k_SlabCut)
        { return assets::load::MeatSlabCut_Mars_MI(); }
        return assets::load::MeatSlabFlesh_Mars_MI();
    }

    // Every piece the blade's plane crosses splits in two: the plane stands on the board at the hand's lateral position
    // with its normal along the board's width (the blade runs along the board's depth), carried into the slab node's frame.
    // The positive side stays in the piece, the negative side becomes a new piece on a sibling component; both move
    // SlabNudgeCm away from the plane so the cut shows. A piece the plane misses is left as it is.
    private void Slice_Slab(float32 InLateral)
    {
        if (_SlabPieces.Num() == 0)
        { return; }

        const auto NodeLocal = FTransform(FRotator(0.0, SlabYaw, 0.0), FVector(PileX, 0.0, Get_BoardTop()));
        const auto PlanePosition = NodeLocal.InverseTransformPosition(FVector(CleaverX, float64(InLateral), Get_BoardTop()));
        const auto PlaneNormal = NodeLocal.InverseTransformVector(FVector::RightVector).GetSafeNormal();

        auto NewPieces = TArray<FMars_DicingSlab_Piece>();
        for (int32 Index = 0; Index < _SlabPieces.Num(); ++Index)
        {
            auto Positive = FMars_DicingSlab_Piece();
            auto Negative = FMars_DicingSlab_Piece();
            if (Split_Piece(_SlabPieces[Index], PlanePosition, PlaneNormal, Positive, Negative) == false)
            { continue; }

            Shift_Piece(Positive, PlaneNormal * SlabNudgeCm);
            Shift_Piece(Negative, PlaneNormal * -SlabNudgeCm);
            Positive.Component = _SlabPieces[Index].Component;
            Negative.Component = Make_PieceComponent(Positive.Component);
            _SlabPieces[Index] = Positive;
            Write_Piece(_SlabPieces[Index]);
            Write_Piece(Negative);
            NewPieces.Add(Negative);
        }

        for (auto Piece : NewPieces)
        { _SlabPieces.Add(Piece); }
    }

    private void Shift_Piece(FMars_DicingSlab_Piece& InPiece, FVector InOffset)
    {
        for (int32 Index = 0; Index < InPiece.Positions.Num(); ++Index)
        { InPiece.Positions[Index] += InOffset; }
    }

    // A sibling of InSibling on the same owner and parent, at the same (identity) relative transform, no collision.
    private UProceduralMeshComponent Make_PieceComponent(UProceduralMeshComponent InSibling)
    {
        _SlabPieceSerial += 1;
        auto Component = UProceduralMeshComponent::Create(InSibling.GetOwner(), FName(f"DicingStation_SlabPiece_{_SlabPieceSerial}"));
        Component.SetMobility(EComponentMobility::Movable);
        Component.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Component.AttachToComponent(InSibling.GetAttachParent(), NAME_None,
            EAttachmentRule::SnapToTarget, EAttachmentRule::SnapToTarget, EAttachmentRule::SnapToTarget, false);
        Component.SetRelativeTransform(InSibling.GetRelativeTransform());
        return Component;
    }

    // Clips every triangle of InPiece against the plane: whole triangles go to their side, crossing ones are cut into the
    // polygon on each side (fan-triangulated, winding kept) and their cut edges collected; the cut polygon is capped on
    // both sides with a fan about its centroid (the joint's sections are convex enough). False when the plane misses.
    private bool Split_Piece(const FMars_DicingSlab_Piece& InPiece, FVector InPlanePosition, FVector InPlaneNormal,
                             FMars_DicingSlab_Piece& OutPositive, FMars_DicingSlab_Piece& OutNegative) const
    {
        TArray<FVector> CapPoints;
        bool AnyPositive = false;
        bool AnyNegative = false;
        for (int32 Triangle = 0; Triangle < InPiece.Sections.Num(); ++Triangle)
        {
            const auto Section = InPiece.Sections[Triangle];
            TArray<FVector> Corners;
            TArray<float64> Distances;
            int32 Above = 0;
            int32 Below = 0;
            for (int32 Corner = 0; Corner < 3; ++Corner)
            {
                const auto P = InPiece.Positions[Triangle * 3 + Corner];
                const auto D = (P - InPlanePosition).DotProduct(InPlaneNormal);
                Corners.Add(P);
                Distances.Add(D);
                if (D > k_SlabPlaneEpsilon)
                { Above += 1; }
                else if (D < -k_SlabPlaneEpsilon)
                { Below += 1; }
            }

            if (Below == 0)
            {
                Add_Triangle(OutPositive, Corners[0], Corners[1], Corners[2], Section);
                AnyPositive = true;
                continue;
            }
            if (Above == 0)
            {
                Add_Triangle(OutNegative, Corners[0], Corners[1], Corners[2], Section);
                AnyNegative = true;
                continue;
            }

            // Crossing: clip the triangle's polygon to each half-space (Sutherland-Hodgman keeps the winding).
            TArray<FVector> PositivePoly;
            TArray<FVector> NegativePoly;
            for (int32 Corner = 0; Corner < 3; ++Corner)
            {
                const auto Next = (Corner + 1) % 3;
                const auto P = Corners[Corner];
                const auto Q = Corners[Next];
                const auto DP = Distances[Corner];
                const auto DQ = Distances[Next];
                if (DP >= -k_SlabPlaneEpsilon)
                { PositivePoly.Add(P); }
                if (DP <= k_SlabPlaneEpsilon)
                { NegativePoly.Add(P); }
                if ((DP > k_SlabPlaneEpsilon && DQ < -k_SlabPlaneEpsilon) || (DP < -k_SlabPlaneEpsilon && DQ > k_SlabPlaneEpsilon))
                {
                    const auto Cut = P + (Q - P) * (DP / (DP - DQ));
                    PositivePoly.Add(Cut);
                    NegativePoly.Add(Cut);
                    CapPoints.Add(Cut);
                }
            }
            Add_Polygon(OutPositive, PositivePoly, Section);
            Add_Polygon(OutNegative, NegativePoly, Section);
            AnyPositive = true;
            AnyNegative = true;
        }

        if (AnyPositive == false || AnyNegative == false)
        { return false; }

        Add_Cap(OutPositive, CapPoints, InPlaneNormal * -1.0);
        Add_Cap(OutNegative, CapPoints, InPlaneNormal);
        return true;
    }

    private void Add_Triangle(FMars_DicingSlab_Piece& InPiece, FVector InA, FVector InB, FVector InC, int32 InSection) const
    {
        InPiece.Positions.Add(InA);
        InPiece.Positions.Add(InB);
        InPiece.Positions.Add(InC);
        InPiece.Sections.Add(InSection);
    }

    // A convex polygon (3 or 4 points, wound like the triangle it came from) as a fan from its first point.
    private void Add_Polygon(FMars_DicingSlab_Piece& InPiece, const TArray<FVector>& InPolygon, int32 InSection) const
    {
        for (int32 Index = 1; Index + 1 < InPolygon.Num(); ++Index)
        { Add_Triangle(InPiece, InPolygon[0], InPolygon[Index], InPolygon[Index + 1], InSection); }
    }

    // The cut face: the distinct cut points sorted by angle about their centroid in the plane, fanned from the centroid,
    // every fan triangle wound so its face normal is InOutward.
    private void Add_Cap(FMars_DicingSlab_Piece& InPiece, const TArray<FVector>& InCapPoints, FVector InOutward) const
    {
        TArray<FVector> Points;
        for (auto Candidate : InCapPoints)
        {
            bool Known = false;
            for (auto Point : Points)
            {
                if (Point.Equals(Candidate, k_SlabPlaneEpsilon))
                {
                    Known = true;
                    break;
                }
            }
            if (Known == false)
            { Points.Add(Candidate); }
        }
        if (Points.Num() < 3)
        { return; }

        auto Centroid = FVector::ZeroVector;
        for (auto Point : Points)
        { Centroid += Point; }
        Centroid /= float64(Points.Num());

        // A basis in the plane: U toward the first point, V = outward x U.
        const auto U = (Points[0] - Centroid).GetSafeNormal();
        const auto V = (InOutward).CrossProduct(U).GetSafeNormal();
        TArray<float64> Angles;
        for (auto Point : Points)
        {
            const auto Offset = Point - Centroid;
            Angles.Add(Math::Atan2((Offset).DotProduct(V), (Offset).DotProduct(U)));
        }
        // Insertion sort by angle (a few dozen points).
        for (int32 Index = 1; Index < Points.Num(); ++Index)
        {
            auto Point = Points[Index];
            auto Angle = Angles[Index];
            int32 Slot = Index - 1;
            while (Slot >= 0 && Angles[Slot] > Angle)
            {
                Points[Slot + 1] = Points[Slot];
                Angles[Slot + 1] = Angles[Slot];
                Slot -= 1;
            }
            Points[Slot + 1] = Point;
            Angles[Slot + 1] = Angle;
        }

        for (int32 Index = 0; Index < Points.Num(); ++Index)
        {
            auto A = Points[Index];
            auto B = Points[(Index + 1) % Points.Num()];
            if ((Get_FaceNormal(Centroid, A, B)).DotProduct(InOutward) < 0.0)
            {
                const auto Swap = A;
                A = B;
                B = Swap;
            }
            Add_Triangle(InPiece, Centroid, A, B, k_SlabCut);
        }
    }

    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        Text.SetText(Get_StateLabel(_DicingHandle.Get_MaterialState(), _DicingHandle.Get_RequestedState()));
    }

    // What the label reads: the texture, "stop here" once it is exactly the requested one, "over-processed" past it.
    private FText Get_StateLabel(EMars_Dicing_State InState, EMars_Dicing_State InRequested) const
    {
        const auto StateName = utils_dicing::Get_StateName(InState);
        if (InState == InRequested)
        { return FText::FromString(f"{StateName}: stop here"); }

        if (int32(InState) > int32(InRequested))
        { return FText::FromString(f"{StateName}: over-processed"); }

        return FText::FromString(StateName);
    }

    private void Move_Band(float32 InCenter)
    {
        if (ck::Is_NOT_Valid(_BandNode))
        { return; }

        utils_scene_node::Request_UpdateOffset_Location(_BandNode, FVector(BandX, InCenter, Get_BoardTop() + BandLift), ECk_RelativeAbsolute::Absolute);
    }

    // One reused burst component: spawned at the first aligned chop whose template is ready (a cold template never stalls
    // the game thread; the chop just goes without a burst), then moved and re-activated per chop. Null under nullrhi.
    private void Play_ChopBurst()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _DicingHandle.Get_HandLateral(), Get_BoardTop() + ChopBurstLift));

        if (ck::IsValid(_ChopBurst))
        {
            _ChopBurst.SetWorldLocation(Contact);
            _ChopBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_ChopBurstBehavior) == false)
        { return; }

        _ChopBurst = utils_particles::Spawn_BehaviorAtLocation(k_ChopBurstBehavior, Contact, RootWorld.Rotator());
        if (ck::IsValid(_ChopBurst))
        { utils_particles::Request_ApplyTuningValues(_ChopBurst, ChopBurstSize, ChopBurstColorIntensity, 1.0f, ChopBurstPlaybackSpeed); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Parts
    //----------------------------------------------------------------------------------------------------------------------

    // The state label above the board's far edge, yawed to face the operator. Its text is set once the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(Get_StateLabel(EMars_Dicing_State::WholeLeaves, _DicingSpec.RequestedState));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"DicingStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Pile();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnReset(FCk_Handle_Dicing InDicing)
    {
        Refresh_Pile();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter)
    {
        Move_Band(InCenter);
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        // The blade cuts whatever meat lies under it wherever it lands; only an aligned chop counts (and sparks).
        Slice_Slab(InDicing.Get_HandLateral());
        if (InResult == EMars_Dicing_ChopResult::Aligned)
        { Play_ChopBurst(); }
    }

    UFUNCTION()
    private void OnSlabPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Build_Slab();
    }
}
