class UMars_AutoTest_AttackCatalog_ValidationRejectsWholeGraph : UMars_AutoTestRig_AttackCatalogPure
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("A01 definitions reject enums, bounds, missing windows and unsafe intervening body keys", n"Step_Definitions");
        Add_Step("A01 validate every enabled graph including a malformed lower-priority fallback", n"Step_Loadouts");
        Add_Step("A01 resolved bindings reject missing and duplicate anatomy and claimed slots", n"Step_Resolved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Definitions(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Clip = Make_BodyClip();
        const auto Valid = Make_Definition(Clip);
        Assert_True(utils_attack::Validate_Definition(Valid).Get_IsValid(), "the unchanged linear body reference contract validates");
        auto Broken = Valid;
        Broken.Prepare.MaxDistance = float32(Math::Sqrt(-1.0));
        Broken.Cooldown.ReuseSeconds = -1.0f;
        Broken.Hit.Emitters[0].Radius = -1.0f;
        Broken.Hit.Emitters[0].DamageWindow = n"Absent";
        Broken.Hit.Emitters[0].Source = EMars_Attack_EmitterSource(99);
        const auto Report = utils_attack::Validate_Definition(Broken);
        Assert_True(Has_Diagnostic(Report, n"PositiveFinite", "Prepare.MaxDistance"), "nonfinite distance has an exact structured field diagnostic");
        Assert_True(Has_Diagnostic(Report, n"NonnegativeFinite", "Cooldown.ReuseSeconds"), "negative reuse duration is rejected");
        Assert_True(Has_Diagnostic(Report, n"PositiveFinite", "Hit.Emitters[0].Radius"), "negative sphere radius is rejected");
        Assert_True(Has_Diagnostic(Report, n"DamageWindowMissing", "Hit.Emitters[0].DamageWindow"), "missing damage window is rejected");
        Assert_True(Has_Diagnostic(Report, n"EmitterSourceEnum", "Hit.Emitters[0].Source"), "invalid emitter enum is rejected");
        Broken = Valid;
        Broken.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>();
        Assert_True(Has_Diagnostic(utils_attack::Validate_Definition(Broken), n"ClipMissing", "Clip"), "missing clip is rejected before execution");
        Broken = Valid;
        auto Slot = FMars_Attack_SlotRole();
        Slot.Slot = n"Tip";
        Slot.Role = GameplayTags::AttackRole_Mars_Test_Jaw;
        Slot.MaxCondition = EMars_BodyPart_Condition(99);
        Broken.Requirements.Slots.Add(Slot);
        Broken.Requirements.Slots.Add(Slot);
        const auto Duplicate = utils_attack::Validate_Definition(Broken);
        Assert_True(Has_Diagnostic(Duplicate, n"DuplicateSlot", "Requirements.Slots[1].Slot") &&
            Has_Diagnostic(Duplicate, n"DuplicateRole", "Requirements.Slots[1].Role") &&
            Has_Diagnostic(Duplicate, n"ConditionEnum", "Requirements.Slots[0].MaxCondition"), "slots, roles and condition ceilings are all checked");
        auto Draft = FCk_ProceduralAction_ClipDraft();
        utils_procedural_action_builder::Make_Draft_FromData(Clip, Draft);
        auto Phases = Draft.Get_Phases();
        auto Keys = Phases[0].Get_BodyKeys();
        Keys.Insert(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(0.5), FVector(-5.0, 0.0, 0.0), FRotator(0.0, 15.0, 0.0).Quaternion()), 1);
        Phases[0].Set_BodyKeys(Keys);
        Draft.Set_Phases(Phases);
        auto UnsafeClip = Build_Clip(Draft);
        Assert_True(Has_Diagnostic(utils_attack::Validate_Definition(Make_Definition(UnsafeClip)), n"BodyKeyEnvelope", "Clip.Phases[0].BodyKeys[1]"),
            "an unsafe intervening body key is rejected despite a valid unchanged final key");
        Phases = Draft.Get_Phases();
        Phases[0].Set_BodyInterpolation(ECk_ProceduralAction_Interpolation::Smooth);
        Draft.Set_Phases(Phases);
        auto SmoothClip = Build_Clip(Draft);
        Assert_True(Has_Diagnostic(utils_attack::Validate_Definition(Make_Definition(SmoothClip)), n"UnsupportedBodyCurve", "Clip.Phases[0].BodyInterpolation"),
            "unsupported body interpolation is explicit and distinct from phase easing");
    }

    UFUNCTION()
    private void Step_Loadouts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Good = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        Good.Def = Make_Definition(Make_BodyClip());
        auto Bad = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        Bad.Def = Good.Def;
        Bad.Def.Hit.Emitters[0].Radius = -1.0f;
        _Definitions.Add(Good);
        _Definitions.Add(Bad);
        auto Loadout = FMars_Attack_Loadout();
        auto First = FMars_Attack_Entry();
        First.Id = GameplayTags::Attack_Mars_Test_Preferred;
        First.Priority = 100;
        First.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Good);
        Loadout.Entries.Add(First);
        auto Fallback = FMars_Attack_Entry();
        Fallback.Id = GameplayTags::Attack_Mars_Test_Fallback;
        Fallback.Priority = -100;
        Fallback.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(Bad);
        Loadout.Entries.Add(Fallback);
        const auto Report = utils_attack::Validate_Loadout(Loadout);
        Assert_True(Has_Diagnostic(Report, n"PositiveFinite", "Entries[1].Definition.Hit.Emitters[0].Radius"),
            "a lower-priority enabled malformed graph rejects the whole loadout with an entry-prefixed diagnostic");
        Assert_True(Loadout.Entries.Num() == 2 && Bad.Def.Hit.Emitters[0].Radius == -1.0f && Good.Def.Hit.Emitters[0].Radius == 20.0f,
            "pure validation leaves all input data untouched");
        Loadout.Entries[1].Enabled = false;
        Loadout.Entries[1].Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>();
        Assert_True(utils_attack::Validate_Loadout(Loadout).Get_IsValid(), "disabled definitions need not load or validate");
        // A tag resolves ignoring case to the same registered tag, so a differently cased name is the same attack.
        Loadout.Entries[1].Id = GameplayTags::ResolveGameplayTag(n"attack.mars.test.preferred");
        Assert_True(Has_Diagnostic(utils_attack::Validate_Loadout(Loadout), n"DuplicateAttackId", "Entries[1].Id"),
            "disabled IDs remain unique ignoring case");
        Loadout.Selection.ControlWait = EMars_Attack_ControlWaitPolicy(99);
        Assert_True(Has_Diagnostic(utils_attack::Validate_Loadout(Loadout), n"ControlWaitPolicyEnum", "Selection.ControlWait"), "policy enums are checked");
    }

    UFUNCTION()
    private void Step_Resolved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Loadout = FMars_Attack_ResolvedLoadout();
        Loadout.GameRevision = 1;
        const auto Body = Make_Binding(GameplayTags::AttackRole_Mars_Body, NAME_None);
        Loadout.Anatomy.Add(Body);
        auto Entry = FMars_Attack_ResolvedEntry();
        Entry.Identity.Id = GameplayTags::Attack_Mars_Test_BodyAttack;
        Entry.Identity.GameRevision = 1;
        Entry.Definition = Make_Definition(Make_BodyClip());
        auto Part = FMars_Attack_ResolvedPart();
        Part.Binding = Body;
        Entry.Parts.Add(Part);
        Loadout.Entries.Add(Entry);
        Assert_True(utils_attack::Validate_ResolvedLoadout(Loadout).Get_IsValid(), "a valid resolved body graph validates");
        Loadout.Anatomy.Add(Body);
        Assert_True(Has_Diagnostic(utils_attack::Validate_ResolvedLoadout(Loadout), n"DuplicateRole", "Anatomy[1].Role"), "duplicate resolved role is rejected");
        Loadout.Anatomy.RemoveAt(1);
        Loadout.Entries[0].Parts[0].Binding.Role = GameplayTags::AttackRole_Mars_Test_Absent;
        Assert_True(Has_Diagnostic(utils_attack::Validate_ResolvedLoadout(Loadout), n"RoleUnbound", "Entries[0].Parts[0].Binding"), "missing anatomy prerequisite rejects");
        Loadout.Entries[0].Parts[0] = Part;
        auto SecondBinding = Make_Binding(GameplayTags::AttackRole_Mars_Test_SecondBody, NAME_None);
        Loadout.Anatomy.Add(SecondBinding);
        auto SecondAuthored = FMars_Attack_PartRequirement();
        SecondAuthored.Role = GameplayTags::AttackRole_Mars_Test_SecondBody;
        Loadout.Entries[0].Definition.Requirements.Parts.Add(SecondAuthored);
        Loadout.Entries[0].Parts.Add(Part);
        const auto Missing = utils_attack::Validate_ResolvedLoadout(Loadout);
        Assert_True(Has_Diagnostic(Missing, n"DuplicateResolvedPart", "Entries[0].Parts[1].Binding.Role") &&
            Has_Diagnostic(Missing, n"ResolvedPartMissing", "Entries[0].Parts"),
            "equal-count [A,A] resolution cannot hide authored prerequisite B");
        Loadout.Entries[0].Definition.Requirements.Parts.RemoveAt(1);
        Loadout.Entries[0].Parts.RemoveAt(1);
        Loadout.Anatomy.RemoveAt(1);
        auto Slot = FMars_Attack_ResolvedSlot();
        Slot.Slot = n"Tip";
        Slot.Binding = Make_Binding(GameplayTags::AttackRole_Mars_Test_Jaw, n"Jaw0");
        Loadout.Anatomy.Add(Slot.Binding);
        Loadout.Entries[0].Slots.Add(Slot);
        Loadout.Entries[0].Slots.Add(Slot);
        const auto Dup = utils_attack::Validate_ResolvedLoadout(Loadout);
        Assert_True(Has_Diagnostic(Dup, n"DuplicateClaimedLimb", "Entries[0].Slots[1].Binding.LimbId") &&
            Has_Diagnostic(Dup, n"DuplicateSlot", "Entries[0].Slots[1].Slot"), "two slots cannot acquire the same limb or repeat a slot");
    }
}
