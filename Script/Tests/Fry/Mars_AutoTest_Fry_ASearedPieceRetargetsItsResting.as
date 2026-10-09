// A piece that comes from a searing pan already carries a body (Kinematic, as a take-out leaves it) and a Resting on that
// pan's base (a stand-in plate here). Admitted to the fryer it gets no second body and no second Resting (no ensure): its
// Resting is retargeted onto the scoop disc and the basket floor, its own body is switched back to Dynamic, and it floats in
// the oil like any piece.
class UMars_AutoTest_Fry_ASearedPieceRetargetsItsResting : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 12.0f;

    // The stand-in pan base: a kinematic plate beside the station, nowhere near the piece or the pot.
    private const FVector k_PlateLocal = FVector(0.0, -600.0, 0.0);

    private FCk_Handle_JoltBody _Plate;
    private FCk_Handle_FoodPiece _Food;
    private FCk_Handle_JoltBody _Body;
    private FMars_CookingFeed_PieceId _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);
        _Plate = Build_Plate(InHandle);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("give the piece a Kinematic body and a Resting on the plate, as a searing pan leaves it", n"Step_SearedPiece");
        Add_Step_WaitUntil("its body is in the simulation", n"Check_BodyAdded", 0, 2.0f);
        Add_Step("admit it just above the oil", n"Step_Admit");
        Add_Step_WaitUntil("it was admitted", n"Check_Added1", 0, 2.0f);
        Add_Step_WaitFrames("the retarget and the motion type land", 3);
        Add_Step("its Resting names the scoop and the basket; its own body is Dynamic", n"Step_AssertRetargeted");
        Add_Step_WaitUntil("the piece is in the oil", n"Check_InOil", 0, 3.0f);
        Add_Step("it floats like any piece", n"Step_AssertInOil");
        Run_Steps(InHandle);
    }

    // A kinematic 40 x 40 plate on its own entity under InHandle.
    private FCk_Handle_JoltBody Build_Plate(FCk_Handle InHandle)
    {
        auto PlateEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(PlateEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_PlateLocal), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(20.0, 20.0, 1.0));
        auto Spec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        Spec.Set_ShapeDimensions(Shape);
        Spec.Set_MotionType(ECk_MotionType::Kinematic);
        // Jolt asserts a positive mass even on a kinematic body; the value is never used.
        Spec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        Spec.Set_MassKg(1.0f);
        Spec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(PlateEntity, Spec);
    }

    UFUNCTION()
    private void Step_SearedPiece(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Food = _Pieces[0];
        FCk_Handle Entity = _Food;

        auto Convex = FCk_JoltBody_RuntimeConvexSpec();
        Convex.Set_PointsCm(utils_runtime_mesh::Copy_LocalVerticesCm(_Food.Get_Geometry()));
        auto Spec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::RuntimeConvex);
        Spec.Set_RuntimeConvex(Convex);
        Spec.Set_MotionType(ECk_MotionType::Kinematic);
        Spec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        Spec.Set_MassKg(float32(_Food.Get_MassKg()));
        Spec.Set_PersistContacts(ECk_EnableDisable::Enable);
        _Body = utils_jolt_body::Add(Entity, Spec);

        utils_resting::Add(Entity, FMars_Resting_Spec(_Plate));
    }

    UFUNCTION()
    private void Check_BodyAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_IsBodyAdded(_Body) && utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Food;
        const FCk_Handle Plate = _Plate;
        const auto Targets = Entity.As_Resting().Get_Targets();
        Assert_True(Targets.Num() == 1 && Targets[0] == Plate, "before admission the piece rests only on the plate's terms");

        _Piece = AddPiece(FVector(-30.0, 0.0, float64(_Spec.Oil.SurfaceZ) + Get_BoxHalfExtents().Z + 1.0));
    }

    UFUNCTION()
    private void Step_AssertRetargeted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AdmissionCountAccepted(), 1, "the piece was accepted");
        Assert_True(_Fry.Get_PieceBody(_Piece) == _Body, "the fryer kept the piece's own body");

        FCk_Handle Entity = _Food;
        const FCk_Handle Scoop = _Spec.Nodes.ScoopBody;
        const FCk_Handle Basket = _Spec.Nodes.BasketBody;
        const auto Targets = Entity.As_Resting().Get_Targets();
        Assert_Equals_Int(Targets.Num(), 2, "two targets after the admission");
        Assert_True(Targets.Num() == 2 && Targets[0] == Scoop && Targets[1] == Basket, "the targets are the scoop disc and the basket floor");
        Assert_True(utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Dynamic, "the piece's body is Dynamic again");
    }

    UFUNCTION()
    private void Check_InOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Oil);
    }

    UFUNCTION()
    private void Step_AssertInOil(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Oil, "the piece floats in the oil");
        Assert_Equals_Int(_Fry.Get_Tally().Lost, 0, "nothing was lost");
    }

    private int32 Get_AdmissionCountAccepted() const
    {
        auto Count = 0;
        for (const auto Admission : _Admissions)
        {
            if (Admission == EMars_CookingFeed_Admission::Accepted)
            { Count += 1; }
        }

        return Count;
    }
}
