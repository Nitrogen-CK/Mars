// R24 (per-rat material isolation) + R21 (corpse dither, CPD half). Two rats assembled with their real skeletal bodies
// (built headless). One is killed by the chef's real strike (corpse hold shortened to 0.5 s for this test); its corpse fades.
// Every frame of that fade: the fading rat's body primitive slot 14 equals its kernel FadeAlpha (one fade clock, copied
// each frame it changes) and passes through (0, 1); its slots 0..13 (the Eyes' cells, anim, look, colour) are exactly what
// they were when the fade began (the fade write touches only slot 14); the other rat's slot 14 stays 1. The spoon and the
// harness are material slots of the same body primitive (Wood, Harness), so the one write fades them with the body. The
// faded corpse is destroyed once; the other rat lives on, solid.
class UMars_AutoTest_PantryRat_CorpseFadeIsIsolatedPerRat : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle _FadingEntity;
    private FCk_Handle _SolidEntity;
    private UMars_PantryRat_EntityScript _Fading;
    private UMars_PantryRat_EntityScript _Solid;
    private TArray<float32> _EyeSlotsAtFadeStart;
    private bool _Snapshotted = false;
    private int32 _MidFadeFrames = 0;
    private int32 _SlotMismatches = 0;
    private int32 _EyeSlotDrifts = 0;
    private int32 _SolidDips = 0;
    private FString _FirstProblem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(724000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Scent.NoTargetReturnSeconds = 600.0f;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        Make_ChefDealer(0, 1.0f);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step("spawn two rats with their real bodies", n"Step_Spawn");
        Add_Step_WaitUntil("both bodies are built and solid", n"Check_Built", k_LongPolls, 0);
        Add_Step("one body primitive carries the spoon and harness slots; strike one rat", n"Step_Strike");
        Add_Step_WaitUntil("the struck corpse is gone", n"Check_FadingGone", k_LongPolls, 0);
        Add_Step("one rat faded alone; slots 0..13 untouched; the other solid", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FadingEntity = Spawn_LookRat(InHandle, _Origin + FVector(0.0, -300.0, 0.0), 911, 0.5f);
        _SolidEntity = Spawn_LookRat(InHandle, _Origin + FVector(0.0, 300.0, 0.0), 912, 0.5f);
    }

    UFUNCTION()
    private void Check_Built(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Fading = Get_RatScript(_FadingEntity);
        _Solid = Get_RatScript(_SolidEntity);
        const auto Fade = utils_pantry_rat_look::Get_FadeAlphaCpdIndex();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Fading) && ck::IsValid(_Solid) && ck::IsValid(_Fading.Get_Body()) && ck::IsValid(_Solid.Get_Body())
            && Get_BodyCpd(_Fading, Fade) == 1.0f && Get_BodyCpd(_Solid, Fade) == 1.0f
            && Get_BodyCpd(_Fading, constants_eyes::k_Slot_Cells) > 0.0f);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Body = _Fading.Get_Body();
        Assert_True(Body.GetMaterialIndex(n"Wood") != ck::INDEX_NONE() && Body.GetMaterialIndex(n"Harness") != ck::INDEX_NONE()
            && Body.GetMaterialIndex(n"Body") != ck::INDEX_NONE(), "the spoon (Wood) and harness are slots of the one body primitive");
        Assert_True(Strike_RatAsTheChef(_Fading.Get_Rat(), 0, FVector(1.0, 0.0, 0.0)), "the real strike's sweep hit the rat");
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Fading) || ck::Is_NOT_Valid(_Solid) || ck::Is_NOT_Valid(_FadingEntity))
        { return; }

        const auto FadeSlot = utils_pantry_rat_look::Get_FadeAlphaCpdIndex();
        if (ck::IsValid(_Solid.Get_BodyPart()) && Get_BodyCpd(_Solid, FadeSlot) != 1.0f)
        {
            ++_SolidDips;
            Note(f"the solid rat's slot 14 read [{Get_BodyCpd(_Solid, FadeSlot)}]");
        }

        if (utils_entity_lifetime::Get_IsPendingDestroy(_FadingEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto Rat = _Fading.Get_Rat();
        if (ck::Is_NOT_Valid(Rat) || Rat.Get_Phase() != EMars_PantryRat_Phase::CorpseFade || ck::Is_NOT_Valid(_Fading.Get_BodyPart()))
        { return; }

        if (_Snapshotted == false)
        {
            _Snapshotted = true;
            for (int32 Index = 0; Index < FadeSlot; ++Index)
            { _EyeSlotsAtFadeStart.Add(Get_BodyCpd(_Fading, Index)); }
            return;
        }

        const auto Written = Get_BodyCpd(_Fading, FadeSlot);
        if (Written > 0.0f && Written < 1.0f)
        { ++_MidFadeFrames; }

        // The presentation writes the kernel's value in the frame it changes; allow one frame of lag.
        if (Math::Abs(Written - Rat.Get_FadeAlpha()) > 0.35f)
        {
            ++_SlotMismatches;
            Note(f"slot 14 [{Written}] vs FadeAlpha [{Rat.Get_FadeAlpha()}]");
        }

        for (int32 Index = 0; Index < FadeSlot; ++Index)
        {
            if (Get_BodyCpd(_Fading, Index) != _EyeSlotsAtFadeStart[Index])
            {
                ++_EyeSlotDrifts;
                Note(f"slot {Index} moved from [{_EyeSlotsAtFadeStart[Index]}] to [{Get_BodyCpd(_Fading, Index)}] during the fade");
            }
        }
    }

    private void Note(FString InWhat)
    {
        if (_FirstProblem.IsEmpty())
        { _FirstProblem = InWhat; }
    }

    UFUNCTION()
    private void Check_FadingGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_FadingEntity)
            || utils_entity_lifetime::Get_IsPendingDestroy(_FadingEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Snapshotted, "the fade was observed from its first frame");
        Assert_True(_MidFadeFrames > 0, "the fading body's slot 14 passed through (0, 1)");
        Assert_Equals_Int(_SlotMismatches, 0, f"slot 14 tracked the kernel's FadeAlpha ({_FirstProblem})");
        Assert_Equals_Int(_EyeSlotDrifts, 0, f"slots 0..13 untouched by the fade ({_FirstProblem})");
        Assert_Equals_Int(_SolidDips, 0, f"the other rat stayed solid ({_FirstProblem})");
        const auto Solid = _Solid.Get_Rat();
        Assert_True(ck::IsValid(Solid) && Solid.Get_IsDead() == false && Solid.Get_FadeAlpha() == 1.0f, "the other rat lives, solid");
        Assert_True(Get_BodyCpd(_Solid, utils_pantry_rat_look::Get_FadeAlphaCpdIndex()) == 1.0f, "its slot 14 still reads 1");
    }
}
