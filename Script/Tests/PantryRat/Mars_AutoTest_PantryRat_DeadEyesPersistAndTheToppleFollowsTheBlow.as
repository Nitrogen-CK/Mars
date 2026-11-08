// R20 (X eyes persist) + the topple side. A rat assembled with its real skeletal body (built headless: the Phase 2 mesh,
// the EyePatch slot as the Eyes plate) plays a timed emote (Dizzy-style, 1.0 s, blinking) and is then killed by the chef's
// real strike pushing toward the rat's right. The assembly clears the emote and sets the persistent Downed state: both eyes
// resolve to cell 20, no blink, no look, and the body primitive's custom primitive data holds 20 / 20 in the cell slots
// (read back from the component, constants_eyes::k_Slot_Cells) and FadeAlpha 1 in slot 14 - still so after the timed
// emote's duration has long run out. The corpse topples to its right (DeathToppleRight, both sides clear), then DeadHold.
// The body primitive is then recreated (Rebuild_Body): the new component is re-seeded - CPD 14 = 1 and the Eyes' every
// group, so cells 20 / 20 again - without the face resetting to alive. The pure side rule is checked on its four cases.
class UMars_AutoTest_PantryRat_DeadEyesPersistAndTheToppleFollowsTheBlow : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle _RatEntity;
    private FCk_Handle_PantryRat _Rat;
    private UMars_PantryRat_EntityScript _Script;
    private FCk_Handle_UnrealComponent _FirstBody;

    private const int32 k_LeftCellSlot = constants_eyes::k_Slot_Cells;
    private const int32 k_RightCellSlot = constants_eyes::k_Slot_Cells + 1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(720000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Scent.NoTargetReturnSeconds = 600.0f;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        Make_ChefDealer(0, 1.0f);

        Add_CourtSteps();
        Add_Step("spawn a rat with its real body", n"Step_Spawn");
        Add_Step_WaitUntil("its body and eyes are built and drawing", n"Check_Built", k_LongPolls, 0);
        Add_Step("a timed emote, then the real strike toward its right", n"Step_EmoteThenStrike");
        Add_Step_WaitUntil("the corpse shows Downed and chose its topple", n"Check_Downed", k_SlowPolls, 0);
        Add_Step_WaitSeconds("past the timed emote's duration", 1.5f);
        Add_Step("X eyes held, no blink, no look, slot 14 solid, toppled right", n"Step_AssertDead");
        Add_Step("recreate the body primitive", n"Step_Rebuild");
        Add_Step_WaitUntil("the new primitive is re-seeded", n"Check_Reseeded", k_SlowPolls, 0);
        Add_Step("the recreated face is still dead; the side rule's four cases", n"Step_AssertRebuilt");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RatEntity = Spawn_LookRat(InHandle, _Origin + FVector(0.0, -300.0, 0.0), 901, 60.0f);
    }

    UFUNCTION()
    private void Check_Built(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Script = Get_RatScript(_RatEntity);
        auto Ready = ck::IsValid(_Script) && ck::IsValid(_Script.Get_Body()) && ck::IsValid(_Script.Get_Eyes())
            && _Script.Get_Eyes().Get_HasPresentation();
        if (Ready)
        {
            _Rat = _Script.Get_Rat();
            _FirstBody = _Script.Get_BodyPart();
            // The Wide style's cells (19 / 19) are on the plate: the eyes draw on the body primitive.
            Ready = Get_BodyCpd(_Script, k_LeftCellSlot) == float32(utils_eyes::Style_Wide().Def.LeftCell)
                && Get_BodyCpd(_Script, utils_pantry_rat_look::Get_FadeAlphaCpdIndex()) == 1.0f;
        }

        auto Result = OutResult;
        Result.Set(Ready);
    }

    UFUNCTION()
    private void Step_EmoteThenStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Emote = FMars_Eyes_ExpressionDef();
        Emote.LeftCell = 9;
        Emote.RightCell = 9;
        Emote.AllowBlink = true;
        Emote.AllowLook = true;
        Emote.DurationSeconds = 1.0f;
        auto Eyes = _Script.Get_Eyes();
        Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Emote));

        const auto Right = utils_transform::Get_EntityCurrentRotation(_Rat.As_Transform()).GetRightVector();
        Assert_True(Strike_RatAsTheChef(_Rat, 0, Right), "the real strike's sweep hit the rat");
    }

    UFUNCTION()
    private void Check_Downed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Eyes = _Script.Get_Eyes();
        auto Result = OutResult;
        Result.Set(_Rat.Get_IsDead() && _Script.Get_ToppleSide().IsSet() && Eyes.Get_HasEmote() == false
            && Eyes.Get_ResolvedLeftCell() == 20 && Eyes.Get_ResolvedRightCell() == 20);
    }

    UFUNCTION()
    private void Step_AssertDead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Eyes = _Script.Get_Eyes();
        Assert_Equals_Int(Eyes.Get_ResolvedLeftCell(), 20, "left eye X (cell 20)");
        Assert_Equals_Int(Eyes.Get_ResolvedRightCell(), 20, "right eye X (cell 20)");
        Assert_False(Eyes.Get_HasEmote(), "no emote over the dead face");
        Assert_True(Eyes.Get_Blink() == 0.0f, f"no blink (closure [{Eyes.Get_Blink()}])");
        Assert_True(Eyes.Get_LookOffset().IsNearlyZero(0.001), f"no look (offset [{Eyes.Get_LookOffset().ToString()}])");
        Assert_True(Get_BodyCpd(_Script, k_LeftCellSlot) == 20.0f && Get_BodyCpd(_Script, k_RightCellSlot) == 20.0f,
            f"the body primitive holds cells 20 / 20 (got [{Get_BodyCpd(_Script, k_LeftCellSlot)}] / [{Get_BodyCpd(_Script, k_RightCellSlot)}])");
        Assert_True(Get_BodyCpd(_Script, utils_pantry_rat_look::Get_FadeAlphaCpdIndex()) == 1.0f, "slot 14 still solid (the hold)");
        Assert_True(_Script.Get_ToppleSide().GetValue() == EMars_PantryRat_ToppleSide::Right, "toppled toward the blow (right)");
        Assert_True(_Script.Get_PlayingClip() == n"DeadHold", f"the topple finished into DeadHold (playing [{_Script.Get_PlayingClip()}])");
        Assert_True(_Rat.Get_Phase() == EMars_PantryRat_Phase::DeadHold, "the kernel holds the corpse");
    }

    UFUNCTION()
    private void Step_Rebuild(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Script.Rebuild_Body();
    }

    UFUNCTION()
    private void Check_Reseeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Script.Get_BodiesBuilt() == 2 && ck::IsValid(_Script.Get_Body()) && _Script.Get_BodyPart() != _FirstBody
            && Get_BodyCpd(_Script, k_LeftCellSlot) == 20.0f && Get_BodyCpd(_Script, k_RightCellSlot) == 20.0f
            && Get_BodyCpd(_Script, utils_pantry_rat_look::Get_FadeAlphaCpdIndex()) == 1.0f);
    }

    UFUNCTION()
    private void Step_AssertRebuilt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Script.Get_Eyes().Get_ResolvedLeftCell(), 20, "the recreated face is still X");
        Assert_True(_Script.Get_PlayingClip() == n"DeadHold", "the recreated body plays DeadHold, not an alive clip");

        const auto Right = FVector(0.0, 1.0, 0.0);
        Assert_True(utils_pantry_rat::Get_ToppleSide(Right, Right * 300.0, true, true) == EMars_PantryRat_ToppleSide::Right, "pushed right, clear -> right");
        Assert_True(utils_pantry_rat::Get_ToppleSide(Right, Right * -300.0, true, true) == EMars_PantryRat_ToppleSide::Left, "pushed left, clear -> left");
        Assert_True(utils_pantry_rat::Get_ToppleSide(Right, Right * 300.0, true, false) == EMars_PantryRat_ToppleSide::Left, "pushed right, right blocked -> left");
        Assert_True(utils_pantry_rat::Get_ToppleSide(Right, Right * -300.0, false, true) == EMars_PantryRat_ToppleSide::Right, "pushed left, left blocked -> right");
        Assert_True(utils_pantry_rat::Get_ToppleSide(Right, Right * 300.0, false, false) == EMars_PantryRat_ToppleSide::Right, "both blocked keeps the pushed side");
    }
}
