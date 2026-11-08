// R02 (den eyes and model handoff). The real court: the den's eye proxy shows while both residents hide (slot 0), moves to
// the still-hidden slot 1 the moment slot 0's rat is granted its emergence, and goes black (vacant) once both are out. Every
// frame the proxy never stands for a slot whose rat is Pending or Outside, so one resident's proxy pair and its real head
// eyes never both show; the plate is a single pair, so no slot ever has two proxies.
class UMars_AutoTest_RatDen_EyesHandOffToTheEmergingRat : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private bool _SawSlotZero = false;
    private bool _SawSlotOneWhileZeroOut = false;
    private bool _SawVacantWithBothOut = false;
    private int32 _Violations = 0;
    private FString _FirstViolation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(632000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.EmergeSpacingSeconds = 1.0f;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("both residents are out", n"Check_BothOut", k_LongPolls, 0);
        Add_Step_WaitSeconds("watch the plate a further second", 1.0f);
        Add_Step("the proxy handed off slot by slot and never doubled a rat", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Den))
        { return; }

        const auto EyeSlot = _Den.Get_EyeSlot();
        if (EyeSlot.IsSet())
        {
            const auto Slot = EyeSlot.GetValue();
            if (_Den.Get_SlotState(Slot) != EMars_RatDen_SlotState::Dormant)
            {
                ++_Violations;
                if (_FirstViolation.IsEmpty())
                { _FirstViolation = f"the proxy stood for slot {Slot} in state [{_Den.Get_SlotState(Slot) :n}]"; }
            }

            _SawSlotZero = _SawSlotZero || (Slot == 0 && _Den.Get_SlotState(0) == EMars_RatDen_SlotState::Dormant);
            _SawSlotOneWhileZeroOut = _SawSlotOneWhileZeroOut || (Slot == 1 && _Den.Get_SlotState(0) != EMars_RatDen_SlotState::Dormant);
        }
        else
        {
            _SawVacantWithBothOut = _SawVacantWithBothOut || _Den.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant) == 0;
        }
    }

    UFUNCTION()
    private void Check_BothOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Den) && _Den.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant) == 0 && Get_Rats().Num() == 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawSlotZero, "the proxy showed slot 0 while both residents hid");
        Assert_True(_SawSlotOneWhileZeroOut, "the proxy moved to slot 1 once slot 0 emerged");
        Assert_True(_SawVacantWithBothOut, "the plate went vacant once both were out");
        Assert_Equals_Int(_Violations, 0, f"the proxy never stood for an emerging or outside rat ({_FirstViolation})");
        Assert_False(_Den.Get_EyesShown(), "vacant now");
    }
}
