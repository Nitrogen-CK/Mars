// The searing rig: a Searing station on a transform-only root at an isolated origin, its pan node 100 uu up carrying the
// pan Implement (no swirl: the tests pin the ledger) and the pan: the pan mesh at the station's scale, a kinematic
// triangle-mesh body on its own child node (built by utils_searing::Add_PanBody, as the station builds it). There is no
// table or floor: a lost piece falls into the void until the kernel destroys it. The pan starts empty; the rig is the test
// feed: Build_Pieces makes box food pieces (the FoodPiece rig's box, under the world's transient entity), parked beside the
// station with no body, and its AddPiece helpers release them in build order with Ids {1, 0}, {1, 1}, ..., each so that
// the piece's middle lands at a pan-local point. A test waits on Check_PiecesReady before its first admission. The box's
// size is read from its metrics, never assumed. The handlers record every signal by piece; the steps heat the pan, add
// pieces, look, and wait on them.
UCLASS(Abstract)
class UMars_AutoTestRig_Searing : UMars_AutoTestRig_FoodPiece
{
    protected const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // The station's pan: cooking_spec.py's pan (base radius 9.5, rim radius 14.5 at height 4.6, in the mesh's own cm) at
    // the station's scale.
    protected const float32 k_PanScale = 2.5f;
    protected const float32 k_PanRimRadius = 14.5f;
    // The generation every rig piece carries.
    protected const int32 k_Generation = 1;
    // A rig piece's mass (the station's old steak's).
    protected const float k_PieceMassKg = 0.1;
    // The clearance AddPiece leaves under a piece over the cooking surface.
    protected const float64 k_DropClearance = 2.0;
    // Where built pieces wait for their release, beside the station, k_ParkPitch apart.
    protected const FVector k_ParkLocal = FVector(0.0, -300.0, 0.0);
    protected const float64 k_ParkPitch = 20.0;

    protected FCk_Handle_Searing _Searing;
    // The specs the station was built from, nodes included.
    protected FMars_Searing_Spec _Spec;
    protected FMars_Implement_Spec _PanSpec;
    protected FCk_Handle_SceneNode _PanNode;
    protected FCk_Handle_Implement _Pan;
    protected FCk_Handle_JoltBody _PanBaseBody;
    // The station entity (the Searing's), which a test may destroy.
    protected FCk_Handle _StationEntity;
    // The next StockIndex AddPiece hands out.
    protected int32 _NextIndex = 0;
    // Built in order; _NextPiece is the next one a release takes.
    protected TArray<FCk_Handle_FoodPiece> _Pieces;
    protected int32 _NextPiece = 0;

    // In parallel: one entry per OnPieceAdmission.
    protected TArray<FMars_CookingFeed_PieceId> _AdmissionIds;
    protected TArray<EMars_CookingFeed_Admission> _Admissions;
    protected TArray<FString> _AdmissionReasons;
    // In parallel: one entry per OnPieceAdded.
    protected TArray<FMars_CookingFeed_PieceId> _AddedIds;
    protected TArray<FCk_Handle> _Added;
    // In parallel: one entry per OnPanContactChanged.
    protected TArray<FMars_CookingFeed_PieceId> _ContactIds;
    protected TArray<EMars_Searing_Contact> _Contacts;
    // In parallel: one entry per OnFaceSeared.
    protected TArray<FMars_CookingFeed_PieceId> _SearedIds;
    protected TArray<EMars_Searing_Face> _Seared;
    protected int32 _ProgressSignals = 0;
    protected TArray<EMars_Searing_Sizzle> _Sizzles;
    protected TArray<EMars_Searing_Heat> _Heats;
    // In parallel: one entry per OnPieceReady.
    protected TArray<FMars_CookingFeed_PieceId> _ReadyIds;
    protected TArray<FMars_Searing_Tally> _ReadyTallies;
    // In parallel: one entry per OnPieceLost.
    protected TArray<FMars_CookingFeed_PieceId> _LostIds;
    protected TArray<FCk_Handle> _Lost;
    // In parallel: one entry per OnPieceTakenOut.
    protected TArray<FMars_CookingFeed_PieceId> _TakenOutIds;
    protected TArray<FCk_Handle_FoodPiece> _TakenOut;

