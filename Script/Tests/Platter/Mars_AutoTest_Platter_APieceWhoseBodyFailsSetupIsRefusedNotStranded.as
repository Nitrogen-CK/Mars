// A Ready, bodiless piece whose own body cannot set up is refused, not stranded. Its spec names a collision profile that
// does not exist; the platter drops it and gives it that body, whose setup fails (InvalidProfile, a framework ensure). The
// platter refuses the piece Failed within Settle.MaxSeconds of the load (with an ensure of its own, naming the body's
// setup): nothing is pending or held, nothing landed, and the piece is off the platter's books. Both ensures are expected
// (the actor below).
class UMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(40000.0, -25000.0, -30000.0);
    // The load's drain and the poll after the refusal: a few frames.
    private const float32 k_RefusalSlackSeconds = 0.5f;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Spec = Make_PlatterSpec(2);
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Spec);

        auto PieceSpec = Make_Spec(0.5);
        PieceSpec.Body.CollisionProfileName = n"Mars_Test_NoSuchProfile";
        _P = Build_Piece(Get_BoxMesh(), FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), PieceSpec);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("load P", n"Step_Load");
        // The drop follows the load by one DropCadenceSeconds; a dropped body that never reaches the simulation is
        // refused at Settle.MaxSeconds.
        Add_Step_WaitUntil("P was refused within Settle.MaxSeconds of the load", n"Check_Refused", 0,
            Spec.Settle.DropCadenceSeconds + Spec.Settle.MaxSeconds + k_RefusalSlackSeconds);
        Add_Step("refused Failed; nothing pending, held or landed; P off the books", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _P;
        Assert_False(Entity.Is_JoltBody(), "P has no body before the drop");
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AllRefusalCount(_Platter) > 0 || TryGet_Loaded(_P).IsSet());
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_RefusalCount(_Platter, EMars_Platter_LoadRefusal::Failed), 1, "P was refused Failed");
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "nothing else was refused");
        Assert_False(TryGet_Loaded(_P).IsSet(), "P never landed");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing is pending");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty");
        Assert_True(ck::Is_NOT_Valid(_P.TryGet_Platter()), "P is off the platter's books");

        FCk_Handle Entity = _P;
        Assert_True(Entity.Is_JoltBody(), "the drop gave P its body");
        if (Entity.Is_JoltBody())
        {
            const auto Body = Entity.As_JoltBody();
            Assert_True(utils_jolt_body::Get_SetupState(Body) == ECk_JoltBody_SetupState::Failed, "P's body failed setup");
            Assert_True(utils_jolt_body::Get_SetupFailure(Body) == ECk_JoltBody_SetupFailure::InvalidProfile,
                f"for its collision profile (got {utils_jolt_body::Get_SetupFailure(Body) :n})");
        }
    }
}

// Hand-authored so the framework's ensure for the missing collision profile and the platter's own refusal ensure are
// expected rather than failures.
class AMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Platter_APieceWhoseBodyFailsSetupIsRefusedNotStranded;
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("collision profile [Mars_Test_NoSuchProfile] does not exist in UCollisionProfile");
        Out.Add("could not be loaded after");
        return Out;
    }
}
