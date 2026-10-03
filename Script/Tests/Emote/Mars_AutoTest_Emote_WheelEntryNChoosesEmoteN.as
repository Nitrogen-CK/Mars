// The configured wheel offers every emote in canonical order: confirming a close over sector N chooses entry N, whose
// Mars.Emote.* tag maps to EMars_FPEmote N - the emote UMars_SmTask_EmoteWheelIntent plays. (The task
// and the character are not available headless; this covers the wheel side and the tag mapping the task uses.)
class UMars_AutoTest_Emote_WheelEntryNChoosesEmoteN : UCk_AutoTest_Base
{
    private FCk_Handle_EmoteWheel _Wheel;
    private float32 _Travel = 1.0f;
    private int32 _Count = 0;
    private int32 _NextIndex = 0;
    private TArray<int32> _ChosenIndices;
    private TArray<FGameplayTag> _ChosenEmotes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        const auto Spec = mars::Mars_PlayerCharacter_Config.EmoteWheel;
        _Travel = Spec.PointerTravel;
        _Wheel = utils_emote_wheel::Add(LocalHandle, Spec);
        _Count = utils_fphands::Get_EmoteCount();
        if (ck::Is_NOT_Valid(_Wheel) || _Wheel.Get_EntryCount() != _Count)
        {
            FinishFailure(f"the configured wheel must offer one entry per emote ({_Count})");
            return;
        }

        _Wheel.BindTo_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));

        for (int32 Index = 0; Index < _Count; ++Index)
        {
            Add_Step(f"open, point at sector {Index}, confirm", n"Step_ChooseNext");
            Add_Step_WaitUntil(f"entry {Index} chosen", n"Check_Chosen");
        }
        Add_Step("each choice maps to its emote", n"Step_CheckEmotes");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote)
    {
        _ChosenIndices.Add(InIndex);
        _ChosenEmotes.Add(InEmote);
    }

    // Open, MovePointer and Close drain in that order in one pass, so one step makes one choice.
    UFUNCTION()
    private void Step_ChooseNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Point = utils_emote_wheel::Get_SectorPoint(_NextIndex, _Count, 1.0f);
        _NextIndex += 1;

        _Wheel.Request_Open();
        _Wheel.Request_MovePointer(FMars_Request_EmoteWheel_MovePointer(Point * _Travel));
        _Wheel.Request_Close(FMars_Request_EmoteWheel_Close(EMars_EmoteWheel_CloseAction::Choose));
    }

    UFUNCTION()
    private void Check_Chosen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChosenIndices.Num() == _NextIndex && _Wheel.Get_IsOpen() == false);
    }

    UFUNCTION()
    private void Step_CheckEmotes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChosenIndices.Num(), _Count, "one choice per entry");

        for (int32 Index = 0; Index < _ChosenIndices.Num(); ++Index)
        {
            Assert_Equals_Int(_ChosenIndices[Index], Index, f"pointing at sector {Index} chose entry {Index}");

            auto Emote = EMars_FPEmote::Wave;
            const auto Found = utils_fphands::TryGet_Emote(_ChosenEmotes[Index], Emote);
            Assert_True(Found && Emote == EMars_FPEmote(Index),
                f"entry {Index} ({_ChosenEmotes[Index].ToString()}) asks for emote {Index}");
        }
    }
}
