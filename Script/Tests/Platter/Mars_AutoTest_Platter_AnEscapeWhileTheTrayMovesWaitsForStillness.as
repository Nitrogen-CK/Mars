// An escape while the tray moves waits for stillness before its one re-drop. A box dropped onto the platter is knocked out
// onto a ledge beside its walls just as the platter starts sliding (60 cm/s: a tray carried to a dock). This platter counts
// a piece that drifts less than its DriftCm per sample as at rest, so the box freezes on the ledge while the platter still
// slides. It is not attached while the platter moves: it stays settling, outside the walls. Once the platter stops, the box
// is dropped again, once, and lands inside the walls.
class UMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(44000.0, -25000.0, -30000.0);
    private const float64 k_Speed = 60.0;
    // The ledge: a static slab beside the -X wall (the platter slides away along +X), its top level with the floor's.
    private const FVector k_LedgeOffset = FVector(-60.0, 0.0, 0.0);
    private const FVector k_LedgeHalfExtents = FVector(20.0, 20.0, 1.0);
    // The box's bottom starts this far above the ledge.
    private const float64 k_LedgeClearanceCm = 1.0;
    // A box at rest on the ledge drifts 9 cm per 0.15 s sample in the sliding root's frame: under this, that is at rest.
    private const float32 k_DriftCm = 40.0f;
    // Room for the freeze and the second of sliding the test holds the box out for.
    private const float32 k_MaxSeconds = 6.0f;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private float64 _MoveStart = 0.0;
    private bool _IsMoving = false;
    // Watched every frame.
    private int32 _MostRedrops = 0;
    private bool _WasAttachedWhileMoving = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_PlatterSpec(2);
        Spec.Settle.DriftCm = k_DriftCm;
        Spec.Settle.MaxSeconds = k_MaxSeconds;
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Spec);
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        auto Owner = InHandle;
        Add_Ledge(Owner);
        utils_timer::Create_Tick(Owner, FCk_Delegate_Timer(this, n"OnTick"));

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("load P onto the still platter", n"Step_Load");
        Add_Step_WaitUntil("the platter dropped P", n"Check_Dropped", 0, 0);
        Add_Step("knock P onto the ledge and start the platter sliding", n"Step_KnockOutAndSlide");
        Add_Step_WaitUntil("P froze on the ledge while the platter slides", n"Check_FrozenOutside", 0, 0);
        Add_Step_WaitSeconds("the platter keeps sliding", 1.0f);
        Add_Step("P is not attached: it is still settling, outside the walls", n"Step_AssertWaiting");
        Add_Step("stop the platter", n"Step_Stop");
        Add_Step_WaitUntil("P landed", n"Check_Landed", 0, 0);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("P was dropped again once and is frozen inside the walls", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    private void Add_Ledge(FCk_Handle& InOwner)
    {
        auto Ledge = utils_entity_lifetime::Request_CreateEntity(InOwner);
        const auto Centre = k_Origin + k_LedgeOffset - FVector(0.0, 0.0, k_LedgeHalfExtents.Z);
        utils_transform::Add(Ledge, FTransform(FRotator::ZeroRotator, Centre), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_LedgeHalfExtents);
        auto LedgeSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        LedgeSpec.Set_ShapeDimensions(Shape);
        LedgeSpec.Set_MotionType(ECk_MotionType::Static);
        LedgeSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Ledge, LedgeSpec);
    }

    // Slides the root along +X while moving, and watches P's settling entry and its parent.
    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_IsMoving)
        {
            const auto Elapsed = float64(System::GetGameTimeInSeconds()) - _MoveStart;
            Move_Platter(_Platter, k_Origin + FVector(k_Speed * Elapsed, 0.0, 0.0));

            if (Get_IsSceneNode(_P))
            { _WasAttachedWhileMoving = true; }
        }

        const auto Settling = TryGet_Settling();
        if (Settling.IsSet())
        { _MostRedrops = Math::Max(_MostRedrops, Settling.GetValue().Redrops); }
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _P);
    }

    // Settling with its body in the simulation.
    UFUNCTION()
    private void Check_Dropped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _P;
        auto Res = OutResult;
        Res.Set(TryGet_Settling().IsSet() && Entity.Is_JoltBody() && utils_jolt_body::Get_IsBodyAdded(Entity.As_JoltBody()));
    }

    // P's middle over the ledge's, level, its bottom k_LedgeClearanceCm above the ledge, at rest.
    UFUNCTION()
    private void Step_KnockOutAndSlide(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Metrics = Get_Metrics(_P);
        const auto HalfHeight = (Metrics.Get_BoundsMaxCm().Z - Metrics.Get_BoundsMinCm().Z) * 0.5;
        const auto Centre = k_Origin + k_LedgeOffset + FVector(0.0, 0.0, HalfHeight + k_LedgeClearanceCm);
        FCk_Handle Entity = _P;
        auto Body = Entity.As_JoltBody();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Centre - Get_BoundsCenter(_P), FRotator::ZeroRotator));

        _MoveStart = float64(System::GetGameTimeInSeconds());
        _IsMoving = true;
    }

    UFUNCTION()
    private void Check_FrozenOutside(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Settling = TryGet_Settling();
        auto Res = OutResult;
        Res.Set(Settling.IsSet() && Settling.GetValue().Freeze.IsSet() && Get_IsInsideWalls(_Platter, _P) == false);
    }

    UFUNCTION()
    private void Step_AssertWaiting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Settling = TryGet_Settling();
        Assert_True(Settling.IsSet(), "P is still settling");
        Assert_True(Settling.IsSet() && Settling.GetValue().Redrops == 0, "P has not been dropped again");
        Assert_False(Get_IsSceneNode(_P), "P has no scene parent while the platter slides");
        Assert_False(Get_IsInsideWalls(_Platter, _P), "P is outside the walls");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "nothing landed");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 1, "P is the one pending piece");
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _IsMoving = false;
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_Loaded(_P).IsSet() || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_False(_WasAttachedWhileMoving, "P was never attached while the platter slid");
        Assert_Equals_Int(_MostRedrops, 1, "P was dropped again once");
        Assert_Equals_Int(Get_LoadedCountOf(_P), 1, "P landed once");
        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is frozen on the root");
        Assert_True(Get_IsInsideWalls(_Platter, _P), "P lies inside the walls");
    }

    // P's entry while it settles; unset otherwise.
    private TOptional<FMars_Platter_Settling> TryGet_Settling() const
    {
        for (const auto& Settling : _Platter.Get_Fragment(FMars_Fragment_Platter).Settling)
        {
            if (Settling.Piece == _P)
            { return TOptional<FMars_Platter_Settling>(Settling); }
        }

        return TOptional<FMars_Platter_Settling>();
    }
}
