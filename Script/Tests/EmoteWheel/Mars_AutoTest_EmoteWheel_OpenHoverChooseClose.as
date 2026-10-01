// Opening resets the pointer to the centre; pointer moves hover sectors (clamped to the rim, so pushing on slides around
// the wheel); a confirming close over an entry broadcasts OnEmoteChosen with its emote before OnClosed; a confirming
// close from the centre chooses nothing; pointer moves while closed are ignored.
class UMars_AutoTest_EmoteWheel_OpenHoverChooseClose : UCk_AutoTest_Base
{
    private FCk_Handle_EmoteWheel _Wheel;
    private float32 _Travel = 1.0f;
    private int32 _OpenedCount = 0;
    private int32 _ClosedCount = 0;
    private int32 _HoverChangeCount = 0;
    private int32 _ChosenCount = 0;
    private int32 _ChosenIndex = -1;
    private FGameplayTag _ChosenEmote;
    // OnEmoteChosen must precede OnClosed.
    private int32 _ClosedCountWhenChosen = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        const auto Spec = mars::Mars_PlayerCharacter_Config.EmoteWheel;
        _Travel = Spec.PointerTravel;
        _Wheel = utils_emote_wheel::Add(LocalHandle, Spec);
        if (ck::Is_NOT_Valid(_Wheel) || _Wheel.Get_EntryCount() < 4)
        {
            FinishFailure("the configured wheel needs at least 4 entries for this test");
            return;
        }

        _Wheel.BindTo_OnOpened(FMars_Delegate_EmoteWheel_OnOpened(this, n"OnOpened"));
        _Wheel.BindTo_OnClosed(FMars_Delegate_EmoteWheel_OnClosed(this, n"OnClosed"));
        _Wheel.BindTo_OnHoveredChanged(FMars_Delegate_EmoteWheel_OnHoveredChanged(this, n"OnHoveredChanged"));
        _Wheel.BindTo_OnEmoteChosen(FMars_Delegate_EmoteWheel_OnEmoteChosen(this, n"OnEmoteChosen"));

        Add_Step("move the pointer while closed", n"Step_MoveUp");
        // Otherwise the move could share a drain with the open, which applies first.
        Add_Step_WaitUntil("the closed move drained", n"Check_RequestsDrained");
        Add_Step("open", n"Step_Open");
        Add_Step_WaitUntil("open, centred, nothing hovered, the early move ignored", n"Check_OpenCentred");
        Add_Step("move the pointer up to the rim", n"Step_MoveUp");
        Add_Step_WaitUntil("sector 0 hovered", n"Check_HoveredZero");
        Add_Step("push right past the rim", n"Step_PushRight");
        Add_Step_WaitUntil("the pointer slid around the rim to the right-hand sector", n"Check_HoveredRight");
        Add_Step("release (confirm)", n"Step_Confirm");
        Add_Step_WaitUntil("that entry was chosen, then the wheel closed", n"Check_ChosenThenClosed");
        Add_Step("open again", n"Step_Open");
        Add_Step_WaitUntil("open again", n"Check_OpenAgain");
        Add_Step("release from the centre (confirm)", n"Step_Confirm");
        Add_Step_WaitUntil("closed without a choice", n"Check_ClosedWithoutChoice");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnOpened(FCk_Handle_EmoteWheel InWheel)
    {
        _OpenedCount += 1;
    }

    UFUNCTION()
    private void OnClosed(FCk_Handle_EmoteWheel InWheel)
    {
        _ClosedCount += 1;
    }

    UFUNCTION()
    private void OnHoveredChanged(FCk_Handle_EmoteWheel InWheel, int32 InPrevIndex, int32 InNewIndex)
    {
        _HoverChangeCount += 1;
    }

    UFUNCTION()
    private void OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote)
    {
        _ChosenCount += 1;
        _ChosenIndex = InIndex;
        _ChosenEmote = InEmote;
        _ClosedCountWhenChosen = _ClosedCount;
    }

    UFUNCTION()
    private void Step_Open(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_Open();
    }

    UFUNCTION()
    private void Step_MoveUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_MovePointer(FMars_Request_EmoteWheel_MovePointer(FVector2D(0.0, -_Travel)));
    }

    // From the top of the rim, two travels right and one down: clamped back onto the rim at 3 o'clock.
    UFUNCTION()
    private void Step_PushRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_MovePointer(FMars_Request_EmoteWheel_MovePointer(FVector2D(2.0 * _Travel, _Travel)));
    }

    UFUNCTION()
    private void Step_Confirm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Wheel.Request_Close(FMars_Request_EmoteWheel_Close(true));
    }

    UFUNCTION()
    private void Check_RequestsDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Wheel.Has_Fragment(FMars_Fragment_EmoteWheel_Requests) == false);
    }

    UFUNCTION()
    private void Check_OpenCentred(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OpenedCount == 1 && _Wheel.Get_IsOpen() && _Wheel.Get_HoveredIndex() == -1
            && _Wheel.Get_Pointer().IsNearlyZero() && _HoverChangeCount == 0);
    }

    UFUNCTION()
    private void Check_HoveredZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Wheel.Get_HoveredIndex() == 0 && _HoverChangeCount == 1);
    }

    UFUNCTION()
    private void Check_HoveredRight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Expected = utils_emote_wheel::Get_SectorAt(FVector2D(1.0, 0.0), _Wheel.Get_EntryCount(), _Wheel.Get_DeadZoneRatio());
        auto Res = OutResult;
        Res.Set(_Wheel.Get_HoveredIndex() == Expected && Math::IsNearlyEqual(_Wheel.Get_Pointer().Size(), 1.0, 0.001));
    }

    UFUNCTION()
    private void Check_ChosenThenClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Expected = utils_emote_wheel::Get_SectorAt(FVector2D(1.0, 0.0), _Wheel.Get_EntryCount(), _Wheel.Get_DeadZoneRatio());
        const auto ExpectedEntry = _Wheel.TryGet_Entry(Expected);
        auto Res = OutResult;
        Res.Set(_ChosenCount == 1 && _ChosenIndex == Expected && ExpectedEntry.IsSet()
            && _ChosenEmote == ExpectedEntry.GetValue().Emote && _ClosedCountWhenChosen == 0
            && _ClosedCount == 1 && _Wheel.Get_IsOpen() == false && _Wheel.Get_HoveredIndex() == -1);
    }

    UFUNCTION()
    private void Check_OpenAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OpenedCount == 2 && _Wheel.Get_IsOpen() && _Wheel.Get_HoveredIndex() == -1);
    }

    UFUNCTION()
    private void Check_ClosedWithoutChoice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ClosedCount == 2 && _ChosenCount == 1 && _Wheel.Get_IsOpen() == false);
    }
}
