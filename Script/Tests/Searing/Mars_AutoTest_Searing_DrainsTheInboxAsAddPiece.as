// The pan's drain takes the station's admission inbox as its AddPiece: one release sent to the station's inbox is answered
// Accepted on the station's OnAdmission, OnPieceAdded names it, the pan holds it, the piece names the station as its holder
// and the inbox is empty. In a later drain, the same piece released again under a new Id is Rejected "already admitted"
// and a release that carries no piece is Rejected "no piece", both on the same signal and in arrival order; the pan still
// holds the one piece.
class UMars_AutoTest_Searing_DrainsTheInboxAsAddPiece : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_RepeatLocal = FVector(8.0, 0.0, 8.0);

    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _RepeatId;
    private FMars_CookingFeed_PieceId _EmptyId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release one piece into the station's inbox", n"Step_Release");
        Add_Step_WaitUntil("the release was answered", n"Check_Answered1", 0, 0);
        Add_Step("accepted, added, held, and the inbox is empty; release it again and an empty release", n"Step_AssertAdmittedThenRepeat");
        Add_Step_WaitUntil("both releases were answered", n"Check_Answered3", 0, 0);
        Add_Step("both rejected with their reasons", n"Step_AssertRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstId = AddPiece();
    }

    UFUNCTION()
    private void Check_Answered1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 1);
    }

    UFUNCTION()
    private void Check_Answered3(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertAdmittedThenRepeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 1, "one answer");
        if (_Admissions.Num() != 1)
        { return; }

        Assert_True(_AdmissionIds[0].Get_IsSame(_FirstId), "the answer names the release's Id");
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"the release is accepted (reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_Added.Num(), 1, "one OnPieceAdded");
        if (_Added.Num() == 1)
        {
            Assert_True(_AddedIds[0].Get_IsSame(_FirstId), "OnPieceAdded names the Id");
            Assert_True(_Added[0] == _Pieces[0], "OnPieceAdded names the released piece");
        }

        Assert_True(_Searing.Get_HasPiece(_FirstId), "the pan holds the piece");
        Assert_True(_Pieces[0].TryGet_Holder() == _StationEntity, "the piece names the station as its holder");
        Assert_Equals_Int(_StationEntity.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num(), 0, "the inbox is empty");

        _RepeatId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        Release_ThePiece(_RepeatId, _Pieces[0], k_RepeatLocal);

        _EmptyId = FMars_CookingFeed_PieceId(k_Generation, _NextIndex);
        _NextIndex += 1;
        auto Empty = FMars_CookingFeed_Release(_EmptyId, FTransform(k_Origin), FVector::ZeroVector);
        Assert_True(utils_cooking_feed::Request_Admit(_StationEntity, Empty), "the station queues a release with no piece");
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 3, "three answers in all");
        if (_Admissions.Num() != 3)
        { return; }

        Assert_True(_AdmissionIds[1].Get_IsSame(_RepeatId), "the second answer is the repeat's");
        Assert_True(_Admissions[1] == EMars_CookingFeed_Admission::Rejected, "the repeat is rejected");
        Assert_True(_AdmissionReasons[1] == "already admitted", f"the repeat's reason (got {_AdmissionReasons[1]})");

        Assert_True(_AdmissionIds[2].Get_IsSame(_EmptyId), "the third answer is the empty release's");
        Assert_True(_Admissions[2] == EMars_CookingFeed_Admission::Rejected, "the empty release is rejected");
        Assert_True(_AdmissionReasons[2] == "no piece", f"the empty release's reason (got {_AdmissionReasons[2]})");

        Assert_Equals_Int(_Added.Num(), 1, "still one OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 1, "the pan holds one piece");
        Assert_True(_Pieces[0].TryGet_Holder() == _StationEntity, "the station is still the piece's holder");
        Assert_Equals_Int(_StationEntity.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Num(), 0, "the inbox is empty");
    }
}

class AMars_AutoTest_Searing_DrainsTheInboxAsAddPiece_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_DrainsTheInboxAsAddPiece;
}
