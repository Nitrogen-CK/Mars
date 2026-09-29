struct FMars_Gameplay_IntentRow
{
    FString Token;
    FName MappingName;
    FGameplayTag IntentTag;

    FMars_Gameplay_IntentRow() {}

    FMars_Gameplay_IntentRow(FString InToken, FName InMappingName, FGameplayTag InIntentTag)
    {
        Token = InToken;
        MappingName = InMappingName;
        IntentTag = InIntentTag;
    }
}

// Move and look stay on Enhanced Input (analog, not graded). Every button is a CkIntent LEVEL row
// on this profile's own input layer: Active while held, Idle on release. The matcher is handed to
// the pawn's InputIntents feature, and the player HFSM polls it - nothing here decides what a
// press does.
//
// Button rows terminate on MAPPED buttons, minted from this profile's IMC registration (the
// action-level PlayerMappableKeySettings names), so a rebind re-points the row with no code change.
// The source, the mint and the pawn all arrive on separate edges, so one retry tick owns composition.
class UMars_InputProfile_Gameplay : UMars_InputProfile
{
    protected int32 LayerPriority = 10;

    private float32 MouseLookScale = 0.4f;
    private float32 GamepadYawRate = 70.0f;
    private float32 GamepadPitchRate = 45.0f;

    private FCk_Handle_InputLayer _Layer;
    private FCk_Handle_IntentMatcher _Matcher;
    private FTimerHandle _ComposeTimer;
    private bool _SwapRequested = false;
    private bool _SwapSucceeded = false;
    private int32 _ComposeAttempts = 0;

