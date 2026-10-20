// A Cancel close never chooses, even with the pointer over an entry: the wheel closes (OnClosed once) and OnEmoteChosen
// does not fire. The positive proof first: an entry was hovered before the cancel.
class UMars_AutoTest_EmoteWheel_CancelOverAnEntryChoosesNothing : UCk_AutoTest_Base
{
    private FCk_Handle_EmoteWheel _Wheel;
    private float32 _Travel = 1.0f;
    private int32 _ClosedCount = 0;
    private int32 _ChosenCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        const auto Spec = mars::Mars_PlayerCharacter_Config.EmoteWheel;
        _Travel = Spec.PointerTravel;
        _Wheel = utils_emote_wheel::Add(LocalHandle, Spec);
        if (ck::Is_NOT_Valid(_Wheel) || _Wheel.Get_EntryCount() < 1)
        {
            FinishFailure("the configured wheel needs an entry for this test");
            return;
        }

        _Wheel.BindTo_OnClosed(FMars_Delegate_EmoteWheel_OnClosed(this, n"OnClosed"));
        _Wheel.BindTo_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));

        Add_Step("open", n"Step_Open");
        Add_Step_WaitUntil("the wheel is open", n"Check_Open");
        Add_Step("move the pointer up to the rim", n"Step_MoveUp");
        Add_Step_WaitUntil("an entry is hovered", n"Check_Hovered");
        Add_Step("cancel", n"Step_Cancel");
        Add_Step_WaitUntil("the wheel closed", n"Check_Closed");
        Add_Step("nothing was chosen", n"Step_AssertNothingChosen");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnClosed(FCk_Handle_EmoteWheel InWheel)
    {
        _ClosedCount += 1;
    }

    UFUNCTION()
    private void OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote)
    {
        _ChosenCount += 1;
    }

    UFUNCTION()
    private void Step_Open(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_Open(FMars_Request_EmoteWheel_Open());
    }

    UFUNCTION()
    private void Check_Open(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Wheel.Get_IsOpen());
    }

    UFUNCTION()
    private void Step_MoveUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_MovePointer(FMars_Request_EmoteWheel_MovePointer(FVector2D(0.0, -_Travel)));
    }

    UFUNCTION()
    private void Check_Hovered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Wheel.Get_HoveredIndex().IsSet());
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_Close(FMars_Request_EmoteWheel_Close(EMars_EmoteWheel_CloseAction::Cancel));
    }

    UFUNCTION()
    private void Check_Closed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Wheel.Get_IsOpen() == false && _Wheel.Has_Fragment(FMars_Fragment_EmoteWheel_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertNothingChosen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ClosedCount, 1, "the cancel closed the wheel once");
        Assert_Equals_Int(_ChosenCount, 0, "a cancel over an entry chose nothing");
        Assert_False(_Wheel.Get_HoveredIndex().IsSet(), "the close cleared the hover");
    }
}
