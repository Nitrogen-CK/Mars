// Two pieces on the pan are the world's, not the station's (their lifetime owner is the world's transient entity), yet they
// end with the station: two frames after the station entity is destroyed, both are gone or pending destroy.
class UMars_AutoTest_Searing_StationDestroyedEndsItsPieces : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_LeftLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_RightLocal = FVector(8.0, 0.0, 8.0);

    private TArray<FCk_Handle> _PieceEntities;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(2);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("add two pieces", n"Step_AddTwo");
        Add_Step_WaitUntil("both pieces landed on the pan", n"Check_BothOnPan", 0, 3.0f);
        Add_Step("the pieces are the world's; destroy the station", n"Step_DestroyStation");
        Add_Step_WaitFrames("the station's teardown runs", 2);
        Add_Step("both pieces ended with the station", n"Step_AssertPiecesEnded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AddPieceAt(k_LeftLocal);
        AddPieceAt(k_RightLocal);
    }

    UFUNCTION()
    private void Check_BothOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_AddedIds.Num() == 2 && Get_IsOnPan(_AddedIds[0]) && Get_IsOnPan(_AddedIds[1]));
    }

    UFUNCTION()
    private void Step_DestroyStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& PieceId : _AddedIds)
        {
            const auto Entity = _Searing.Get_PieceEntity(PieceId);
            Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Entity) == ck::TransientEntity(),
                f"piece {utils_cooking_feed::Get_PieceName(PieceId)} belongs to the world's transient entity, not the station");
            _PieceEntities.Add(Entity);
        }

        utils_entity_lifetime::Request_DestroyEntity(_StationEntity);
    }

    UFUNCTION()
    private void Step_AssertPiecesEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PieceEntities.Num(), 2, "two pieces were on the pan");
        for (const auto& Entity : _PieceEntities)
        {
            const auto Ended = ck::Is_NOT_Valid(Entity)
                || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
            Assert_True(Ended, f"piece [{Entity.ToString()}] ended with the station");
        }
    }
}

class AMars_AutoTest_Searing_StationDestroyedEndsItsPieces_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_StationDestroyedEndsItsPieces;
}
