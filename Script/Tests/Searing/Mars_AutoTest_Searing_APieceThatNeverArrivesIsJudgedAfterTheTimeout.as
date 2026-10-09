// An adopted piece whose pose never reaches its release is not left unjudged. A box is released over the pan's centre and,
// the moment the kernel admits it, the test hangs it as a scene-node child of a node of its own 300 cm away, so the pose
// the admission asked for is rejected (the parent owns a scene node's world transform) and the piece stays held there.
// Half a second in, the kernel still holds it as arriving (it judges nothing about a piece that is not where it was
// released); past utils_searing::k_ArrivalMaxSeconds it ensures, naming the piece and its distance, and judges it where it
// is: the piece is no longer arriving and is still on the kernel's books.
class UMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    // Where the test's node holds the piece, from the station's origin: far from the release over the pan.
    private const FVector k_HoldLocal = FVector(0.0, 300.0, 100.0);

    private FCk_Handle_Transform _HoldNode;
    private FMars_CookingFeed_PieceId _PieceId;
    private FCk_Handle_FoodPiece _Piece;
    private bool _IsAttached = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);
        _Searing.BindTo_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnAdmittedHold"));

        auto HoldEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _HoldNode = utils_transform::Add(HoldEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_HoldLocal), ECk_Replication::DoesNotReplicate);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's piece is ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("release the piece over the pan's centre", n"Step_Release");
        Add_Step_WaitUntil("the kernel admitted it and the test holds it away", n"Check_AdmittedAndHeld", 0, 3.0f);
        Add_Step_WaitSeconds("half the arrival timeout", 0.5f);
        Add_Step("the piece is still arriving: nothing judges it", n"Step_AssertStillArriving");
        Add_Step_WaitUntil("the kernel stopped waiting for it", n"Check_NoLongerArriving", 0, 2.0f);
        Add_Step("it timed out and is judged where it is", n"Step_AssertJudged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = _Pieces[0];
        _PieceId = AddPiece();
    }

    // The admission has already asked for the release pose; the attach overrides it from here on.
    UFUNCTION()
    private void OnAdmittedHold(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        if (InAdmission != EMars_CookingFeed_Admission::Accepted || InPieceId.Get_IsSame(_PieceId) == false)
        { return; }

        FCk_Handle PieceEntity = _Piece;
        auto PieceTransform = PieceEntity.As_Transform();
        utils_scene_node::Add(PieceTransform, _HoldNode, FTransform::Identity);
        _IsAttached = true;
    }

    UFUNCTION()
    private void Check_AdmittedAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_IsAttached && _Searing.Get_HasPiece(_PieceId));
    }

    UFUNCTION()
    private void Step_AssertStillArriving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto State = _Searing.Get_PieceState(_PieceId);
        Assert_True(State.Arriving.IsSet(), "the piece is still arriving half a second in");
        Assert_True(State.ArrivingSeconds < utils_searing::k_ArrivalMaxSeconds, f"its arrival clock [{State.ArrivingSeconds}] is under the timeout");
        Assert_Equals_Int(_Contacts.Num(), 0, "no contact edge was judged for it");
    }

    UFUNCTION()
    private void Check_NoLongerArriving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasPiece(_PieceId) == false || _Searing.Get_PieceState(_PieceId).Arriving.IsSet() == false);
    }

    UFUNCTION()
    private void Step_AssertJudged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_HasPiece(_PieceId), "the piece is still on the kernel's books");
        if (_Searing.Get_HasPiece(_PieceId) == false)
        { return; }

        const auto State = _Searing.Get_PieceState(_PieceId);
        Assert_False(State.Arriving.IsSet(), "the piece is no longer arriving");
        Assert_True(State.ArrivingSeconds >= utils_searing::k_ArrivalMaxSeconds,
            f"it stopped arriving only at the timeout (after {State.ArrivingSeconds} s)");
        Assert_True(_Searing.Get_PieceContact(_PieceId) != EMars_Searing_Contact::OnPan, "held 300 cm away, it is not on the pan");
    }
}

// Hand-authored so the ensures the test provokes on purpose are expected rather than failures: the kernel's (a piece that
// never arrives) and CkSceneNode's rejection of the admission's pose request on the piece the test hangs off its node.
class AMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_APieceThatNeverArrivesIsJudgedAfterTheTimeout;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("never arrived at its release");
        Out.Add("Transform request rejected on parent-driven SceneNode");
        return Out;
    }
}
