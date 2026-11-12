// The server slices the meat slab by hand through its centre, slices the positive half again at 9 cm (normal +X) and spawns
// that slice's two pieces first; a step later it spawns the two halves of the first slice, and a step later destroys the
// slab and the positive half. On the client no frame shows a piece standing with one it was cut from; once both
// grandchildren stand the slab reads Superseded; the positive half reads Superseded from its first frame as a FoodPiece and
// never stands; the negative half stands.
// Surface: Ck.FoodPiece.Net.AS_FoodPiece_GrandchildrenBeforeTheirParent
class UCk_AutoTest_Net_FoodPiece_GrandchildrenBeforeTheirParent : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 184000.0;
    private const float32 k_ServerWatchSeconds = 4.0f;

    // Client: the positive half once seen, and frames in which both grandchildren stood beside a living slab that did not
    // read Superseded.
    private FCk_Handle _ClientP;
    private int32 _GrandchildrenFrames = 0;
    private int32 _GrandchildrenBad = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            WaitUntil(n"Is_ClientSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        Begin_ServerSlab(InHandle);
    }

    private FCk_RuntimeMesh_PlaneLocal Make_SecondPlane()
    {
        return Make_Plane(FVector(9.0, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector);
    }

    protected void On_ServerSlabStill() override
    {
        Begin_ByHandHalves();
    }

    protected void On_ServerHalvesHeld() override
    {
        Slice_ByHand(_BirthP.Geometry, Make_SecondPlane(), _WholeSpec.Cap);
        WaitUntil(n"Is_ServerSecondSliced", n"OnServerSecondSliced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSecondSliced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ByHandSlices.Num() >= 2);
    }

    UFUNCTION()
    private void OnServerSecondSliced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Second = _ByHandSlices[1];
        Assert_True(Second.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the second slice succeeded (got {Second.Get_Outcome() :n})");
        if (Second.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            End_Server();
            return;
        }

        Spawn_ByHand(Make_ByHandBirth(_BirthP.Spec, Second, FMars_FoodPiece_RecipeCut(Make_SecondPlane(), EMars_FoodPiece_CutSide::Positive)));
        Spawn_ByHand(Make_ByHandBirth(_BirthP.Spec, Second, FMars_FoodPiece_RecipeCut(Make_SecondPlane(), EMars_FoodPiece_CutSide::Negative)));
        WaitSeconds(k_StepSeconds, n"OnServerSpawnHalves");
    }

    UFUNCTION()
    private void OnServerSpawnHalves(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_P();
        Spawn_N();
        WaitSeconds(k_StepSeconds, n"OnServerDestroySources");
    }

    UFUNCTION()
    private void OnServerDestroySources(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Destroy_Whole();
        if (ck::IsValid(_SpawnedP))
        { utils_entity_lifetime::Request_DestroyEntity(_SpawnedP); }

        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"pieces={Get_ReadyPieceCountNear(_FloorTop)}");
        End_Server();
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (ck::Is_NOT_Valid(_ClientP))
        { _ClientP = Find_ByRecipe(Get_PieceEntitiesNear(_FloorTop), 1, EMars_FoodPiece_CutSide::Positive); }

        auto Grandchildren = 0;
        for (const auto& Piece : InStanding)
        {
            if (Piece.Get_Recipe().Cuts.Num() == 2)
            { ++Grandchildren; }
        }

        const auto Whole = Find_FoodPieceNear(_FloorTop);
        if (Grandchildren < 2 || ck::Is_NOT_Valid(Whole))
        { return; }

        ++_GrandchildrenFrames;
        if (Get_IsSuperseded(Whole) == false)
        { ++_GrandchildrenBad; }
    }

    UFUNCTION()
    private void Is_ClientSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_WholeStood && ck::IsValid(_ClientP) && Get_IsLive(_ClientP) == false && ck::Is_NOT_Valid(Find_FoodPieceNear(_FloorTop))
            && Get_StandingNear(_FloorTop).Num() == 3);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Sampling();
        const auto PSighting = Get_Sighting(_ClientP);
        const auto Negative = Find_ByRecipe(Get_PieceEntitiesNear(_FloorTop), 1, EMars_FoodPiece_CutSide::Negative);

        Assert_Equals_Int(_Both, 0, "no frame shows a piece standing with one it was cut from");
        Assert_True(_GrandchildrenFrames > 0, "the slab was alive while both grandchildren stood");
        Assert_Equals_Int(_GrandchildrenBad, 0, "once both grandchildren stand the slab reads Superseded");
        Assert_True(PSighting.PieceFrame >= 0, "the positive half was a FoodPiece on the client");
        Assert_True(PSighting.FirstStanding == EMars_FoodPiece_Standing::Superseded, f"the positive half reads Superseded from its first frame (got {PSighting.FirstStanding :n})");
        Assert_Equals_Int(PSighting.StoodFrame, -1, "the positive half never stands");
        Assert_True(Get_Stands(Negative), "the negative half stands");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_Result(f"{Describe_Standing()} grandchildren={_GrandchildrenFrames} bad={_GrandchildrenBad} pFirst={PSighting.FirstStanding :n} pStood={PSighting.StoodFrame} {Describe_Tally()}");
        End_Client();
    }
}
