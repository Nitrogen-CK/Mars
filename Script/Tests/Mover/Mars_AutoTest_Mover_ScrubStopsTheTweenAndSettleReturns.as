// A scrub puts the handle at an alpha right now: it stops an in-flight tween, holds there, and leaves the target alone.
// A settle then tweens back to the target pose from wherever the scrub left it, also when both land in one drain.
class UMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns : UCk_AutoTest_Base
{
    private FCk_Handle_Mover _Mover;
    private float32 _LowestAlphaWhileSettling = 1.0f;

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

        Add_Step("move to the end", n"Step_MoveToEnd");
        Add_Step_WaitUntil("the tween is mid-way", n"Check_MidTween", 0, 5.0f);
        Add_Step("scrub to 0.3", n"Step_Scrub");
        Add_Step_WaitSeconds("let the stopped tween stay stopped", 0.3f);
        Add_Step("the handle holds the scrubbed alpha and the target is unchanged", n"Step_AssertHeld");
        Add_Step("settle", n"Step_Settle");
        Add_Step_WaitUntil("the handle returns to the end pose", n"Check_AtEndPose", 0, 5.0f);
        Add_Step("the target is still the end", n"Step_AssertAtEnd");
        Add_Step("scrub and settle in the same frame", n"Step_ScrubAndSettle");
        Add_Step_WaitUntil("the handle returns to the end pose again", n"Check_SettledFromScrub", 0, 5.0f);
        Add_Step("the scrub landed before the settle tweened home", n"Step_AssertScrubLandedFirst");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_MoveToEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mover.Request_MoveTo(true);
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
        const auto Alpha = _Mover.Get_Alpha();
        Assert_True(Math::Abs(Alpha - 0.3f) < 0.001f, f"a scrub stops the tween and holds (alpha {Alpha})");
        Assert_True(_Mover.Get_AtEnd(), "scrub leaves the target alone");
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
        Res.Set(_Mover.Get_Alpha() > 0.999f);
    }

    UFUNCTION()
    private void Step_AssertAtEnd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_AtEnd(), "a settle does not change the target");
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
        Assert_True(_Mover.Get_AtEnd(), "the target is still the end");
    }
}
