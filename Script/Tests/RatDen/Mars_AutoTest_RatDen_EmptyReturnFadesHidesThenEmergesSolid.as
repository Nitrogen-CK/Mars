// R22 (return fade reset) + R04's dither half. One resident watches a guarded pack; the cheese is taken away, so it returns
// empty. In DenEnter it crouches (DenCrouchSeconds) and then its one fade clock runs 1 -> 0 over ReturnFadeSeconds (0.25 s,
// rat clock; sampled every frame, it passes through (0, 1)); only at 0 is it hidden (DormantInDen) - and FadeAlpha is back
// to 1 in that same frame, while hidden. While it fades the den's proxy eyes stay off for its slot (no second pair); once
// it is hidden the den admits it (slot Dormant, proxy shows it) and the raid retires the entity. The cheese is then put
// back: the next emergence's rat is a new entity that starts solid (FadeAlpha 1, not hidden) from its first frame.
// F4-5 (Phase 5): the rat walks through the arch to the den's Inside stand before DenEnter, so at the first frame its
// FadeAlpha drops its root is inside the arch footprint (den-local x -47..9.5, |y| <= 30: the R02 den mesh's x extent and
// the 60 cm opening, PantryRat_R02_Manifest.json den.bounds_ue_cm).
class UMars_AutoTest_RatDen_EmptyReturnFadesHidesThenEmergesSolid : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 90.0f;

    private FCk_Handle_PantryRat _Rat;
    private FCk_Handle _RatEntity;
    private FCk_Handle_Inventory_DataOnly _Elsewhere;
    private float32 _FadeStartedAt = -1.0f;
    private TOptional<FVector> _FadeStartLocal;
    private float32 _HiddenAt = -1.0f;
    private int32 _MidFadeFrames = 0;
    private bool _EyesShownWhileFading = false;
    private bool _FadeAfterHidden = false;
    private bool _HiddenBeforeZero = false;
    private float32 _LastFade = 1.0f;
    private FCk_Handle _NextRat;
    private bool _NextStartedSolid = true;
    private int32 _NextFramesSeen = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(728000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));
        _Elsewhere = Make_OpenHolder(InHandle);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat is out and watching the guarded pack", n"Check_Watching", k_LongPolls, 0);
        Add_Step("take the cheese out of the pack", n"Step_RemoveCheese");
        Add_Step_WaitUntil("the rat faded, hid and was retired; its slot is Dormant", n"Check_Home", k_LongPolls, 0);
        Add_Step("the fade ran 0.25 s before the hide; reset while hidden; no doubled eyes", n"Step_AssertReturn");
        Add_Step("put the cheese back", n"Step_ReturnCheese");
        Add_Step_WaitUntil("the next resident emerges and is watched for a few frames", n"Check_NextOut", k_LongPolls, 0);
        Add_Step("the next rat started solid", n"Step_AssertNext");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished())
        { return; }

        // The next resident: every frame from its first constructed frame, solid and visible.
        if (_HiddenAt >= 0.0f && ck::IsValid(_Raid))
        {
            for (auto Rat : Get_Rats())
            {
                FCk_Handle RatEntity = Rat;
                if (RatEntity == _RatEntity)
                { continue; }

                _NextRat = RatEntity;
                ++_NextFramesSeen;
                _NextStartedSolid = _NextStartedSolid && Rat.Get_FadeAlpha() == 1.0f && Rat.Get_IsHidden() == false;
            }
        }

        if (ck::Is_NOT_Valid(_Rat) || ck::Is_NOT_Valid(_RatEntity)
            || utils_entity_lifetime::Get_IsPendingDestroy(_RatEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto Phase = _Rat.Get_Phase();
        const auto Fade = _Rat.Get_FadeAlpha();
        if (Phase == EMars_PantryRat_Phase::DenEnter && Fade < 1.0f)
        {
            if (_FadeStartedAt < 0.0f)
            {
                _FadeStartedAt = _Rat.Get_Clock();
                const auto DenFrame = utils_transform::Get_EntityCurrentTransform(_Den.As_Transform());
                _FadeStartLocal = DenFrame.InverseTransformPosition(_Rat.Get_Location());
            }

            if (Fade > 0.0f)
            { ++_MidFadeFrames; }

            _EyesShownWhileFading = _EyesShownWhileFading || _Den.Get_EyeSlot() == TOptional<int32>(0);
            _LastFade = Fade;
        }

        if (_Rat.Get_IsHidden())
        {
            if (_HiddenAt < 0.0f)
            {
                _HiddenAt = _Rat.Get_Clock();
                _HiddenBeforeZero = _FadeStartedAt < 0.0f;
            }

            _FadeAfterHidden = _FadeAfterHidden || Fade != 1.0f;
        }
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        if (ck::IsValid(Rat) && ck::Is_NOT_Valid(_Rat))
        {
            _Rat = Rat;
            _RatEntity = Rat;
        }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded);
    }

    UFUNCTION()
    private void Step_RemoveCheese(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Source = Get_Slot(1).Get_Inventory();
        Source.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_CheeseItem, _Elsewhere),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Home(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_HiddenAt >= 0.0f && _Raid.Get_RatCount() == 0 && _Den.Get_SlotState(0) == EMars_RatDen_SlotState::Dormant);
    }

    UFUNCTION()
    private void Step_AssertReturn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto FadeSeconds = _HiddenAt - _FadeStartedAt;
        Assert_False(_HiddenBeforeZero, "never hidden before the fade began");
        Assert_True(_FadeStartedAt >= 0.0f && FadeSeconds >= 0.25f - 0.05f && FadeSeconds < 0.25f + 0.2f,
            f"the return fade ran ~0.25 s on the rat's clock (took [{FadeSeconds}])");
        Assert_True(_MidFadeFrames > 0, "FadeAlpha passed through (0, 1)");
        Assert_True(_FadeStartLocal.IsSet(), "the fade start was observed");
        if (_FadeStartLocal.IsSet())
        {
            const auto Local = _FadeStartLocal.GetValue();
            Assert_True(Local.X >= -47.0 && Local.X <= 9.5 && Math::Abs(Local.Y) <= 30.0,
                f"the rat was inside the arch footprint when FadeAlpha started dropping (den-local [{Local.ToString()}])");
        }
        Assert_False(_FadeAfterHidden, "FadeAlpha was 1 again in every hidden frame");
        Assert_False(_EyesShownWhileFading, "the den's proxy eyes stayed off for the fading resident (no second pair)");
        Assert_Equals_Int(_Den.Get_RefusedReturns(), 0, "the den admitted it (empty pocket)");
        Assert_True(_Den.Get_EyeSlot() == TOptional<int32>(0), "the proxy shows the resident home again");
    }

    UFUNCTION()
    private void Step_ReturnCheese(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Move_Chef(0, _Origin + k_ChefAway);
        auto Slot = Get_Slot(1);
        Slot.Request_Stow(FMars_Request_CargoSlot_Stow(_CheeseItem));
    }

    UFUNCTION()
    private void Check_NextOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_NextRat) && _NextFramesSeen >= 10);
    }

    UFUNCTION()
    private void Step_AssertNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_NextRat != _RatEntity, "the next emergence is a new entity");
        Assert_True(_NextStartedSolid, "it was solid and visible in every frame it was watched");
    }
}
