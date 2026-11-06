// A route answer stamped with an older route generation changes nothing: while the launch route (generation G) is pending,
// a Reached and an Unreachable carrying G - 1 arrive (what a superseded MoveTo's late crowd answer looks like after
// Issue_Move stamped it); the route stays Pending on G and no outcome is broadcast. The same Unreachable stamped G is then
// taken: the route ends Unreachable and OnRouteOutcome reports generation G once (the control that the request path is
// live, so the first half is not vacuous).
class UMars_AutoTest_Bat_StaleRouteAnswerIsIgnored : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -144000.0, 2000.0);

    // Frames the stale answers get to (wrongly) land before the route is checked.
    private const int32 k_SettleFrames = 5;

    private int32 _Generation = -1;
    private int32 _OutcomesBefore = 0;
    private int32 _Frames = 0;
    private TArray<int32> _OutcomeGenerations;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it launches on a pending route", n"Check_RoutePending", 0, k_FlightSeconds);
        Add_Step("answers for the previous generation arrive", n"Step_SendStaleAnswers");
        Add_Step_WaitUntil("a few frames pass", n"Check_Settled");
        Add_Step("the pending route ignored them", n"Step_AssertIgnored");
        Add_Step("the same answer for the current generation arrives", n"Step_SendCurrentAnswer");
        Add_Step_WaitUntil("the route reports it", n"Check_Answered", 0, 5.0f);
        Add_Step("it was taken once, for the current generation", n"Step_AssertTaken");
        Run_Steps(InHandle);
    }

    private FMars_Bat_Route Get_Route() const
    {
        return _Bat.Get_Fragment(FMars_Fragment_Bat).Route;
    }

    UFUNCTION()
    private void Check_RoutePending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Launching && Get_Route().Outcome == EMars_Bat_RouteOutcome::Pending);
    }

    UFUNCTION()
    private void Step_SendStaleAnswers(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Generation = Get_Route().Generation;
        _OutcomesBefore = _Outcomes.Num();
        _Bat.BindTo_OnRouteOutcome(FMars_Delegate_Bat_OnRouteOutcome(this, n"OnOutcomeGeneration"));

        const auto Stale = _Generation - 1;
        _Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome::Reached, Stale));
        _Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome::Unreachable, Stale));
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Frames += 1;
        Res.Set(_Frames >= k_SettleFrames);
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Route = Get_Route();
        Log(f"[BatTest] stale route answer: generation {_Generation}, route now {Route.Generation}:{Route.Outcome}, outcomes {_Outcomes.Num() - _OutcomesBefore}, phases [{Get_PhaseTrail()}]");
        Assert_Equals_Int(Route.Generation, _Generation, "no new route was issued while the stale answers were in flight");
        Assert_True(Route.Outcome == EMars_Bat_RouteOutcome::Pending, f"the current route is still Pending (got {Route.Outcome})");
        Assert_Equals_Int(_Outcomes.Num(), _OutcomesBefore, "no route outcome was broadcast for the stale answers");
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Launching, f"it is still launching (got {_Bat.Get_Phase()})");
    }

    UFUNCTION()
    private void Step_SendCurrentAnswer(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome::Unreachable, _Generation));
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutcomeGenerations.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertTaken(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[BatTest] current route answer: outcomes for generations {_OutcomeGenerations.Num()}, first {_OutcomeGenerations[0]}, route now {Get_Route().Generation}:{Get_Route().Outcome}");
        Assert_Equals_Int(_OutcomeGenerations[0], _Generation, "the first outcome after the stale answers is for the current generation");
        Assert_True(_Outcomes[_OutcomesBefore] == EMars_Bat_RouteOutcome::Unreachable, f"and it is the Unreachable stamped with it (got {_Outcomes[_OutcomesBefore]})");
        auto ForCurrent = 0;
        for (auto Generation : _OutcomeGenerations)
        {
            if (Generation == _Generation)
            { ForCurrent += 1; }
        }

        Assert_Equals_Int(ForCurrent, 1, "generation G got exactly one outcome");
    }

    UFUNCTION()
    private void OnOutcomeGeneration(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome)
    {
        _OutcomeGenerations.Add(InGeneration);
    }
}