    UFUNCTION(BlueprintOverride)
    void Setup(UEnhancedInputComponent InInputComponent)
    {
        Super::Setup(InInputComponent);

        Context = NewObject(this, UInputMappingContext);
        SetupKeyboardBindings();
        SetupGamepadBindings();

        InInputComponent.BindAction(mars::Mars_IA_Move, ETriggerEvent::Triggered,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnMove"));
        InInputComponent.BindAction(mars::Mars_IA_Move, ETriggerEvent::Completed,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnMove"));
        InInputComponent.BindAction(mars::Mars_IA_Look, ETriggerEvent::Triggered,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnLook"));
        InInputComponent.BindAction(mars::Mars_IA_CycleSlot, ETriggerEvent::Triggered,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnCycleSlot"));
    }

    UFUNCTION(BlueprintOverride)
    void Activate(APlayerController InController, APawn InPawn)
    {
        Super::Activate(InController, InPawn);

        _SwapRequested = false;
        _SwapSucceeded = false;
        _ComposeAttempts = 0;
        System::ClearAndInvalidateTimerHandle(_ComposeTimer);
        _ComposeTimer = System::SetTimer(this, n"DoTryCompose", 0.1f, true);
        DoTryCompose();
    }

    UFUNCTION(BlueprintOverride)
    void Repoint(APawn InNewPawn)
    {
        auto OldIntents = TryGet_PawnIntents();
        if (ck::IsValid(OldIntents))
        { OldIntents.Set_Matcher(FCk_Handle_IntentMatcher()); }

        Super::Repoint(InNewPawn);
        DoTryCompose();
    }

    // Destroying the layer emits no phase signal, but the pawn stops reading the matcher, so every
    // intent polls Idle from here on.
    UFUNCTION(BlueprintOverride)
    void Deactivate(APlayerController InController)
    {
        System::ClearAndInvalidateTimerHandle(_ComposeTimer);

        auto Intents = TryGet_PawnIntents();
        if (ck::IsValid(Intents))
        {
            Intents.Set_Matcher(FCk_Handle_IntentMatcher());
            Intents.Set_MoveDirection(FVector::ZeroVector);
        }

        if (ck::IsValid(_Layer))
        { utils_entity_lifetime::Request_DestroyEntity(_Layer); }

        _Layer = FCk_Handle_InputLayer();
        _Matcher = FCk_Handle_IntentMatcher();
        _SwapRequested = false;
        _SwapSucceeded = false;

        Super::Deactivate(InController);
    }

    //--------------------------------------------------------------------------------------------
    // Enhanced Input mappings
    //--------------------------------------------------------------------------------------------

    private void SetupKeyboardBindings()
    {
        auto IA_Move = mars::Mars_IA_Move;

        Context.MapKey(IA_Move, EKeys::W);

        auto& MappingA = Context.MapKey(IA_Move, EKeys::A);
        MappingA.Modifiers.Add(NewObject(Context, UInputModifierNegate));
        auto SwizzleA = NewObject(Context, UInputModifierSwizzleAxis);
        SwizzleA.Order = EInputAxisSwizzle::YXZ;
        MappingA.Modifiers.Add(SwizzleA);

        auto& MappingS = Context.MapKey(IA_Move, EKeys::S);
        MappingS.Modifiers.Add(NewObject(Context, UInputModifierNegate));

        auto& MappingD = Context.MapKey(IA_Move, EKeys::D);
        auto SwizzleD = NewObject(Context, UInputModifierSwizzleAxis);
        SwizzleD.Order = EInputAxisSwizzle::YXZ;
        MappingD.Modifiers.Add(SwizzleD);

        auto Scope = GameplayTag::MakeContainerFromTag(GameplayTags::Input_Scope_Gameplay);
        auto Category = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        utils_key_binding::MakeMappingPlayerMappable(Context, IA_Move, EKeys::W,
            n"IA_Move_Forward", NSLOCTEXT("MarsSettingsUI", "KeybindMoveForward", "Move Forward"), Category, Scope);
        utils_key_binding::MakeMappingPlayerMappable(Context, IA_Move, EKeys::S,
            n"IA_Move_Backward", NSLOCTEXT("MarsSettingsUI", "KeybindMoveBackward", "Move Backward"), Category, Scope);
        utils_key_binding::MakeMappingPlayerMappable(Context, IA_Move, EKeys::A,
            n"IA_Move_Left", NSLOCTEXT("MarsSettingsUI", "KeybindMoveLeft", "Move Left"), Category, Scope);
        utils_key_binding::MakeMappingPlayerMappable(Context, IA_Move, EKeys::D,
            n"IA_Move_Right", NSLOCTEXT("MarsSettingsUI", "KeybindMoveRight", "Move Right"), Category, Scope);

        Context.MapKey(mars::Mars_IA_Look, EKeys::Mouse2D);

        Context.MapKey(mars::Mars_IA_Jump, EKeys::SpaceBar);
        Context.MapKey(mars::Mars_IA_Sprint, EKeys::LeftShift);
        Context.MapKey(mars::Mars_IA_Crouch, EKeys::LeftControl);
        Context.MapKey(mars::Mars_IA_Crouch, EKeys::C);
        Context.MapKey(mars::Mars_IA_Interact_Primary, EKeys::LeftMouseButton);
        Context.MapKey(mars::Mars_IA_Interact_Secondary, EKeys::RightMouseButton);
        Context.MapKey(mars::Mars_IA_Interact_Use, EKeys::E);
        Context.MapKey(mars::Mars_IA_Slot1, EKeys::One);
        Context.MapKey(mars::Mars_IA_Slot2, EKeys::Two);
        Context.MapKey(mars::Mars_IA_Slot3, EKeys::Three);
        Context.MapKey(mars::Mars_IA_Slot4, EKeys::Four);
        Context.MapKey(mars::Mars_IA_Drop, EKeys::Q);
        Context.MapKey(mars::Mars_IA_CycleSlot, EKeys::MouseWheelAxis);

        Context.MapKey(mars::Mars_IA_ToggleDebugger, EKeys::F9);
    }

    private void SetupGamepadBindings()
    {
        auto& MappingLeftStick = Context.MapKey(mars::Mars_IA_Move, EKeys::Gamepad_Left2D);
        auto DeadzoneLeft = NewObject(Context, UInputModifierDeadZone);
        DeadzoneLeft.LowerThreshold = 0.2f;
        DeadzoneLeft.UpperThreshold = 1.0f;
        DeadzoneLeft.Type = EDeadZoneType::Radial;
        MappingLeftStick.Modifiers.Add(DeadzoneLeft);
        auto SwizzleLeft = NewObject(Context, UInputModifierSwizzleAxis);
        SwizzleLeft.Order = EInputAxisSwizzle::YXZ;
        MappingLeftStick.Modifiers.Add(SwizzleLeft);

        auto& MappingRightStick = Context.MapKey(mars::Mars_IA_Look, EKeys::Gamepad_Right2D);
        auto DeadzoneRight = NewObject(Context, UInputModifierDeadZone);
        DeadzoneRight.LowerThreshold = 0.2f;
        DeadzoneRight.UpperThreshold = 1.0f;
        DeadzoneRight.Type = EDeadZoneType::Radial;
        MappingRightStick.Modifiers.Add(DeadzoneRight);
        MappingRightStick.Modifiers.Add(NewObject(Context, UInputModifierScaleByDeltaTime));
        auto RateRight = NewObject(Context, UInputModifierScalar);
        RateRight.Scalar = FVector(GamepadYawRate / MouseLookScale, GamepadPitchRate / MouseLookScale, 1.0f);
        MappingRightStick.Modifiers.Add(RateRight);

        Context.MapKey(mars::Mars_IA_Jump, EKeys::Gamepad_FaceButton_Bottom);
        Context.MapKey(mars::Mars_IA_Sprint, EKeys::Gamepad_LeftThumbstick);
        Context.MapKey(mars::Mars_IA_Crouch, EKeys::Gamepad_FaceButton_Right);
        Context.MapKey(mars::Mars_IA_Interact_Primary, EKeys::Gamepad_RightTrigger);
        Context.MapKey(mars::Mars_IA_Interact_Secondary, EKeys::Gamepad_LeftTrigger);
        Context.MapKey(mars::Mars_IA_Interact_Use, EKeys::Gamepad_FaceButton_Left);
        Context.MapKey(mars::Mars_IA_Slot1, EKeys::Gamepad_DPad_Left);
        Context.MapKey(mars::Mars_IA_Slot2, EKeys::Gamepad_DPad_Up);
        Context.MapKey(mars::Mars_IA_Slot3, EKeys::Gamepad_DPad_Right);
        Context.MapKey(mars::Mars_IA_Slot4, EKeys::Gamepad_DPad_Down);
        Context.MapKey(mars::Mars_IA_Drop, EKeys::Gamepad_FaceButton_Top);
        Context.MapKey(mars::Mars_IA_CycleSlot, EKeys::Gamepad_RightShoulder);
        auto& MappingCyclePrevious = Context.MapKey(mars::Mars_IA_CycleSlot, EKeys::Gamepad_LeftShoulder);
        MappingCyclePrevious.Modifiers.Add(NewObject(Context, UInputModifierNegate));
    }

    //--------------------------------------------------------------------------------------------
    // Enhanced Input handlers
    //--------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnMove(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        auto Intents = TryGet_PawnIntents();
        if (ck::Is_NOT_Valid(Intents))
        { return; }

        const auto Input = ActionValue.GetAxis2D();
        Intents.Set_MoveDirection(FVector(Input.X, Input.Y, 0.0));
    }

    // Legacy input scales are on (DefaultInput.ini bEnableLegacyInputScales): the controller scales
    // pitch by -2.5, so stick/mouse up needs a negative pitch input.
    UFUNCTION()
    private void OnLook(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (ck::Is_NOT_Valid(ControlledPawn))
        { return; }

        const auto LookDelta = ActionValue.GetAxis2D();
        ControlledPawn.AddControllerYawInput(float32(LookDelta.X) * MouseLookScale);
        ControlledPawn.AddControllerPitchInput(float32(-LookDelta.Y) * MouseLookScale);
    }

    // A wheel tick is pressed and released inside one frame, which a polled level row can miss - so cycling is an
    // axis handled here, alongside Move/Look.
    UFUNCTION()
    private void OnCycleSlot(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        auto Hotbar = TryGet_PawnHotbar();
        if (ck::Is_NOT_Valid(Hotbar))
        { return; }

        const auto Value = ActionValue.GetAxis1D();
        if (Value > 0.0f)
        { Hotbar.Request_CycleNext(); }
        else if (Value < 0.0f)
        { Hotbar.Request_CyclePrevious(); }
    }

    private FCk_Handle_Hotbar TryGet_PawnHotbar() const
    {
        if (ck::Is_NOT_Valid(ControlledPawn) || ControlledPawn.Get_IsActorEcsReady() == false)
        { return FCk_Handle_Hotbar(); }

        return ControlledPawn.TryGet_ActorEntityHandle().As_Hotbar(ECk_SanityCheck::UnChecked);
    }

    //--------------------------------------------------------------------------------------------
    // CkIntent composition
    //--------------------------------------------------------------------------------------------

    private TArray<FMars_Gameplay_IntentRow> Get_IntentRows() const
    {
        TArray<FMars_Gameplay_IntentRow> Rows;
        Rows.Add(FMars_Gameplay_IntentRow("JP", n"IA_Jump", GameplayTags::Mars_Intent_Jump));
        Rows.Add(FMars_Gameplay_IntentRow("SP", n"IA_Sprint", GameplayTags::Mars_Intent_Sprint));
        Rows.Add(FMars_Gameplay_IntentRow("CR", n"IA_Crouch", GameplayTags::Mars_Intent_Crouch));
        Rows.Add(FMars_Gameplay_IntentRow("IP", n"IA_Interact_Primary", GameplayTags::Mars_Intent_Interact_Primary));
        Rows.Add(FMars_Gameplay_IntentRow("IS", n"IA_Interact_Secondary", GameplayTags::Mars_Intent_Interact_Secondary));
        Rows.Add(FMars_Gameplay_IntentRow("IU", n"IA_Interact_Use", GameplayTags::Mars_Intent_Interact_Use));
        Rows.Add(FMars_Gameplay_IntentRow("SA", n"IA_Slot1", GameplayTags::Mars_Intent_Slot1));
        Rows.Add(FMars_Gameplay_IntentRow("SB", n"IA_Slot2", GameplayTags::Mars_Intent_Slot2));
        Rows.Add(FMars_Gameplay_IntentRow("SC", n"IA_Slot3", GameplayTags::Mars_Intent_Slot3));
        Rows.Add(FMars_Gameplay_IntentRow("SD", n"IA_Slot4", GameplayTags::Mars_Intent_Slot4));
        Rows.Add(FMars_Gameplay_IntentRow("DR", n"IA_Drop", GameplayTags::Mars_Intent_Drop));
        return Rows;
    }

    UFUNCTION()
    private void DoTryCompose()
    {
        if (ck::Is_NOT_Valid(OwningController) || OwningController.Get_IsActorEcsReady() == false)
        { return; }

        auto SourceSubsystem = UCk_InputSource_Subsystem::Get(OwningController);
        if (ck::Is_NOT_Valid(SourceSubsystem))
        { return; }

        auto Source = SourceSubsystem.Get_InputSource();
        if (ck::Is_NOT_Valid(Source))
        { return; }

        auto ButtonMap = DoEnsureSourceComposed(Source);

        if (ck::Is_NOT_Valid(_Layer))
        {
            _Layer = utils_input_layer::Create(ck::ToEntity(OwningController), FCk_InputLayer_Spec(Source, LayerPriority));
            utils_handle::Set_DebugName(_Layer, n"GameplayInputLayer");

            FCk_Handle LayerEntity = _Layer;
            _Matcher = utils_intent_matcher::Add(LayerEntity, FCk_IntentMatcher_Spec());
        }

        if (_SwapRequested == false && Get_AreRowsMinted(ButtonMap))
        { DoRequestSwap(); }

        // ~5s at the 0.1s cadence: one unminted button costs every button on the layer, silently.
        _ComposeAttempts += 1;
        if (_ComposeAttempts == 50 && _SwapSucceeded == false)
        { ck::Warning("[GameplayInput] the intent set has not composed after 5s - is every IA_* row's Mapped button minted (IMC registered with user settings)?"); }

        if (_SwapSucceeded == false)
        { return; }

        auto Intents = TryGet_PawnIntents();
        if (ck::Is_NOT_Valid(Intents))
        { return; }

        Intents.Set_Matcher(_Matcher);
        System::ClearAndInvalidateTimerHandle(_ComposeTimer);
    }

    // One button map and one sampler per source - idempotent, whoever ticks first composes them.
    // The map re-derives every pass because registering an IMC does not trigger its derive.
    private FCk_Handle_InputButtonMap DoEnsureSourceComposed(FCk_Handle_InputSource InSource)
    {
        FCk_Handle SourceEntity = InSource;

        if (utils_intent_sampler::DoCast(SourceEntity).IsSet() == false)
        { utils_intent_sampler::Add(SourceEntity, FCk_IntentSampler_Spec(120)); }

        auto ExistingMap = utils_input_button_map::DoCast(SourceEntity);
        if (ExistingMap.IsSet() == false)
        { return utils_input_button_map::Add(SourceEntity, FCk_InputButtonMap_Spec(TArray<FKey>())); }

        auto ButtonMap = ExistingMap.GetValue();
        utils_input_button_map::Request_Rederive(ButtonMap, FCk_Request_InputButtonMap_Rederive());
        return ButtonMap;
    }

    // The swap is atomic - one unminted terminal rejects the whole set - so wait for every mint.
    private bool Get_AreRowsMinted(FCk_Handle_InputButtonMap InButtonMap) const
    {
        if (ck::Is_NOT_Valid(InButtonMap))
        { return false; }

        auto Rows = Get_IntentRows();
        for (const auto& Row : Rows)
        {
            const auto Button = FCk_Input_ButtonId(ECk_Input_ButtonTier::Mapped, Row.MappingName);
            if (utils_input_button_map::TryGet_KeyForButton(InButtonMap, Button).IsValid() == false)
            { return false; }
        }
        return true;
    }

    private void DoRequestSwap()
    {
        TArray<FCk_Intent_Definition> Definitions;
        TArray<FCk_Intent_ButtonNameRow> ButtonRows;

        auto Rows = Get_IntentRows();
        for (const auto& Row : Rows)
        {
            auto Parsed = utils_intent_grammar::Parse(f"{Row.Token} level", Row.IntentTag.TagName, 0, Row.IntentTag);
            if (ck::EnsureIfNot(Parsed.Get_Outcome() == ECk_SucceededFailed::Succeeded,
                f"[GameplayInput] the {Row.IntentTag.ToString()} notation failed to parse"))
            { continue; }

            Definitions.Add(Parsed.Get_Definition());
            ButtonRows.Add(FCk_Intent_ButtonNameRow(FName(Row.Token), FCk_Input_ButtonId(ECk_Input_ButtonTier::Mapped, Row.MappingName)));
        }

        auto Baked = utils_intent_grammar::Bake(Definitions, ButtonRows);
        if (ck::EnsureIfNot(Baked.Get_Outcome() == ECk_SucceededFailed::Succeeded, "[GameplayInput] the gameplay intent set failed to bake"))
        {
            System::ClearAndInvalidateTimerHandle(_ComposeTimer);
            return;
        }

        utils_intent_matcher::Request_SwapSet(_Matcher,
            FCk_Request_IntentMatcher_SwapSet(Baked.Get_CompiledSet()),
            FCk_Delegate_Request_OnCompleted(this, n"OnSwapCompleted"));
        _SwapRequested = true;
    }

    UFUNCTION()
    private void OnSwapCompleted(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        if (InResult != ECk_Request_OperationResult::Succeeded)
        {
            // A terminal lost its key between the mint check and the drain - retry from the tick.
            _SwapRequested = false;
            return;
        }

        _SwapSucceeded = true;
        DoTryCompose();
    }
}
