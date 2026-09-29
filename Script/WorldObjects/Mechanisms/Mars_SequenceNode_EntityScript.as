// Placeable sequence logic node: a MechanismSink listening to every step channel feeds a Sequence, which asserts the
// node's MechanismSource once the steps rise in order. Visuals: a small pedestal with one indicator cube per step.
class UMars_SequenceNode_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Sequence_Spec Sequence;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    private FCk_Handle_Sequence _Sequence;
    private TArray<FCk_Handle_UnrealComponent> _Indicators;
    private FCk_Handle_Timer _FlashTimer;
    private bool _IsFlashing = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        auto SinkSpec = FMars_MechanismSink_Spec();
        for (const auto& Step : Sequence.Steps)
        {
            if (Step.IsValid())
            { SinkSpec.InputChannels.AddUnique(Step); }
        }
        SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
        utils_mechanism_sink::Add(InHandle, SinkSpec);

        _Sequence = utils_sequence::Add(InHandle, Sequence);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        _Sequence.BindTo_OnStepAccepted(FMars_Delegate_Sequence_OnStepAccepted(this, n"OnStepAccepted"));
        _Sequence.BindTo_OnInputRejected(FMars_Delegate_Sequence_OnInputRejected(this, n"OnInputRejected"));
        _Sequence.BindTo_OnCompleted(FMars_Delegate_Sequence_OnCompleted(this, n"OnCompleted"));
        _Sequence.BindTo_OnReset(FMars_Delegate_Sequence_OnReset(this, n"OnReset"));

        AddVisuals(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(CubeMesh))
        { return; }

        // Engine cube is 100 uu, pivot at its center. Indicators sit in a row along local Y on top of the pedestal.
        const float64 IndicatorSize = 20.0;
        const float64 IndicatorSpacing = 30.0;
        const float64 PedestalHeight = 90.0;
        const float64 PedestalDepth = 40.0;

        const auto NumSteps = Sequence.Steps.Num();
        const auto PedestalWidth = Math::Max(NumSteps, 1) * IndicatorSpacing + 20.0;

        AddBox(InRoot, FVector(0.0, 0.0, PedestalHeight * 0.5),
            FVector(PedestalDepth, PedestalWidth, PedestalHeight) * 0.01,
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"SequenceNode_Pedestal");

        auto IndicatorMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();
        const auto FirstY = -(NumSteps - 1) * IndicatorSpacing * 0.5;
        for (int32 Index = 0; Index < NumSteps; ++Index)
        {
            auto Indicator = AddBox(InRoot,
                FVector(0.0, FirstY + Index * IndicatorSpacing, PedestalHeight + IndicatorSize * 0.5),
                FVector(IndicatorSize, IndicatorSize, IndicatorSize) * 0.01,
                CubeMesh, IndicatorMaterial, collision::profile::NoCollision, n"SequenceNode_Indicator");

            _Indicators.Add(Indicator);
            if (ck::IsValid(Indicator))
            { utils_unreal_component::BindTo_OnAdded(Indicator, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnIndicatorAdded")); }
        }
    }

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private FCk_Handle_UnrealComponent AddBox(
        FCk_Handle_Transform& InAttachTo,
        FVector InLocation,
        FVector InScale,
        UStaticMesh InMesh,
        UMaterialInterface InMaterial,
        FName InCollisionProfile,
        FName InDebugName)
    {
        auto Node = utils_scene_node::Create(InAttachTo, FTransform(FRotator::ZeroRotator, InLocation, InScale));
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static
        // component refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(InCollisionProfile);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(NodeEntity, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Indicator colors (visual only; the sequence state is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    private void Repaint()
    {
        const auto Dim = FLinearColor(0.06f, 0.06f, 0.06f, 1.0f);
        const auto Accepted = FLinearColor(0.1f, 0.85f, 0.2f, 1.0f);
        const auto Rejected = FLinearColor(0.9f, 0.08f, 0.05f, 1.0f);

        auto Progress = 0;
        auto IsComplete = false;
        if (ck::IsValid(_Sequence))
        {
            Progress = _Sequence.Get_Progress();
            IsComplete = _Sequence.Get_IsComplete();
        }

        for (int32 Index = 0; Index < _Indicators.Num(); ++Index)
        {
            if (_IsFlashing)
            {
                PaintIndicator(_Indicators[Index], Rejected);
                continue;
            }

            PaintIndicator(_Indicators[Index], (IsComplete || Index < Progress) ? Accepted : Dim);
        }
    }

    private void PaintIndicator(FCk_Handle_UnrealComponent InIndicator, FLinearColor InColor)
    {
        if (ck::Is_NOT_Valid(InIndicator))
        { return; }

        // Null until the component is created (asynchronously); OnIndicatorAdded repaints then.
        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InIndicator));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        // Returns the existing dynamic instance on later calls.
        auto Material = Mesh.CreateDynamicMaterialInstance(0);
        if (ck::Is_NOT_Valid(Material))
        { return; }

        Material.SetVectorParameterValue(n"PrimaryColor", InColor);
        Material.SetVectorParameterValue(n"SecondaryColor", ScaleColor(InColor, 0.6f));
        Material.SetVectorParameterValue(n"LineColor", ScaleColor(InColor, 1.5f));
    }

    private FLinearColor ScaleColor(FLinearColor InColor, float32 InScale) const
    {
        return FLinearColor(InColor.R * InScale, InColor.G * InScale, InColor.B * InScale, InColor.A);
    }

    private void StartRejectFlash()
    {
        const float32 FlashSeconds = 0.5f;

        if (ck::IsValid(_FlashTimer))
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(_FlashTimer)); }
        _FlashTimer = FCk_Handle_Timer();

        _IsFlashing = true;

        if (ck::IsValid(_Sequence))
        {
            auto TimerSpec = FCk_Timer_Spec(FCk_Time(FlashSeconds));
            TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                     .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

            auto Entity = FCk_Handle(_Sequence);
            _FlashTimer = utils_timer::Add(Entity, TimerSpec);
            if (ck::IsValid(_FlashTimer))
            { _FlashTimer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnFlashDone")); }
        }

        // Without a timer the flash would never clear.
        if (ck::Is_NOT_Valid(_FlashTimer))
        { _IsFlashing = false; }

        Repaint();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnIndicatorAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnStepAccepted(FCk_Handle_Sequence InSequence, int32 InIndex)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnInputRejected(FCk_Handle_Sequence InSequence, FGameplayTag InChannel)
    {
        StartRejectFlash();
    }

    UFUNCTION()
    private void OnCompleted(FCk_Handle_Sequence InSequence)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnReset(FCk_Handle_Sequence InSequence)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnFlashDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // A flash restarted by a newer rejection can still finish in the frame it was destroyed.
        if ((FCk_Handle(_FlashTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        _FlashTimer = FCk_Handle_Timer();
        _IsFlashing = false;
        Repaint();
    }
}
