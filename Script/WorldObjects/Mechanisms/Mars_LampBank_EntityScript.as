// Placeable lamp bank: a MechanismSink whose rising edges charge a Countdown, which asserts the bank's MechanismSource while
// any lamp is lit. One lamp per Countdown step; they go dark one every Countdown.SecondsPerStep, from the last to the first.
// The origin is the mounting surface; local +X points out of it and the lamps run along local Y.
class UMars_LampBank_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Countdown_Spec Countdown;

    // The channels whose rising edge charges the bank. The rule is irrelevant (edges, not power): it is set to AnyChannel.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    private FCk_Handle_Countdown _Countdown;
    private TArray<FCk_Handle_UnrealComponent> _Lamps;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsLampBank");

        if (Sink.InputChannels.Num() > 0)
        {
            auto SinkSpec = Sink;
            SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
            utils_mechanism_sink::Add(InHandle, SinkSpec);
        }

        _Countdown = utils_countdown::Add(InHandle, Countdown);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        // A rejected Countdown spec already ensured in utils_countdown::Add; the lamps then stay dark.
        if (ck::IsValid(_Countdown))
        { _Countdown.BindTo_OnRemainingChanged(FMars_Delegate_Countdown_OnRemainingChanged(this, n"OnRemainingChanged")); }

        AddVisuals(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();

        // Engine cube is 100 uu, pivot at its center.
        const float64 LampSize = 16.0;
        const float64 LampSpacing = 28.0;
        const float64 PlateDepth = 6.0;
        const float64 PlateHeight = 30.0;

        const auto LampCount = Math::Max(Countdown.Steps, 1);
        const auto PlateWidth = LampCount * LampSpacing + 12.0;

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(PlateDepth * 0.5, 0.0, 0.0), FVector(PlateDepth, PlateWidth, PlateHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"LampBank_Plate"));

        auto LampMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();
        const auto FirstY = -(LampCount - 1) * LampSpacing * 0.5;
        for (int32 Index = 0; Index < LampCount; ++Index)
        {
            auto Lamp = InRoot.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator::ZeroRotator, FVector(PlateDepth + LampSize * 0.5, FirstY + Index * LampSpacing, 0.0), FVector(LampSize, LampSize, LampSize) * 0.01),
                CubeMesh, LampMaterial, collision::profile::NoCollision, n"LampBank_Lamp"));

            _Lamps.Add(Lamp);
            if (ck::IsValid(Lamp))
            { utils_unreal_component::BindTo_OnAdded(Lamp, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLampAdded")); }
        }
    }

    // Visual only; the Countdown is the source of truth.
    private void Repaint()
    {
        const auto Dim = FLinearColor(0.06f, 0.06f, 0.06f, 1.0f);
        const auto Lit = FLinearColor(1.0f, 0.55f, 0.08f, 1.0f);

        auto Remaining = 0;
        if (ck::IsValid(_Countdown))
        { Remaining = _Countdown.Get_Remaining(); }

        for (int32 Index = 0; Index < _Lamps.Num(); ++Index)
        { _Lamps[Index].Paint_MeshPart(Index < Remaining ? Lit : Dim); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLampAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Repaint();
    }

    UFUNCTION()
    private void OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining)
    {
        Repaint();
    }
}
