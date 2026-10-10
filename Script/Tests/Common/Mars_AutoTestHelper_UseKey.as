// One more intent row on a key of its own, baked beside the Use row: Token is the row's token in the intent grammar (the
// gameplay input profile's own: BK Back, IP Interact_Primary, IS Interact_Secondary, AF StationAddFood).
struct FMars_AutoTestHelper_KeyRow
{
    FKey Key;
    FGameplayTag Intent;
    FName Token;

    FMars_AutoTestHelper_KeyRow() {}

    FMars_AutoTestHelper_KeyRow(FKey InKey, FGameplayTag InIntent, FName InToken)
    {
        Key = InKey;
        Intent = InIntent;
        Token = InToken;
    }
}

// A private input stack a test presses Use (and any extra rows) on, for the player's level rows: a source, a button map with
// one physical key per row, a sampler, a layer and its matcher. The test hands the matcher to its carrier's InputIntents and
// bakes the rows into it; a press and a release are raw key events on the source.
UCLASS()
class UMars_AutoTestHelper_UseKey : UObject
{
    // The Use row first, then the extra rows in the order given.
    private TArray<FMars_AutoTestHelper_KeyRow> _Rows;
    private FCk_Handle_InputSource _Source;
    private FCk_Handle_InputButtonMap _Map;
    private FCk_Handle_IntentSampler _Sampler;
    private FCk_Handle_IntentMatcher _Matcher;

    // The Use row alone, on InKey. The stack hangs off a child of InOwner, so it ends with the test.
    void Build(FCk_Handle InOwner, FKey InKey)
    {
        Build_WithRows(InOwner, InKey, TArray<FMars_AutoTestHelper_KeyRow>());
    }

    // The Use row on InUseKey and InExtraRows beside it, each on its own key.
    void Build_WithRows(FCk_Handle InOwner, FKey InUseKey, const TArray<FMars_AutoTestHelper_KeyRow>& InExtraRows)
    {
        _Rows.Empty();
        _Rows.Add(FMars_AutoTestHelper_KeyRow(InUseKey, GameplayTags::Mars_Intent_Interact_Use, n"IU"));
        _Rows.Append(InExtraRows);

        auto Parent = InOwner;
        auto Owner = utils_entity_lifetime::Request_CreateEntity(Parent);
        _Source = utils_input_source::Add(Owner, FCk_InputSource_Spec(0));

        TArray<FKey> PhysicalButtons;
        for (const auto& Row : _Rows)
        { PhysicalButtons.Add(Row.Key); }

        _Map = utils_input_button_map::Add(Owner, FCk_InputButtonMap_Spec(PhysicalButtons));
        _Sampler = utils_intent_sampler::Add(Owner, FCk_IntentSampler_Spec(120));

        FCk_Handle LayerEntity = utils_input_layer::Create(Owner, FCk_InputLayer_Spec(_Source, 50));
        _Matcher = utils_intent_matcher::Add(LayerEntity, FCk_IntentMatcher_Spec());
    }

    FCk_Handle_IntentMatcher Get_Matcher() const
    {
        return _Matcher;
    }

    // Every row's key is minted on the button map and the sampler records frames.
    bool Get_IsRecording()
    {
        for (const auto& Row : _Rows)
        {
            if (utils_input_button_map::Get_ButtonIdsForKey(_Map, Row.Key).Num() < 1)
            { return false; }
        }

        return utils_intent_sampler::Get_FrameCount(_Sampler) >= 1;
    }

    // Bakes every row as a level row on its key and swaps them into the matcher. Invalid when a notation fails to parse or
    // the set fails to bake.
    FMars_Validation Request_SwapUseSet()
    {
        TArray<FCk_Intent_Definition> Definitions;
        TArray<FCk_Intent_ButtonNameRow> ButtonRows;
        for (const auto& Row : _Rows)
        {
            auto Parsed = utils_intent_grammar::Parse(f"{Row.Token.ToString()} level", Row.Intent.TagName, 0, Row.Intent);
            if (Parsed.Get_Outcome() != ECk_SucceededFailed::Succeeded)
            { return FMars_Validation(f"the {Row.Token.ToString()} level notation failed to parse"); }

            Definitions.Add(Parsed.Get_Definition());
            ButtonRows.Add(FCk_Intent_ButtonNameRow(Row.Token, FCk_Input_ButtonId(ECk_Input_ButtonTier::Physical, Row.Key.GetKeyName())));
        }

        auto Baked = utils_intent_grammar::Bake(Definitions, ButtonRows);
        if (Baked.Get_Outcome() != ECk_SucceededFailed::Succeeded)
        { return FMars_Validation("the level rows failed to bake"); }

        utils_intent_matcher::Request_SwapSet(_Matcher, FCk_Request_IntentMatcher_SwapSet(Baked.Get_CompiledSet()));
        return FMars_Validation();
    }

    // Every row is live on the matcher, each captured on its key.
    bool Get_IsUseSetActive()
    {
        if (utils_intent_matcher::Get_ActiveIntentCount(_Matcher) != _Rows.Num())
        { return false; }

        const auto CaptureKeys = utils_intent_matcher::Get_RegisteredCaptureKeys(_Matcher);
        for (const auto& Row : _Rows)
        {
            if (CaptureKeys.Contains(Row.Key) == false)
            { return false; }
        }

        return true;
    }

    void Press()
    {
        Inject(_Rows[0].Key, ECk_InputSource_EventType::Pressed);
    }

    void Release()
    {
        Inject(_Rows[0].Key, ECk_InputSource_EventType::Released);
    }

    // Presses the key of the row for InIntent; a row this stack was not built with is the test's defect.
    void Press_Row(FGameplayTag InIntent)
    {
        Inject(Get_KeyFor(InIntent), ECk_InputSource_EventType::Pressed);
    }

    void Release_Row(FGameplayTag InIntent)
    {
        Inject(Get_KeyFor(InIntent), ECk_InputSource_EventType::Released);
    }

    private FKey Get_KeyFor(FGameplayTag InIntent) const
    {
        for (const auto& Row : _Rows)
        {
            if (Row.Intent == InIntent)
            { return Row.Key; }
        }

        ck::EnsureIfNot(false, f"[UseKey] no row for [{InIntent.ToString()}]");
        return FKey();
    }

    private void Inject(FKey InKey, ECk_InputSource_EventType InEventType)
    {
        auto Event = FCk_InputSource_RawEvent(ECk_InputSource_DeviceClass::Keyboard, InKey, InEventType);
        utils_input_source::Request_InjectRawEvent(_Source, FCk_Request_InputSource_InjectRawEvent(Event));
    }
}
