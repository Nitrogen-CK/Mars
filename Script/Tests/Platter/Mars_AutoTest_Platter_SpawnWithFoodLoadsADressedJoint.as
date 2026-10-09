// A platter spawned with a food builds that food's whole joint, dresses it when it is Ready and loads it into slot 0: the
// held piece is the whole beef joint, wearing its display, its bounds centre over slot 0.
class UMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(14000.0, -15000.0, -30000.0);

    // The spawned platter entity, under construction until it is a Platter.
    private FCk_Handle _Entity;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        _Entity = utils_platter::Request_SpawnWorld(Owner,
            FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin), mars::Food_MeatSlab_Mars));

        Add_Step_WaitUntil("the platter holds one piece", n"Check_HoldsOne");
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("the piece is the dressed whole beef joint, over slot 0", n"Step_AssertDressedJoint");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_HoldsOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Platter) && ck::IsValid(_Entity) && _Entity.Is_Platter())
        { _Platter = _Entity.As_Platter(); }

        const auto HoldsOne = ck::IsValid(_Platter) && _Platter.Get_HeldCount() == 1;
        if (HoldsOne && ck::Is_NOT_Valid(_Piece))
        {
            const auto Held = _Platter.Get_Held();
            _Piece = Held[0];
            Track_ForCleanup(_Piece);
        }

        auto Res = OutResult;
        Res.Set(HoldsOne);
    }

    UFUNCTION()
    private void Step_AssertDressedJoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Ready, "the joint is Ready");
        Assert_True(_Piece.Get_IsWhole(), "the joint is whole");
        Assert_True(_Piece.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), "the joint is beef");
        Assert_True(_Piece.Get_Definition().Get() == mars::Food_MeatSlab_Mars, "the joint's definition is the meat slab");
        Assert_True(_Piece.Get_PlatterSlot() == TOptional<int32>(0), "the joint holds slot 0");

        FCk_Handle PieceEntity = _Piece;
        Assert_True(PieceEntity.Is_RuntimeMeshDisplay(), "the joint wears its display (added when it readied)");

        const auto Metrics = utils_runtime_mesh::Get_Metrics(_Piece.Get_Geometry());
        const auto CentreLocal = (Metrics.Get_BoundsMinCm() + Metrics.Get_BoundsMaxCm()) * 0.5;
        const auto Centre = utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform()).TransformPosition(CentreLocal);

        FCk_Handle PlatterEntity = _Platter;
        const auto PlatterWorld = utils_transform::Get_EntityCurrentTransform(PlatterEntity.As_Transform());
        const auto Slot = (_Platter.Get_Spec().SlotsLocal[0] * PlatterWorld).GetLocation();

        const auto CentreXY = FVector(Centre.X, Centre.Y, 0.0);
        const auto SlotXY = FVector(Slot.X, Slot.Y, 0.0);
        Assert_True(CentreXY.Equals(SlotXY, 0.5), f"the joint's bounds centre sits over slot 0 ({CentreXY} vs {SlotXY})");
    }
}
