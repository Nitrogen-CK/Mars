// A fast upward look (40 degrees in one frame, far above LiftFlickSpeedDegreesPerSecond) kicks the pan up; the kinematic
// push launches the resting piece, which leaves the pan and either lands back on it (a flip if it settled on another face)
// or is lost (nothing replaces it). Which face lands is the physics' business; the test pins the toss and a legal end,
// then the lift settling.
class UMars_AutoTest_Searing_FastUpwardLookTossesTheSteak : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 12.0f;

    private int32 _ContactsBeforeToss = 0;
    private EMars_Searing_Face _DownFaceBefore = EMars_Searing_Face::NegZ;
    private float32 _TossTime = -1.0f;
    private float32 _AirborneTime = -1.0f;
    private float32 _PeakLiftVelocity = 0.0f;
    // Recorded when the toss ended: landed (else lost), and after how long in the air.
    private bool _Landed = false;
    private float32 _EndAirSeconds = -1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Tilt.LevelReturnDegreesPerSecond = 45.0f;
        BuildStation(InHandle, Spec, PanSpec);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Steps_AddPieceAndLand();
        Add_Step_WaitSeconds("the piece settles", 0.3f);
        Add_Step("flick the look up", n"Step_Flick");
        Add_Step_WaitUntil("the pan lifted", n"Check_PanLifted", 0, 0.3f);
        Add_Step_WaitUntil("the piece left the pan", n"Check_TossedAirborne", 0, 0.6f);
        Add_Step_WaitUntil("the piece landed or was lost", n"Check_LandedOrLost", 0, 3.0f);
        Add_Step("record how the toss ended", n"Step_RecordOutcome");
        // A landed face counts as a flip only once it stayed down for utils_searing::k_FaceSettleSeconds.
        Add_Step_WaitSeconds("the resting face settles", 0.3f);
        Add_Step("a legal end: a landing, or one loss", n"Step_AssertOutcome");
        Add_Step_WaitSeconds("the lift spring settles", 0.6f);
        Add_Step("nothing replaced the piece", n"Step_AssertNoReplacement");
        Add_Step("the pan is back at rest", n"Step_AssertLiftSettled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Flick(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsOnPan(Get_FirstId()), "the piece rests on the pan before the flick");
        _ContactsBeforeToss = _Contacts.Num();
        _DownFaceBefore = _Searing.Get_DownFace(Get_FirstId());
        _TossTime = Get_Now();
        Look(FVector(0.0, -40.0, 0.0));
    }

    UFUNCTION()
    private void Check_PanLifted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_PeakLiftVelocity();
        auto Res = OutResult;
        Res.Set(_Searing.Get_PanLift() > 2.0f);
    }

    UFUNCTION()
    private void Check_TossedAirborne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Record_PeakLiftVelocity();
        const auto Tossed = _Contacts.Num() > _ContactsBeforeToss && _Contacts.Last() == EMars_Searing_Contact::Airborne;
        if (Tossed && _AirborneTime < 0.0f)
        { _AirborneTime = Get_Now(); }

        auto Res = OutResult;
        Res.Set(Tossed || _Lost.Num() > 0);
    }

    UFUNCTION()
    private void Check_LandedOrLost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasLanded() || _Lost.Num() == 1);
    }

    UFUNCTION()
    private void Step_RecordOutcome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Landed = Get_HasLanded();
        _EndAirSeconds = Get_Now() - _AirborneTime;
    }

    UFUNCTION()
    private void Step_AssertOutcome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_AirborneTime >= 0.0f, "the piece left the pan after the flick");

        const auto Tally = _Searing.Get_Tally();
        if (_Landed)
        {
            const auto DownFaceAfter = _Searing.Get_DownFace(Get_FirstId());
            ck::Trace(f"[Searing] toss outcome: LANDED after {_EndAirSeconds :.3} s airborne; peak lift velocity "
                + f"{_PeakLiftVelocity :.1} uu/s; down face {utils_searing::Get_FaceName(_DownFaceBefore)} -> {utils_searing::Get_FaceName(DownFaceAfter)} "
                + f"after the settle (flips {Tally.Flips})");
            Assert_True(_Searing.Get_PieceStatus(Get_FirstId()) == EMars_Searing_PieceStatus::Cooking, "the tossed piece is still cooking");
            Assert_Equals_Int(Tally.Losses, 0, "the landed piece was not lost while it settled");
            const auto ExpectedFlips = DownFaceAfter != _DownFaceBefore ? 1 : 0;
            Assert_Equals_Int(Tally.Flips, ExpectedFlips, "a landing counts a flip exactly when it settled the piece onto another face");
            return;
        }

        ck::Trace(f"[Searing] toss outcome: LOST {_EndAirSeconds :.3} s after leaving the pan; peak lift velocity "
            + f"{_PeakLiftVelocity :.1} uu/s; down face before {utils_searing::Get_FaceName(_DownFaceBefore)}");
        Assert_Equals_Int(Tally.Losses, 1, "the lost toss counted one loss");
        Assert_Equals_Int(_Searing.Get_Summary().Lost, 1, "the summary counts it lost");
    }

    // Landed or lost, the pan holds what it was given: no second piece ever appears.
    UFUNCTION()
    private void Step_AssertNoReplacement(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Added.Num(), 1, "OnPieceAdded fired once: nothing replaced the piece");
        Assert_Equals_Int(_Searing.Get_Summary().Admitted, 1, "one piece admitted");
    }

    UFUNCTION()
    private void Step_AssertLiftSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lift = _Searing.Get_PanLift();
        Assert_True(Math::Abs(Lift) <= 0.5f, f"the lift spring brought the pan back to rest (got {Lift})");
    }

    // Landed = an OnPan edge after the toss's Airborne edge.
    private bool Get_HasLanded()
    {
        if (_Contacts.Num() < _ContactsBeforeToss + 2)
        { return false; }

        return _Contacts.Last() == EMars_Searing_Contact::OnPan && _Lost.Num() == 0;
    }

    private void Record_PeakLiftVelocity()
    {
        const auto Velocity = _Searing.Get_Pan().Get_LiftVelocity();
        _PeakLiftVelocity = Math::Max(_PeakLiftVelocity, Velocity);
    }
}

class AMars_AutoTest_Searing_FastUpwardLookTossesTheSteak_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 12.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_FastUpwardLookTossesTheSteak;
}
