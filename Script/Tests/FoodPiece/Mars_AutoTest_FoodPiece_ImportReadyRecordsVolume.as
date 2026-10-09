// A box piece composes Pending, then announces Ready exactly once with the mesh's volume (1000 cm3): a root with a new Id
// and Lineage, no parent, and the mass it was given.
class UMars_AutoTest_FoodPiece_ImportReadyRecordsVolume : UMars_AutoTestRig_FoodPiece
{
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Piece = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -40000.0)), Make_Spec(2.5));
        Assert_True(ck::IsValid(_Piece), "the piece composed");
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Pending, "a piece on an importing mesh starts Pending");

        Add_Step_WaitUntil("the piece announced Ready", n"Check_Readied");
        Add_Step_WaitSeconds("a second OnReady would arrive in this window", 0.2f);
        Add_Step("the piece is a Ready root with the mesh's volume", n"Step_AssertReady");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Readied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Piece));
    }

    UFUNCTION()
    private void Step_AssertReady(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Metrics = Get_Metrics(_Piece);
        ck::Trace(f"[FoodPiece test] box metrics: volume {Metrics.Get_VolumeCm3()} cm3, bounds {Metrics.Get_BoundsMinCm()}..{Metrics.Get_BoundsMaxCm()}, {Metrics.Get_TriangleCount()} tris");

        Assert_Equals_Int(_Readied.Num(), 1, "OnReady fired once");
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Ready, "the piece is Ready");
        Assert_False(_Piece.Get_IsCutting(), "the piece is not cutting");
        Assert_Equals_Float(_Piece.Get_VolumeCm3(), 1000.0, 0.01, "the piece's volume is the box's 1000 cm3");
        Assert_Equals_Float(_Piece.Get_VolumeCm3(), Metrics.Get_VolumeCm3(), 0.000000001, "the recorded volume is the geometry's");
        Assert_Equals_Float(_Piece.Get_MassKg(), 2.5, 0.0, "the mass is the spec's");
        Assert_True(_Piece.Get_Id().IsValid(), "the piece has an Id");
        Assert_True(_Piece.Get_Lineage().IsValid(), "a root gets a new Lineage");
        Assert_True(_Piece.Get_Lineage() != _Piece.Get_Id(), "the Lineage is not the Id");
        Assert_False(_Piece.Get_ParentId().IsValid(), "a root has no parent");
        Assert_Equals_Int(_Failures.Num(), 0, "no OnFailed");
    }
}
