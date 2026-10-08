// A start runs Windup -> Strike -> Recover -> None on the request's timeline and moves the node it was given along the
// arc, leaving it at rest. Make_Timeline puts the impact fraction of the strike travel on ImpactSeconds and the rest on
// ImpactSeconds + RecoverySeconds; Evaluate lands on the windup key, the strike key and identity at the boundaries. In
// flight the node's offset has left rest; once the swing ends the pose and the node are identity again and the phases
// were announced in order. Isolated Z band: -84000.
class UMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -84000.0);
    private FCk_Handle_HandSwing _Swing;
    private FCk_Handle_SceneNode _Node;
    private TArray<EMars_HandSwing_Phase> _Phases;

    private float32 _ImpactSeconds = 0.5f;
    private float32 _RecoverySeconds = 0.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Node = utils_scene_node::Create(Root, FTransform::Identity);
        _Swing = utils_hand_swing::Add(Entity, FMars_HandSwing_Spec(_Node));
        _Swing.BindTo_OnPhaseChanged(FMars_Delegate_HandSwing_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step("the timeline places the impact and the keys sit on the boundaries", n"Step_AssertTimeline");
        Add_Step("start", n"Step_Start");
        Add_Step_WaitUntil("the strike travel", n"Check_PastWindup", 0, 2.0f);
        Add_Step("in flight the node has left rest", n"Step_AssertInFlight");
        Add_Step_WaitUntil("back at rest", n"Check_AtRest", 0, 3.0f);
        Add_Step("the phases ran in order and the node is at rest", n"Step_AssertDone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_HandSwing InSwing, EMars_HandSwing_Phase InPrevious, EMars_HandSwing_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void Step_AssertTimeline(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Swing, "utils_hand_swing::Add composed the swing");
        Assert_False(_Swing.Get_IsSwinging(), "a fresh swing is at rest");
        Assert_True(_Swing.Get_Pose().Equals(FTransform::Identity), "a fresh swing's pose is identity");

        const auto Arc = MakeArc();
        const auto Timeline = utils_hand_swing::Make_Timeline(Arc, _ImpactSeconds, _RecoverySeconds);
        Assert_Equals_Float(Timeline.WindupEnd, _ImpactSeconds - Arc.StrikeSeconds * Arc.ImpactFraction, 0.0001,
            "the windup ends ImpactFraction of the strike travel before the impact");
        Assert_Equals_Float(Timeline.StrikeEnd, Timeline.WindupEnd + Arc.StrikeSeconds, 0.0001, "the strike travel lasts StrikeSeconds");
        Assert_Equals_Float(Timeline.RecoverEnd, _ImpactSeconds + _RecoverySeconds, 0.0001, "rest comes RecoverySeconds after the impact");

        const auto Rest = FTransform::Identity;
        Assert_True(utils_hand_swing::Evaluate(Arc, Timeline, Rest, 0.0f).Equals(Rest, 0.001), "at 0 the hand is where it started");
        Assert_True(utils_hand_swing::Evaluate(Arc, Timeline, Rest, Timeline.WindupEnd).Equals(utils_hand_swing::Make_Pose(Arc.Windup), 0.001),
            "at the windup's end the hand is on the windup key");
        Assert_True(utils_hand_swing::Evaluate(Arc, Timeline, Rest, Timeline.StrikeEnd).Equals(utils_hand_swing::Make_Pose(Arc.Strike), 0.001),
            "at the strike's end the hand is on the strike key");
        Assert_True(utils_hand_swing::Evaluate(Arc, Timeline, Rest, Timeline.RecoverEnd).Equals(Rest, 0.001),
            "at the recovery's end the hand is back at rest");
        Assert_True(utils_hand_swing::Get_PhaseAt(Timeline, Timeline.RecoverEnd) == EMars_HandSwing_Phase::None,
            "past the recovery the phase is None");

        // ImpactFraction is a fraction of the strike's time: at the impact the hand is where the strike's easing puts it.
        const auto AtImpact = utils_hand_swing::Evaluate(Arc, Timeline, Rest, _ImpactSeconds);
        const auto Expected = Math::Lerp(Arc.Windup.Location, Arc.Strike.Location, float(utils_hand_swing::Ease(Arc.Strike.Easing, Arc.ImpactFraction)));
        Assert_True(AtImpact.GetLocation().Equals(Expected, 0.01),
            f"at the impact the hand is ImpactFraction of the strike's time along its eased travel (got [{AtImpact.GetLocation()}], expected [{Expected}])");
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Swing.Request_Start(FMars_Request_HandSwing_Start(MakeArc(), _ImpactSeconds, _RecoverySeconds));
    }

    UFUNCTION()
    private void Check_PastWindup(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Phase = _Swing.Get_Phase();
        Res.Set(Phase == EMars_HandSwing_Phase::Strike || Phase == EMars_HandSwing_Phase::Recover);
    }

    UFUNCTION()
    private void Step_AssertInFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Swing.Get_IsSwinging(), "the swing is in flight");
        Assert_True(_Swing.Get_Pose().Equals(FTransform::Identity, 0.01) == false, "in flight the pose has left rest");
        Assert_True(utils_scene_node::Get_Offset(_Node).Equals(FTransform::Identity, 0.01) == false, "in flight the node has left rest");
        Assert_True(_Phases.Num() >= 2 && _Phases[0] == EMars_HandSwing_Phase::Windup && _Phases[1] == EMars_HandSwing_Phase::Strike,
            f"the swing announced Windup then Strike (got {_Phases.Num()} phases)");
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Swing.Get_IsSwinging() == false);
    }

    UFUNCTION()
    private void Step_AssertDone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Phases.Num() == 4, f"four phase changes were announced (got {_Phases.Num()})");
        if (_Phases.Num() == 4)
        {
            Assert_True(_Phases[0] == EMars_HandSwing_Phase::Windup && _Phases[1] == EMars_HandSwing_Phase::Strike
                && _Phases[2] == EMars_HandSwing_Phase::Recover && _Phases[3] == EMars_HandSwing_Phase::None,
                "the phases ran Windup, Strike, Recover, None");
        }

        Assert_True(_Swing.Get_Pose().Equals(FTransform::Identity, 0.001), f"at rest the pose is identity (got [{_Swing.Get_Pose()}])");
        Assert_True(utils_scene_node::Get_Offset(_Node).Equals(FTransform::Identity, 0.001),
            f"at rest the node is back at identity (got [{utils_scene_node::Get_Offset(_Node)}])");
        Assert_True(_Swing.Get_Elapsed() >= _Swing.Get_Timeline().RecoverEnd, "the clock ran past the recovery's end");
    }

    // Slow enough that every phase spans several frames in a headless lane.
    private FMars_HandSwing_Arc MakeArc() const
    {
        auto Arc = utils_hand_swing::Make_ChopArc();
        Arc.StrikeSeconds = 0.3f;
        Arc.ImpactFraction = 0.65f;
        return Arc;
    }
}
