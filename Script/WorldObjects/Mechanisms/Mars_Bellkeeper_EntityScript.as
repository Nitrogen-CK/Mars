// Placeable Bellkeeper dial lock: a wall plate with one dial per Phrase glyph, each ringed by the six glyphs. Use turns a
// dial one detent clockwise; nothing marks the answer. Every rising edge on CommitChannel (a pull chain) judges the dials:
// a wrong commit asserts VentChannel for VentPulseSeconds (a steam vent listens) and costs the front reward, the last is
// always kept; the right one locks the dials, asserts Source and spawns the remaining Rewards.
// The origin is the mounting surface and the plate faces local +Z, up = local -X (pitch -90 to face +X on a wall); dial 0
// is on the viewer's left (local +Y). Above the dials, one candle per reward still at stake; beside them a lamp that
// flashes red on a wrong commit and stays green once solved.
class UMars_Bellkeeper_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // The answer, one glyph per dial, left to right. The clue shows the same phrase.
    UPROPERTY(ExposeOnSpawn)
    TArray<EMars_Bellkeeper_Glyph> Phrase;

    // Where each dial starts; none may start on its answer. Missing entries start on Square.
    UPROPERTY(ExposeOnSpawn)
    TArray<EMars_Bellkeeper_Glyph> StartGlyphs;

    // Lost from the front, one per wrong commit. Transforms are offsets from the panel's origin in world axes: the panel's
    // rotation does not turn them.
    UPROPERTY(ExposeOnSpawn)
    TArray<FMars_Bellkeeper_Reward> Rewards;

    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Mechanism.Channel"))
    FGameplayTag CommitChannel;

    // Optional: no vent while unset.
    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Mechanism.Channel"))
    FGameplayTag VentChannel;

    UPROPERTY(ExposeOnSpawn)
    float32 VentPulseSeconds = 2.0f;

    // Optional: unwired while OutputChannel is unset (utils_mechanism_source::TryAdd). Asserted once solved.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UPROPERTY(ExposeOnSpawn)
    FText PromptText = NSLOCTEXT("MarsInteraction", "TurnDialPrompt", "Turn dial");

    private const float64 DialSpacing = 45.0;
    private const float64 PlateThickness = 6.0;
    private const float64 RingRadius = 14.0;
    private const float64 GlyphSize = 6.0;
    private const float64 CandleRowX = -34.0;

    private FCk_Handle_Bellkeeper _Bellkeeper;
    private TArray<FCk_Handle_Dial> _Dials;
    private TArray<FCk_Handle_SceneNode> _Knobs;
    private TArray<FCk_Handle_UnrealComponent> _Candles;
    private FCk_Handle_UnrealComponent _Lamp;
    // Valid while the lamp flashes a wrong commit.
    private FCk_Handle_Timer _FlashTimer;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsBellkeeper");

        AddPlate(Root);
        for (int32 Index = 0; Index < Phrase.Num(); ++Index)
        { AddDial(Root, Index); }

        auto Spec = FMars_Bellkeeper_Spec();
        Spec.Dials = _Dials;
        for (const auto Glyph : Phrase)
        { Spec.Answer.Add(int32(Glyph)); }

        for (const auto& Reward : Rewards)
        {
            const auto World = FTransform(Reward.Transform.Rotator(), SpawnTransform.GetLocation() + Reward.Transform.GetLocation());
            Spec.Rewards.Add(FMars_Bellkeeper_Reward(Reward.Definition, World));
        }

        if (VentChannel.IsValid())
        {
            auto VentEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
            auto VentSpec = FMars_MechanismSource_Spec();
            VentSpec.OutputChannel = VentChannel;
            Spec.VentSource = utils_mechanism_source::Add(VentEntity, VentSpec);
        }
        Spec.VentPulseSeconds = VentPulseSeconds;

        _Bellkeeper = utils_bellkeeper::Add(InHandle, Spec);

        // A rejected spec already ensured in utils_bellkeeper::Add; the plate and dials still show where the lock is.
        if (ck::IsValid(_Bellkeeper))
        {
            auto SinkSpec = FMars_MechanismSink_Spec();
            SinkSpec.InputChannels.Add(CommitChannel);
            SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
            utils_mechanism_sink::Add(InHandle, SinkSpec);

            _Bellkeeper.BindTo_OnCommitFailed(FMars_Delegate_Bellkeeper_OnCommitFailed(this, n"OnCommitFailed"));
            _Bellkeeper.BindTo_OnSolved(FMars_Delegate_Bellkeeper_OnSolved(this, n"OnSolved"));
        }

        utils_mechanism_source::TryAdd(InHandle, Source);

        AddLights(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // Dial InIndex's centre on the plate, dial 0 on the viewer's left (local +Y).
    private FVector Get_DialCenter(int32 InIndex) const
    {
        const auto FirstY = (Phrase.Num() - 1) * DialSpacing * 0.5;
        return FVector(0.0, FirstY - InIndex * DialSpacing, PlateThickness);
    }

    // Glyph InIndex sits clockwise from the top, as the viewer sees the plate.
    private float64 Get_GlyphYaw(int32 InIndex) const
    {
        return 180.0 + InIndex * 360.0 / constants_bellkeeper_glyphs::k_Count;
    }

    private void AddPlate(FCk_Handle_Transform& InRoot)
    {
        const auto Width = Math::Max(Phrase.Num(), 1) * DialSpacing + 20.0;
        const auto Height = 90.0;

        // Engine cube is 100 uu with a centered pivot. The plate runs from X -45 (top, above the candles) to +45.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(-5.0, 0.0, PlateThickness * 0.5), FVector(Height, Width, PlateThickness) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"Bellkeeper_Plate"));
    }

    private void AddDial(FCk_Handle_Transform& InRoot, int32 InIndex)
    {
        auto DialNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, Get_DialCenter(InIndex)));
        auto DialEntity = DialNode.H();

        auto DialSpec = FMars_Dial_Spec();
        DialSpec.Positions = constants_bellkeeper_glyphs::k_Count;
        DialSpec.StartIndex = StartGlyphs.IsValidIndex(InIndex) ? int32(StartGlyphs[InIndex]) : 0;
        auto Dial = utils_dial::Add(DialEntity, DialSpec);
        _Dials.Add(Dial);

        // The dial face, its ring of glyphs, then the knob whose pointer the dial turns.
        auto Face = DialNode.As_Transform();
        auto FacePart = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 0.5), FVector(0.4, 0.4, 0.01)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_DialFace");
        FacePart.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.08f, 0.07f, 0.06f, 1.0f));
        Face.Add_MeshPart(this, FacePart);

        for (int32 Glyph = 0; Glyph < constants_bellkeeper_glyphs::k_Count; ++Glyph)
        {
            const auto Yaw = Math::DegreesToRadians(Get_GlyphYaw(Glyph));
            const auto Center = FVector(Math::Cos(Yaw) * RingRadius, Math::Sin(Yaw) * RingRadius, 1.0);
            Face.Add_BellkeeperGlyph(this, FMars_Bellkeeper_GlyphPlacement(EMars_Bellkeeper_Glyph(Glyph), Center, GlyphSize));
        }

        const auto StartYaw = Get_GlyphYaw(DialSpec.StartIndex);
        auto Knob = utils_scene_node::Create(Face, FTransform(FRotator(0.0, StartYaw, 0.0), FVector::ZeroVector));
        _Knobs.Add(Knob);

        auto KnobTransform = Knob.As_Transform();
        KnobTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 3.0), FVector(0.14, 0.14, 0.05)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_Knob"));

        // The pointer runs along the knob's +X, which the knob's yaw turns onto the glyph it points at.
        auto PointerPart = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(5.5, 0.0, 6.0), FVector(0.09, 0.025, 0.02)),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_Pointer");
        PointerPart.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.9f, 0.85f, 0.7f, 1.0f));
        KnobTransform.Add_MeshPart(this, PointerPart);

        if (ck::Is_NOT_Valid(Dial))
        { return; }

        Dial.BindTo_OnIndexChanged(FMars_Delegate_Dial_OnIndexChanged(this, n"OnDialIndexChanged"));

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Behavior = EMars_Control_Behavior::Momentary;
        ControlSpec.ActiveSeconds = 0.15f;
        auto Control = utils_control::Add(DialEntity, ControlSpec);

        // A rejected Control spec already ensured in utils_control::Add.
        if (ck::Is_NOT_Valid(Control))
        { return; }

        Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnDialEngaged"));

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(18.0, 18.0, 12.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 6.0));

        auto InteractSpec = FMars_Interactable_Spec();
        InteractSpec.ProbeInfo = Probe;
        InteractSpec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, PromptText)));
        utils_interactable::Create(Face, InteractSpec);
    }

    private void AddLights(FCk_Handle_Transform& InRoot)
    {
        const auto CandleSpacing = 12.0;
        const auto FirstY = (Rewards.Num() - 1) * CandleSpacing * 0.5;
        for (int32 Index = 0; Index < Rewards.Num(); ++Index)
        {
            auto Candle = InRoot.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator::ZeroRotator, FVector(CandleRowX, FirstY - Index * CandleSpacing, PlateThickness + 2.0), FVector(0.05, 0.05, 0.04)),
                engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_Candle"));
            _Candles.Add(Candle);
            if (ck::IsValid(Candle))
            { utils_unreal_component::BindTo_OnAdded(Candle, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded")); }
        }

        const auto LampY = -(FirstY + CandleSpacing * 1.5);
        _Lamp = InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(CandleRowX, LampY, PlateThickness + 2.0), FVector(0.06, 0.06, 0.04)),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_Lamp"));
        if (ck::IsValid(_Lamp))
        { utils_unreal_component::BindTo_OnAdded(_Lamp, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded")); }
    }

    // Visual only; the bellkeeper's state is the source of truth.
    private void Repaint()
    {
        const auto Dark = FLinearColor(0.05f, 0.05f, 0.05f, 1.0f);
        const auto Flame = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
        const auto Wrong = FLinearColor(0.9f, 0.08f, 0.05f, 1.0f);
        const auto Right = FLinearColor(0.1f, 0.85f, 0.2f, 1.0f);

        auto Remaining = 0;
        auto IsSolved = false;
        if (ck::IsValid(_Bellkeeper))
        {
            Remaining = _Bellkeeper.Get_RemainingRewards();
            IsSolved = _Bellkeeper.Get_IsSolved();
        }

        // The candles go out from the front, as the rewards are lost.
        const auto Lost = _Candles.Num() - Remaining;
        for (int32 Index = 0; Index < _Candles.Num(); ++Index)
        { _Candles[Index].Paint_MeshPart(Index < Lost ? Dark : Flame); }

        if (ck::IsValid(_Lamp))
        { _Lamp.Paint_MeshPart(IsSolved ? Right : (ck::IsValid(_FlashTimer) ? Wrong : Dark)); }
    }

    // Without a timer the flash would never clear, so a failed timer leaves the lamp unflashed.
    private void StartWrongFlash()
    {
        const float32 FlashSeconds = 0.8f;

        if (ck::IsValid(_FlashTimer))
        { utils_entity_lifetime::Request_DestroyEntity(_FlashTimer.H()); }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(FlashSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        _FlashTimer = utils_timer::Add(_Bellkeeper.H(), TimerSpec);
        if (ck::IsValid(_FlashTimer))
        { _FlashTimer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnFlashDone")); }

        Repaint();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDialEngaged(FCk_Handle_Control InControl)
    {
        auto Dial = InControl.As_Dial();
        Dial.Request_Step(FMars_Request_Dial_Step(1));
    }

    UFUNCTION()
    private void OnDialIndexChanged(FCk_Handle_Dial InDial, int32 InIndex)
    {
        const auto DialIndex = _Dials.FindIndex(InDial);
        if (_Knobs.IsValidIndex(DialIndex) == false)
        { return; }

        auto Knob = _Knobs[DialIndex];
        utils_scene_node::Request_UpdateOffset(Knob,
            FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator(0.0, Get_GlyphYaw(InIndex), 0.0), FVector::ZeroVector)));
    }

    UFUNCTION()
    private void OnLightAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards)
    {
        StartWrongFlash();
    }

    UFUNCTION()
    private void OnSolved(FCk_Handle_Bellkeeper InBellkeeper)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnFlashDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // A flash restarted by a newer wrong commit can still finish in the frame it was destroyed.
        if (_FlashTimer != InTimer)
        { return; }

        _FlashTimer = FCk_Handle_Timer();
        Repaint();
    }
}
