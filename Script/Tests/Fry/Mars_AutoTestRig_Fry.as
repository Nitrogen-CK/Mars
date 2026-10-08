// The fry rig: a Fry station on a transform-only root at an isolated origin. The drain basket node sits fixed on the
// operator's right (k_BasketLocal, its five kinematic boxes); the skimmer node, parked at carry height over the far oil,
// carries the skimmer Implement (no look tilt, a pour roll and a commanded lift the skim sets, a Commanded slide the kernel
// steers) and, at its origin, the scoop's disc and lip. No pot and no floor: the oil is a buoyant band in open space and a
// lost piece falls into the void until the kernel destroys it. The pot starts empty; the rig is the test feed: AddPiece
// releases pieces with Ids {1, 0}, {1, 1}, ... at a root-frame pose (k_ReleaseLocal is the station's release point). The
// handlers record every signal by piece; the helpers drive, dip, carry, look, slide the skimmer and reset.
UCLASS(Abstract)
class UMars_AutoTestRig_Fry : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 22000.0, -60000.0);
    // The basket frame (the floor's top centre) in the station frame: right of the pot, its floor above the oil and the rim.
    protected const FVector k_BasketLocal = FVector(0.0, 90.0, 117.0);
    // The skimmer's park: over the far oil, its disc top 17 above the rim (clear of the basket's walls).
    protected const FVector k_ScoopPark = FVector(30.0, 6.0, 132.0);
    // Over the oil, left of the park (the station's rule: park X - 20, Y -10, 25 over the oil line).
    protected const FVector k_ReleaseLocal = FVector(10.0, -10.0, 128.0);
    // Room for the pour's roll (the scoop spec's PourRollDegrees).
    protected const float32 k_SkimmerMaxTiltDegrees = 60.0f;
    // A slow, critically damped dip and carry: the scoop's deceleration at the top of a carry stays under gravity, so a
    // piece on it is not thrown.
    protected const float32 k_SkimmerLiftSpringHz = 1.5f;
    protected const float32 k_SkimmerLiftDampingRatio = 1.0f;
    // The generation every rig piece carries.
    protected const int32 k_Generation = 1;
    protected const float32 k_LiftTolerance = 0.5f;
    protected const float32 k_SlideTolerance = 0.5f;

    protected FCk_Handle_Fry _Fry;
    // The specs the station was built from, nodes included.
    protected FMars_Fry_Spec _Spec;
    protected FMars_Implement_Spec _SkimmerSpec;
    protected FCk_Handle_Implement _Skimmer;
    // The next StockIndex AddPiece hands out.
    protected int32 _NextIndex = 0;

    // In parallel: one entry per OnPieceAdmission.
    protected TArray<FMars_CookingFeed_PieceId> _AdmissionIds;
    protected TArray<EMars_CookingFeed_Admission> _Admissions;
    protected TArray<FString> _AdmissionReasons;
    // In parallel: one entry per OnPieceAdded.
    protected TArray<FMars_CookingFeed_PieceId> _AddedIds;
    protected TArray<FCk_Handle> _Added;
    // In parallel: one entry per OnPieceWhereaboutsChanged.
    protected TArray<FMars_CookingFeed_PieceId> _WhereaboutsIds;
    protected TArray<EMars_Fry_Whereabouts> _WhereaboutsFrom;
    protected TArray<EMars_Fry_Whereabouts> _WhereaboutsTo;
    // In parallel: one entry per OnFaceHeatStage.
    protected TArray<FMars_CookingFeed_PieceId> _StageIds;
    protected TArray<EMars_Searing_Face> _StageFaces;
    protected TArray<EMars_Fry_HeatStage> _Stages;
    protected TArray<FMars_CookingFeed_PieceId> _DrainedIds;
    // In parallel: one entry per OnPieceLost.
    protected TArray<FMars_CookingFeed_PieceId> _LostIds;
    protected TArray<FCk_Handle> _Lost;
    protected TArray<EMars_Fry_Skim> _SkimChanges;
    protected TArray<EMars_Implement_Drive> _DriveChanges;

    // The oil line, the pot and the reach as the station lays them out around the rig's basket: the pot disc about the root,
    // a corridor as wide as the basket from the pot's axis to the basket interior's near edge (Y 64), and the interior.
    protected FMars_Fry_Spec Make_TestSpec()
    {
        auto Spec = FMars_Fry_Spec();
        Spec.Oil.SurfaceZ = 103.0f;
        Spec.Zones.RimZ = 115.0f;
        Spec.Zones.FloorZ = 30.0f;
        Spec.Zones.PotRadius = 45.0f;

        const auto InteriorNearY = k_BasketLocal.Y - float64(Spec.Basket.InnerHalfY);
        Spec.Reach.CorridorCentre = FVector2D(0.0, InteriorNearY * 0.5);
        Spec.Reach.CorridorHalfExtent = FVector2D(float64(Spec.Basket.InnerHalfX), InteriorNearY * 0.5);
        Spec.Reach.BasketCentre = FVector2D(k_BasketLocal.X, k_BasketLocal.Y);
        Spec.Reach.BasketHalfExtent = FVector2D(float64(Spec.Basket.InnerHalfX), float64(Spec.Basket.InnerHalfY));
        return Spec;
    }

    protected void BuildStation(FCk_Handle InHandle, FMars_Fry_Spec InSpec)
    {
        _Spec = InSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto BasketNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_BasketLocal));
        const auto BasketBody = utils_fry::Add_BasketBodies(BasketNode, _Spec.Basket);

        // The skimmer node at its park is the implement's rest: the kernel steers its slide within the reach, the skim
        // lowers it to the dip, raises it back to the carry and rolls it to the pour.
        auto SkimmerNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_ScoopPark));
        auto ScoopNode = utils_scene_node::Create(SkimmerNode.As_Transform(), FTransform::Identity);
        const auto Bounds = utils_fry::Get_ReachBounds(_Spec);
        _SkimmerSpec = FMars_Implement_Spec();
        _SkimmerSpec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        _SkimmerSpec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        _SkimmerSpec.Tilt.MaxTiltDegrees = k_SkimmerMaxTiltDegrees;
        _SkimmerSpec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        _SkimmerSpec.Lift.LiftPerLookDegree = 0.0f;
        _SkimmerSpec.Lift.MinLift = _Spec.Scoop.DipLift - 2.0f;
        _SkimmerSpec.Lift.MaxLift = 2.0f;
        _SkimmerSpec.Lift.SpringHz = k_SkimmerLiftSpringHz;
        _SkimmerSpec.Lift.DampingRatio = k_SkimmerLiftDampingRatio;
        _SkimmerSpec.Slide.Mode = EMars_Implement_SlideMode::Commanded;
        _SkimmerSpec.Slide.Centre = Bounds.Centre - FVector2D(k_ScoopPark.X, k_ScoopPark.Y);
        _SkimmerSpec.Slide.HalfExtentX = float32(Bounds.HalfExtent.X + 1.0);
        _SkimmerSpec.Slide.HalfExtentY = float32(Bounds.HalfExtent.Y + 1.0);
        _SkimmerSpec.Nodes = FMars_Implement_Nodes(SkimmerNode);
        _Skimmer = utils_implement::Add(SkimmerNode.H(), _SkimmerSpec);
        const auto ScoopBody = utils_fry::Add_ScoopBodies(ScoopNode, _Spec.Scoop);

        _Spec.Nodes = FMars_Fry_Nodes(_Skimmer, ScoopBody, BasketBody);
        _Fry = utils_fry::Add(StationEntity, _Spec);

        _Fry.BindTo_OnDriveChanged(FMars_Delegate_Fry_OnDriveChanged(this, n"OnDriveChanged"));
        _Fry.BindTo_OnPieceAdmission(FMars_Delegate_Fry_OnPieceAdmission(this, n"OnPieceAdmission"));
        _Fry.BindTo_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnPieceAdded"));
        _Fry.BindTo_OnPieceWhereaboutsChanged(FMars_Delegate_Fry_OnPieceWhereaboutsChanged(this, n"OnPieceWhereaboutsChanged"));
        _Fry.BindTo_OnFaceHeatStage(FMars_Delegate_Fry_OnFaceHeatStage(this, n"OnFaceHeatStage"));
        _Fry.BindTo_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnPieceDrained"));
        _Fry.BindTo_OnPieceLost(FMars_Delegate_Fry_OnPieceLost(this, n"OnPieceLost"));
        _Fry.BindTo_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnSkimChanged"));
    }

    // A fresh piece (the next Id) released at InRootLocal in the station frame, at rest and level with the root.
    protected FMars_CookingFeed_PieceId AddPiece(FVector InRootLocal)
    {
        const auto PieceId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        Release_Piece(PieceId, InRootLocal);
        return PieceId;
    }

    // A release with InPieceId at InRootLocal (a duplicate Id included: the kernel answers).
    protected void Release_Piece(const FMars_CookingFeed_PieceId& InPieceId, FVector InRootLocal)
    {
        const auto RootWorld = _Fry.Get_RootWorld();
        const auto ReleaseWorld = FTransform(RootWorld.GetRotation(), RootWorld.TransformPosition(InRootLocal));
        _Fry.Request_AddPiece(FMars_Request_Fry_AddPiece(FMars_CookingFeed_Release(InPieceId, ReleaseWorld, FVector::ZeroVector, InPieceId.StockIndex)));
    }

    protected void Drive()
    {
        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
    }

    protected void Dip()
    {
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Dip));
    }

    protected void Carry()
    {
        _Fry.Request_Skim(FMars_Request_Fry_Skim(EMars_Fry_Skim::Carry));
    }

    protected void Look(FVector InLookDelta)
    {
        _Fry.Request_Look(FMars_Request_Fry_Look(InLookDelta));
    }

    // One look that moves the skimmer's target by InDelta (root frame: +X away from the operator, +Y right).
    protected void SlideSkimmerBy(FVector2D InDelta)
    {
        const auto Step = float64(_Spec.Reach.CmPerLookDegree);
        Look(FVector(InDelta.Y / Step, -InDelta.X / Step, 0.0));
    }

    // One look, sized by Reach.CmPerLookDegree, from the skimmer's current target to InRootXY (the kernel clamps it to the
    // reach).
    protected void SlideSkimmerTo(FVector2D InRootXY)
    {
        SlideSkimmerBy(InRootXY - _Fry.Get_SkimmerTarget());
    }

    protected void ResetStation()
    {
        _Fry.Request_Reset(FMars_Request_Fry_Reset());
    }

    // Moves the piece's body to InRootLocal (level with the root) at InVelocity (station frame).
    protected void Teleport(const FMars_CookingFeed_PieceId& InPieceId, FVector InRootLocal, FVector InVelocity)
    {
        const auto RootWorld = _Fry.Get_RootWorld();
        auto Body = _Fry.Get_PieceBody(InPieceId);
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(RootWorld.TransformPosition(InRootLocal), RootWorld.Rotator()));
        if (InVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(RootWorld.GetRotation().RotateVector(InVelocity))); }
    }

    protected float32 Get_Now() const
    {
        return float32(System::GetGameTimeInSeconds());
    }

    // The first piece OnPieceAdded reported; a default Id before that.
    protected FMars_CookingFeed_PieceId Get_FirstId() const
    {
        if (_AddedIds.Num() == 0)
        { return FMars_CookingFeed_PieceId(); }

        return _AddedIds[0];
    }

    // A piece's centre in the station frame.
    protected FVector Get_PieceRootLocal(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        const auto PieceWorld = utils_transform::Get_EntityCurrentLocation(_Fry.Get_PieceEntity(InPieceId).As_Transform());
        return _Fry.Get_RootWorld().InverseTransformPosition(PieceWorld);
    }

    protected float64 Get_PieceSpeed(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return utils_jolt_body::Get_LinearVelocity(_Fry.Get_PieceBody(InPieceId)).Size();
    }

    // The piece face whose normal points most nearly up (station frame).
    protected EMars_Searing_Face Get_UpFace(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        const auto Rotation = utils_transform::Get_EntityCurrentTransform(_Fry.Get_PieceEntity(InPieceId).As_Transform()).GetRotation();
        return utils_searing::Get_DownFace(Rotation, -_Fry.Get_RootWorld().GetRotation().GetUpVector());
    }

    protected EMars_Searing_Face Get_DownFace(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        const auto Rotation = utils_transform::Get_EntityCurrentTransform(_Fry.Get_PieceEntity(InPieceId).As_Transform()).GetRotation();
        return utils_searing::Get_DownFace(Rotation, _Fry.Get_RootWorld().GetRotation().GetUpVector());
    }

    // The whereabouts the piece passed through since edge InFromEdge, as "From->To" pairs; OutPath gets the places in order
    // (the first edge's From, then every To).
    protected FString Get_Path(const FMars_CookingFeed_PieceId& InPieceId, int32 InFromEdge, TArray<EMars_Fry_Whereabouts>&out OutPath)
    {
        OutPath.Empty();
        auto Edges = FString();
        for (int32 Edge = InFromEdge; Edge < _WhereaboutsTo.Num(); ++Edge)
        {
            if (_WhereaboutsIds[Edge].Get_IsSame(InPieceId) == false)
            { continue; }

            if (OutPath.Num() == 0)
            { OutPath.Add(_WhereaboutsFrom[Edge]); }

            OutPath.Add(_WhereaboutsTo[Edge]);
            Edges = f"{Edges} {_WhereaboutsFrom[Edge] :n}->{_WhereaboutsTo[Edge] :n}";
        }

        return Edges;
    }

    protected int32 Count_Ids(const TArray<FMars_CookingFeed_PieceId>& InIds, const FMars_CookingFeed_PieceId& InPieceId) const
    {
        auto Count = 0;
        for (const auto& PieceId : InIds)
        {
            if (PieceId.Get_IsSame(InPieceId))
            { Count += 1; }
        }

        return Count;
    }

    // The scoop's lift sits within k_LiftTolerance of InLift.
    protected bool Get_IsLiftAt(float32 InLift) const
    {
        return Math::Abs(_Skimmer.Get_Lift() - InLift) <= k_LiftTolerance;
    }

    // The skimmer's slide has reached its target and that target is the kernel's.
    protected bool Get_IsSlideSettled() const
    {
        const auto Expected = _Fry.Get_SkimmerTarget() - FVector2D(k_ScoopPark.X, k_ScoopPark.Y);
        return (_Skimmer.Get_TargetSlide() - Expected).Size() <= float64(k_SlideTolerance)
            && (_Skimmer.Get_Slide() - _Skimmer.Get_TargetSlide()).Size() <= float64(k_SlideTolerance);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnDriveChanged(FCk_Handle_Fry InFry, EMars_Implement_Drive InDrive)
    {
        _DriveChanges.Add(InDrive);
    }

    UFUNCTION()
    protected void OnPieceAdmission(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        _AdmissionIds.Add(InPieceId);
        _Admissions.Add(InAdmission);
        _AdmissionReasons.Add(InReason);
    }

    UFUNCTION()
    protected void OnPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _AddedIds.Add(InPieceId);
        _Added.Add(InPiece);
    }

    UFUNCTION()
    protected void OnPieceWhereaboutsChanged(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId,
        EMars_Fry_Whereabouts InFrom, EMars_Fry_Whereabouts InTo)
    {
        _WhereaboutsIds.Add(InPieceId);
        _WhereaboutsFrom.Add(InFrom);
        _WhereaboutsTo.Add(InTo);
    }

    UFUNCTION()
    protected void OnFaceHeatStage(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, EMars_Fry_HeatStage InStage)
    {
        _StageIds.Add(InPieceId);
        _StageFaces.Add(InFace);
        _Stages.Add(InStage);
    }

    UFUNCTION()
    protected void OnPieceDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId)
    {
        _DrainedIds.Add(InPieceId);
    }

    UFUNCTION()
    protected void OnPieceLost(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _LostIds.Add(InPieceId);
        _Lost.Add(InPiece);
    }

    UFUNCTION()
    protected void OnSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        _SkimChanges.Add(InSkim);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_BodiesAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_Spec.Nodes.ScoopBody) && utils_jolt_body::Get_IsBodyAdded(_Spec.Nodes.BasketBody));
    }

    UFUNCTION()
    protected void Step_Drive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Fry), "the feature composed");
        Drive();
    }

    UFUNCTION()
    protected void Step_Dip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dip();
    }

    UFUNCTION()
    protected void Step_Carry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Carry();
    }

    UFUNCTION()
    protected void Check_Dipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Dip && Get_IsLiftAt(_Spec.Scoop.DipLift));
    }

    // Carrying at carry height, the scoop's underside clear of the rim.
    UFUNCTION()
    protected void Check_CarryingClear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() == EMars_Fry_Skim::Carry && Get_IsLiftAt(_Spec.Scoop.CarryLift) && _Fry.Get_IsScoopClearOfRim());
    }

    UFUNCTION()
    protected void Check_SlideSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlideSettled());
    }

    UFUNCTION()
    protected void Check_Added1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 1 && utils_jolt_body::Get_IsBodyAdded(_Fry.Get_PieceBody(Get_FirstId())));
    }

    UFUNCTION()
    protected void Check_FirstDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FirstId = Get_FirstId();
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 1 && _Fry.Get_HasPiece(FirstId) && _Fry.Get_PieceDrain(FirstId) == EMars_Fry_Drain::Drained);
    }
}