    // The game time of the first OnPieceAdded and of the first landing (the settle time is their difference).
    protected float32 _FirstAddedTime = -1.0f;
    protected float32 _FirstLandingTime = -1.0f;

    // SecondsPerFace 0.2, LingerSeconds 0.5; the rest default.
    protected FMars_Searing_Spec Make_TestSpec()
    {
        auto Spec = FMars_Searing_Spec();
        Spec.Cook.SecondsPerFace = 0.2f;
        Spec.Loss.LingerSeconds = 0.5f;
        // The station's values, so the kernel is tested on the pan it ships with.
        Spec.Loss.PanRadius = k_PanRimRadius * k_PanScale;
        return Spec;
    }

    // InPanSpec is the pan Implement's (tilt, lift, orbit); its default has no orbit.
    protected void BuildStation(FCk_Handle InHandle, FMars_Searing_Spec InSpec, FMars_Implement_Spec InPanSpec = FMars_Implement_Spec())
    {
        _Spec = InSpec;
        _PanSpec = InPanSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _StationEntity = StationEntity;
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _PanNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        _PanSpec.Nodes = FMars_Implement_Nodes(_PanNode);
        _Pan = utils_implement::Add(_PanNode.H(), _PanSpec);
        _PanBaseBody = Build_Pan(_PanNode);

        _Spec.Nodes = FMars_Searing_Nodes(_Pan, _PanBaseBody);
        _Searing = utils_searing::Add(StationEntity, _Spec);

        _Searing.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
        _Searing.BindTo_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnPieceAdmission"));
        _Searing.BindTo_OnPieceAdded(FMars_Delegate_Searing_OnPieceAdded(this, n"OnPieceAdded"));
        _Searing.BindTo_OnPanContactChanged(FMars_Delegate_Searing_OnPanContactChanged(this, n"OnPanContactChanged"));
        _Searing.BindTo_OnSearProgress(FMars_Delegate_Searing_OnSearProgress(this, n"OnSearProgress"));
        _Searing.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));
        _Searing.BindTo_OnSizzleChanged(FMars_Delegate_Searing_OnSizzleChanged(this, n"OnSizzleChanged"));
        _Searing.BindTo_OnPieceReady(FMars_Delegate_Searing_OnPieceReady(this, n"OnSearingPieceReady"));
        _Searing.BindTo_OnPieceLost(FMars_Delegate_Searing_OnPieceLost(this, n"OnPieceLost"));
        _Searing.BindTo_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnPieceTakenOut"));
    }

    // InCount box pieces of k_PieceMassKg, parked in a row beside the station; each is Ready once its import resolves.
    protected void Build_Pieces(int32 InCount)
    {
        for (int32 Index = 0; Index < InCount; ++Index)
        {
            const auto Park = k_Origin + k_ParkLocal - FVector(0.0, k_ParkPitch * float64(_Pieces.Num()), 0.0);
            _Pieces.Add(Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, Park), Make_Spec(k_PieceMassKg)));
        }
    }

    // The next built piece, in build order; a rig that built too few fails the test.
    protected FCk_Handle_FoodPiece Take_Piece()
    {
        if (_NextPiece >= _Pieces.Num())
        {
            FinishFailure(f"the rig built {_Pieces.Num()} piece(s) and a release wants another");
            return FCk_Handle_FoodPiece();
        }

        _NextPiece += 1;
        return _Pieces[_NextPiece - 1];
    }

    // Half InPiece's bounds along its own axes, from its metrics.
    protected FVector Get_HalfExtents(FCk_Handle_FoodPiece InPiece) const
    {
        const auto Metrics = Get_Metrics(InPiece);
        return (Metrics.Get_BoundsMaxCm() - Metrics.Get_BoundsMinCm()) * 0.5;
    }

    // Every rig piece is the same box: the first one's half extents.
    protected FVector Get_BoxHalfExtents() const
    {
        return Get_HalfExtents(_Pieces[0]);
    }

    protected FCk_Handle_JoltBody Build_Pan(FCk_Handle_SceneNode InPanNode)
    {
        auto PanNode = InPanNode;
        return utils_searing::Add_PanBody(PanNode, FMars_Searing_PanBodySpec(assets::FryPan_Mars_SM(), k_PanScale));
    }

    protected void Heat()
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
    }

    protected void Look(FVector InLookDelta)
    {
        _Searing.Request_Look(FMars_Request_Searing_Look(InLookDelta));
    }

    // The next piece released over the pan's centre, flat, its half height + k_DropClearance above the cooking surface.
    protected FMars_CookingFeed_PieceId AddPiece()
    {
        return AddPieceAt(FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + Get_BoxHalfExtents().Z + k_DropClearance));
    }

    // The next piece (with the next Id) released with its middle at InPanLocal in the pan base's frame, at rest and level
    // with the pan.
    protected FMars_CookingFeed_PieceId AddPieceAt(FVector InPanLocal)
    {
        const auto PieceId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        Release_Piece(PieceId, InPanLocal);
        return PieceId;
    }

    // The next piece released with InPieceId (a duplicate Id included: the kernel answers), its middle at InPanLocal.
    protected void Release_Piece(const FMars_CookingFeed_PieceId& InPieceId, FVector InPanLocal)
    {
        Release_ThePiece(InPieceId, Take_Piece(), InPanLocal);
    }

    // InPiece released with InPieceId, its middle at InPanLocal, level with the pan.
    protected void Release_ThePiece(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle_FoodPiece InPiece, FVector InPanLocal)
    {
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Rotation = PanBaseWorld.GetRotation();
        const auto Centre = PanBaseWorld.TransformPosition(InPanLocal);
        const auto ReleaseWorld = FTransform(Rotation, Centre - Rotation.RotateVector(Get_BoundsCenter(InPiece)));

        auto Release = FMars_CookingFeed_Release(InPieceId, ReleaseWorld, FVector::ZeroVector, 0);
        Release.Piece = InPiece;
        _Searing.Request_AddPiece(FMars_Request_Searing_AddPiece(Release));
    }

    // Teleports the piece's body so its middle lands at InPanLocal (pan base frame), turned by InPanRotation on top of the
    // pan's: a cut piece's origin is not its middle, so the turn is about the middle.
    protected void Teleport_Piece(const FMars_CookingFeed_PieceId& InPieceId, FVector InPanLocal, FRotator InPanRotation)
    {
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Rotation = FQuat(PanBaseWorld.Rotator()) * FQuat(InPanRotation);
        const auto Centre = PanBaseWorld.TransformPosition(InPanLocal);
        const auto CentreLocal = _Searing.Get_PieceState(InPieceId).CentreLocal;

        auto Body = _Searing.Get_PieceBody(InPieceId);
        utils_jolt_body::Request_Teleport(Body,
            FCk_Request_JoltBody_Teleport(Centre - Rotation.RotateVector(CentreLocal), Rotation.Rotator()));
    }

    protected float32 Get_Now()
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

    protected int32 Get_AdmissionCount(EMars_CookingFeed_Admission InAdmission) const
    {
        auto Count = 0;
        for (const auto Admission : _Admissions)
        {
            if (Admission == InAdmission)
            { Count += 1; }
        }

        return Count;
    }

    // The piece is still on the pan's books and rests on it.
    protected bool Get_IsOnPan(const FMars_CookingFeed_PieceId& InPieceId) const
    {
        return _Searing.Get_HasPiece(InPieceId) && _Searing.Get_PieceContact(InPieceId) == EMars_Searing_Contact::OnPan;
    }

    // Wait for the pan body and the rig's pieces, add one piece over the centre and wait for it to land.
    protected void Add_Steps_AddPieceAndLand()
    {
        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("add a piece over the pan's centre", n"Step_AddPiece");
        Add_Step_WaitUntil("the piece landed on the pan", n"Check_FirstOnPan", 0, 3.0f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        _Heats.Add(InHeat);
    }

    UFUNCTION()
    protected void OnPieceAdmission(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        _AdmissionIds.Add(InPieceId);
        _Admissions.Add(InAdmission);
        _AdmissionReasons.Add(InReason);
    }

    UFUNCTION()
    protected void OnPieceAdded(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _AddedIds.Add(InPieceId);
        _Added.Add(InPiece);
        if (_FirstAddedTime < 0.0f)
        { _FirstAddedTime = Get_Now(); }
    }

    UFUNCTION()
    protected void OnPanContactChanged(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Contact InContact)
    {
        _ContactIds.Add(InPieceId);
        _Contacts.Add(InContact);
        if (InContact == EMars_Searing_Contact::OnPan && _FirstLandingTime < 0.0f)
        { _FirstLandingTime = Get_Now(); }
    }

    UFUNCTION()
    protected void OnSearProgress(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace, float32 InAlpha)
    {
        _ProgressSignals += 1;
    }

    UFUNCTION()
    protected void OnFaceSeared(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_Searing_Face InFace)
    {
        _SearedIds.Add(InPieceId);
        _Seared.Add(InFace);
    }

    UFUNCTION()
    protected void OnSizzleChanged(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle)
    {
        _Sizzles.Add(InSizzle);
    }

    UFUNCTION()
    protected void OnSearingPieceReady(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FMars_Searing_Tally InTally)
    {
        _ReadyIds.Add(InPieceId);
        _ReadyTallies.Add(InTally);
    }

    UFUNCTION()
    protected void OnPieceLost(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _LostIds.Add(InPieceId);
        _Lost.Add(InPiece);
    }

    UFUNCTION()
    protected void OnPieceTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOutIds.Add(InPieceId);
        _TakenOut.Add(InPiece);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Heat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Searing), "the feature composed");
        Heat();
    }

    UFUNCTION()
    protected void Step_AddPiece(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPiece();
    }

    UFUNCTION()
    protected void Check_PanBodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_PanBaseBody));
    }

    // Every built piece has its metrics (a release reads them).
    UFUNCTION()
    protected void Check_PiecesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = _Pieces.Num() > 0;
        for (const auto& Piece : _Pieces)
        {
            if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
            { AllReady = false; }
        }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    UFUNCTION()
    protected void Check_FirstOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() > 0 && Get_IsOnPan(Get_FirstId()));
    }

    UFUNCTION()
    protected void Check_Added1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 1);
    }

    UFUNCTION()
    protected void Check_Added2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() >= 2);
    }

    UFUNCTION()
    protected void Check_FirstDownFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FirstId = Get_FirstId();
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() > 0 && _Searing.Get_HasPiece(FirstId) && _Searing.Get_IsDownFaceSeared(FirstId));
    }

    UFUNCTION()
    protected void Check_Lost1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lost.Num() >= 1);
    }

    UFUNCTION()
    protected void Check_Ready1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReadyIds.Num() > 0);
    }

    // Every piece recorded lost has been destroyed.
    UFUNCTION()
    protected void Check_LostDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllGone = true;
        for (const auto& Lost : _Lost)
        {
            if (ck::IsValid(Lost))
            { AllGone = false; }
        }

        auto Res = OutResult;
        Res.Set(AllGone);
    }
}

// The runner for every test that builds the pan: it REQUIRES the one warning CkJolt logs while baking the pan mesh (the
// two handle sweeps are inconsistently wound and get flipped), so the tests pass on the mesh as shipped and fail the day
// the mesh is fixed, which is when this class and the wrappers below it go.
UCLASS(Abstract)
class AMars_AutoTestRunner_SearingPan : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Errors;
        Errors.Add("had 2 individually inside-out component(s) and 0 aggregate no-verdict component(s) normalized during the Jolt bake (1 healthy, 0 no-verdict, 0 open, 0 non-manifold, 2 inconsistent, 0 malformed)");
        return Errors;
    }
}
