// Leaving mid-cut keeps the halves for the next operator. The operator leaves in the very frame the board issues the chop's
// cut; the cut commits anyway (the board resolves its own cuts) and its halves are dressed. Idle clears nothing and builds
// nothing, so when the station is taken again the board holds exactly the joint's two halves, touched, and the intake (an
// occupied board) takes nothing more.
class UMars_AutoTest_DicingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(14400.0, -9000.0, -30000.0);

    private bool _LeaveOnIssue = false;
    private bool _InFlightWhenLeft = false;

    private FCk_Handle_FoodPiece _Joint;
    private FGuid _JointId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);

        Add_Steps_IntakeTheJoint();
        Add_Step("chop; when the cut is issued, leave", n"Step_Chop");
        Add_Step_WaitUntil("the operator left and the cut committed into two shown halves", n"Check_CommittedAfterLeaving", 0, 5.0f);
        Add_Step("an operator takes the station again", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitFrames("an intake or a clear would have drained by now", 5);
        Add_Step("the board holds the two halves, touched", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _Board.Get_Held()[0];
        _JointId = _Joint.Get_Id();
        Watch(_Joint);

        _LeaveOnIssue = true;
        Chop();
    }

    // The board has handed the joint its cut; the joint has not sliced yet. The operator leaves in this very frame.
    protected void On_CutIssued(const FMars_FoodBoard_CutIssue& InIssue) override
    {
        if (_LeaveOnIssue == false)
        { return; }

        _LeaveOnIssue = false;
        _InFlightWhenLeft = InIssue.Issued == 1 && _Joint.Get_HasBoardCutPending();
        Leave();
    }

    // A cut that did not commit settles at once so the assertions report it.
    UFUNCTION()
    private void Check_CommittedAfterLeaving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsIdle = utils_state_machine::Get_CurrentStateClass(_Station.Get_MinigameSm()) == UMars_SmState_Dicing_Idle;
        const auto IsSettled = Get_OutcomeCountFor(_Joint) > 0 && (_PieceCuts == 0 || (_Board.Get_HeldCount() == 2 && Get_AllHeldShown()));

        auto Res = OutResult;
        Res.Set(IsIdle && IsSettled);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_InFlightWhenLeft, "the joint's cut was issued and in flight when the operator left");
        Assert_Equals_Int(Get_OutcomeCount(_Joint, EMars_FoodPiece_CutOutcome::Cut), 1, "the joint's cut committed after the operator left");
        Assert_Equals_Int(_PieceCuts, 1, "the board took the halves");
        Assert_Equals_Int(_Cleared, 0, "nothing cleared the board");

        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board holds the two halves");
        Assert_False(_Board.Get_IsUntouched(), "the board is touched");
        for (const auto& Half : _Board.Get_Held())
        {
            Assert_True(Half.Get_ParentId() == _JointId, f"[{Half.ToString()}] was cut from the joint");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] is shown");
        }

        Assert_Equals_Int(_Placed.Num(), 1, "only the intake's joint was ever placed: no new joint");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is still empty");
    }
}
