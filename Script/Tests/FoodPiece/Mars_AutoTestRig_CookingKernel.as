// The test feed every cooking kernel's rig shares (Searing, Fry, Batter): the station entity on a transform-only root at the
// rig's isolated origin, its admission answers recorded; box food pieces (the FoodPiece rig's box, under the world's
// transient entity) built with no body and parked in a row beside the station, k_ParkPitch apart, handed out in build order;
// and a release into the station's admission inbox, as the feed does, with the piece's middle at a given point.
// The box's size is read from its metrics, never assumed. Each kernel's rig records its own OnPieceAdded into _AddedIds.
UCLASS(Abstract)
class UMars_AutoTestRig_CookingKernel : UMars_AutoTestRig_FoodPiece
{
    // The generation every rig piece carries.
    protected const int32 k_Generation = 1;
    // Where built pieces wait for their release, beside the station, k_ParkPitch apart.
    protected const FVector k_ParkLocal = FVector(0.0, -300.0, 0.0);
    protected const float64 k_ParkPitch = 20.0;
    // A poll budget, not a ceiling: bodies bake into the simulation, pieces import, land and cook over seconds.
    protected const int32 k_SlowPolls = 900;

    // The station entity (the kernel's), which a test may destroy.
    protected FCk_Handle _StationEntity;
    // Built in order; _NextPiece is the next one a release takes.
    protected TArray<FCk_Handle_FoodPiece> _Pieces;
    protected int32 _NextPiece = 0;
    // The next TransferIndex a release hands out.
    protected int32 _NextIndex = 0;
    // One entry per OnPieceAdded, in order.
    protected TArray<FMars_CookingFeed_PieceId> _AddedIds;

    private FVector _StationOrigin;

    // The station entity under InHandle with its root at InOrigin. Tracked with the pieces so it is torn down in the frame
    // they are, as a station's own teardown ends them: left to the runner's cascade it would tick on after they are gone, and
    // a piece gone from under a live kernel is a defect the kernel ensures on.
    protected FCk_Handle_Transform Create_StationRoot(FCk_Handle InHandle, FVector InOrigin)
    {
        _StationOrigin = InOrigin;
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _StationEntity = StationEntity;
        Track_ForCleanup(StationEntity);
        Record_Admissions(StationEntity);
        return utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);
    }

    // Where the next built piece parks: beside the station, one pitch past the last.
    protected FTransform Get_NextPark() const
    {
        return FTransform(FRotator::ZeroRotator, _StationOrigin + k_ParkLocal - FVector(0.0, k_ParkPitch * float64(_Pieces.Num()), 0.0));
    }

    // A box piece of InSpec built at the next park.
    protected void Build_ParkedPiece(FMars_FoodPiece_Spec InSpec)
    {
        _Pieces.Add(Build_Piece(Get_BoxMesh(), Get_NextPark(), InSpec));
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

    // The next Id a release hands out: {k_Generation, _NextIndex}.
    protected FMars_CookingFeed_PieceId Take_NextId()
    {
        const auto PieceId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        return PieceId;
    }

    // InPiece released with InPieceId (a duplicate Id included: the kernel answers), at rest, its middle at InMiddleWorld's
    // location and turned by its rotation.
    protected void Release_At(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle_FoodPiece InPiece, FTransform InMiddleWorld)
    {
        const auto Rotation = InMiddleWorld.GetRotation();
        const auto ReleaseWorld = FTransform(Rotation, InMiddleWorld.GetLocation() - Rotation.RotateVector(Get_BoundsCenter(InPiece)));

        auto Release = FMars_CookingFeed_Release(InPieceId, ReleaseWorld, FVector::ZeroVector);
        Release.Piece = InPiece;
        utils_cooking_feed::Request_Admit(_StationEntity, Release);
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

    // The first piece OnPieceAdded reported; a default Id before that.
    protected FMars_CookingFeed_PieceId Get_FirstId() const
    {
        if (_AddedIds.Num() == 0)
        { return FMars_CookingFeed_PieceId(); }

        return _AddedIds[0];
    }

    protected float32 Get_Now() const
    {
        return float32(System::GetGameTimeInSeconds());
    }

    // Every built piece is Ready (a release reads its metrics).
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
}
