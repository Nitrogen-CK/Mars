// The bowl takes a whole piece of a batterable food whose ledger is not battered. A whole piece of the rig's batterable
// test food is released over the bowl: the station's OnAdmission answers Accepted and OnPieceAdded names it; the bowl
// holds it bare (coat 0, at rest), attached under the bowl node, its holder the station; the bowl is Resting.
class UMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the whole batterable piece", n"Step_Admit");
        Add_Step_WaitUntil("the release is answered", n"Check_Answered1", 0, 0);
        Add_Step("it is in the bowl, bare", n"Step_AssertAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Pieces[0].Get_IsWhole(), "the piece is whole");
        Assert_True(utils_batter::Get_IsBatterable(_Pieces[0]), "the piece is batterable");
        Admit(0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Admissions[0] == EMars_CookingFeed_Admission::Accepted, f"accepted (reason: {_AdmissionReasons[0]})");
        Assert_Equals_Int(_AddedIds.Num(), 1, "one OnPieceAdded");
        Assert_Equals_Int(_Refusals.Num(), 0, "no OnAdmissionRefused");
        Assert_True(_Batter.Get_HasPiece(Make_Id(0)), "the bowl holds piece 0");
        if (_Batter.Get_HasPiece(Make_Id(0)) == false)
        { return; }

        Assert_Equals_Float(_Batter.Get_PieceCoat(Make_Id(0)), 0.0, 0.0, "a raw piece has no coat");
        Assert_Equals_Float(_Batter.Get_PieceImmersion(Make_Id(0)), 0.0, 0.0, "it rests above the batter");
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, "the bowl rests");

        FCk_Handle Entity = _Pieces[0];
        Assert_True(Entity.Is_SceneNode() && utils_scene_node::Get_Parent(Entity.As_SceneNode()) == _BowlNode, "it hangs under the bowl node");
        Assert_True(_Pieces[0].TryGet_Holder() == _StationEntity, "the station holds it");
    }
}
