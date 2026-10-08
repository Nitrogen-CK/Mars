// A scrub puts the handle at an alpha right now: it stops an in-flight tween, holds there, and leaves the target alone.
// A settle then tweens back to the target pose from wherever the scrub left it, also when both land in one drain. Resting
// (Get_IsResting) is at the target with no tween: not after the scrub, not while the settle runs, again once it lands.
class UMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns : UCk_AutoTest_Base
{
    private FCk_Handle_Mover _Mover;
    private float32 _LowestAlphaWhileSettling = 1.0f;
    private int32 _SettlingSamples = 0;
    private int32 _RestingWhileSettlingSamples = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = FMars_Mover_Spec();
        Spec.EndLocation = FVector(0.0, 0.0, 10.0);
        Spec.Duration = 0.5f;
        _Mover = utils_mover::Add(Node, Spec);

        Add_Step("the handle rests at the start pose before anything moves", n"Step_AssertRestingAtStart");
        Add_Step("move to the end", n"Step_MoveToEnd");
        Add_Step_WaitUntil("the tween is mid-way", n"Check_MidTween", 0, 5.0f);
        Add_Step("scrub to 0.3", n"Step_Scrub");
        Add_Step_WaitSeconds("let the stopped tween stay stopped", 0.3f);
        Add_Step("the handle holds the scrubbed alpha and the target is unchanged", n"Step_AssertHeld");
        Add_Step("settle", n"Step_Settle");
        Add_Step_WaitUntil("the handle returns to the end pose", n"Check_AtEndPose", 0, 5.0f);
        Add_Step_WaitUntil("the settle tween lands and the handle rests", n"Check_Resting", 0, 1.0f);
        Add_Step("the target is still the end, and the handle rests there", n"Step_AssertAtEnd");
        Add_Step("scrub and settle in the same frame", n"Step_ScrubAndSettle");
        Add_Step_WaitUntil("the handle returns to the end pose again", n"Check_SettledFromScrub", 0, 5.0f);
        Add_Step("the scrub landed before the settle tweened home", n"Step_AssertScrubLandedFirst");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRestingAtStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_IsResting(), "a fresh mover rests at its start pose");
    }

    UFUNCTION()
    private void Step_MoveToEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
    }

    UFUNCTION()
    private void Check_MidTween(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Alpha = _Mover.Get_Alpha();
        Res.Set(Alpha > 0.05f && Alpha < 0.6f);
    }

    UFUNCTION()
    private void Step_Scrub(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mover.Request_Scrub(FMars_Request_Mover_Scrub(0.3f));
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Mover.Get_Alpha(), 0.3f, 0.001f, "a scrub stops the tween and holds the scrubbed alpha");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "scrub leaves the target alone");
        Assert_False(_Mover.Get_IsResting(), "a scrub that left the handle off the target is not rest");
    }

    UFUNCTION()
    private void Step_Settle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mover.Request_Settle();
    }

    UFUNCTION()
    private void Check_AtEndPose(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Alpha = _Mover.Get_Alpha();
        if (Alpha < 0.999f)
        {
            _SettlingSamples += 1;
            if (_Mover.Get_IsResting())
            { _RestingWhileSettlingSamples += 1; }
        }

        Res.Set(Alpha > 0.999f);
    }

    UFUNCTION()
    private void Check_Resting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mover.Get_IsResting());
    }

    UFUNCTION()
    private void Step_AssertAtEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "a settle does not change the target");
        Assert_True(_SettlingSamples > 0, "the settle was observed under way");
        Assert_Equals_Int(_RestingWhileSettlingSamples, 0, "a handle the settle tween is still carrying is not rest");
        Assert_Equals_Float(_Mover.Get_Alpha(), 1.0f, 0.0001f, "a resting handle sits exactly on the end pose");
    }

    UFUNCTION()
    private void Step_ScrubAndSettle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LowestAlphaWhileSettling = 1.0f;
        _Mover.Request_Scrub(FMars_Request_Mover_Scrub(0.3f));
        _Mover.Request_Settle();
    }

    UFUNCTION()
    private void Check_SettledFromScrub(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Alpha = _Mover.Get_Alpha();
        _LowestAlphaWhileSettling = Math::Min(_LowestAlphaWhileSettling, Alpha);
        Res.Set(Alpha > 0.999f);
    }

    UFUNCTION()
    private void Step_AssertScrubLandedFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LowestAlphaWhileSettling < 0.5f,
            f"the settle tweened from the scrubbed alpha (lowest alpha seen {_LowestAlphaWhileSettling})");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "the target is still the end");
    }
}
