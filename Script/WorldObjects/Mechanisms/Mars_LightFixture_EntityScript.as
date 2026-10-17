// Placeable ceiling light: a shade and a bulb hanging from its origin (the mounting point; it hangs along local -Z), with a
// point light under the shade. With Sink input channels it is a MechanismSink and lights only while powered (a light
// switch is a Toggle switch's MechanismSource on one of those channels); without them it is always lit.
class UMars_LightFixture_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // No sink is added while InputChannels is empty.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSink_Spec Sink;

    UPROPERTY(ExposeOnSpawn)
    float32 Intensity = 8000.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 AttenuationRadius = 1100.0f;

    UPROPERTY(ExposeOnSpawn)
    FLinearColor LightColor = FLinearColor(1.0f, 0.9f, 0.75f, 1.0f);

    // How far below the mounting point the bulb hangs.
    UPROPERTY(ExposeOnSpawn)
    float64 DropLength = 40.0;

    private FCk_Handle_MechanismSink _Sink;
    private UPointLightComponent _Light;
    private FCk_Handle_UnrealComponent _Bulb;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsLightFixture");

        if (Sink.InputChannels.Num() > 0)
        {
            _Sink = utils_mechanism_sink::Add(InHandle, Sink);
            if (ck::IsValid(_Sink))
            { _Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnPoweredChanged")); }
        }

        AddVisuals(Root);
        AddLight(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        // Engine shapes are 100 uu with a centered pivot: a 4 uu rod down to a 30 x 30 x 12 shade, the 14 uu bulb under it.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -DropLength * 0.5), FVector(0.04, 0.04, DropLength * 0.01)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"LightFixture_Rod"));

        auto Shade = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -DropLength - 6.0), FVector(0.3, 0.3, 0.12)),
            engine::load::Cone(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"LightFixture_Shade");
        Shade.CastShadow = false;
        InRoot.Add_MeshPart(this, Shade);

        auto Bulb = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -DropLength - 14.0), FVector(0.14, 0.14, 0.14)),
            engine::load::Sphere(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"LightFixture_Bulb");
        Bulb.CastShadow = false;
        _Bulb = InRoot.Add_MeshPart(this, Bulb);
        if (ck::IsValid(_Bulb))
        { utils_unreal_component::BindTo_OnAdded(_Bulb, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }
    }

    private void AddLight(FCk_Handle_Transform& InRoot)
    {
        auto Node = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -DropLength - 30.0)));

        auto Archetype = Cast<UPointLightComponent>(NewObject(this, UPointLightComponent));
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetLightColor(LightColor);
        Archetype.SetIntensity(Intensity);
        Archetype.SetAttenuationRadius(AttenuationRadius);
        Archetype.SetCastShadows(true);
        Archetype.SetVisibility(false);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"LightFixture_Light");
        auto Light = utils_unreal_component::Add(Node.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Light, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded"));
    }

    // Without a sink it is always lit; with one, only once the sink has evaluated powered.
    private bool Get_IsLit() const
    {
        if (ck::Is_NOT_Valid(_Sink))
        { return true; }

        return _Sink.Get_HasEvaluated() && _Sink.Get_IsPowered();
    }

    // Visual only; the sink is the source of truth.
    private void Refresh()
    {
        const auto IsLit = Get_IsLit();
        if (ck::IsValid(_Light))
        { _Light.SetVisibility(IsLit); }

        const auto Dim = FLinearColor(0.06f, 0.06f, 0.06f, 1.0f);
        _Bulb.Paint_MeshPart(IsLit ? LightColor : Dim);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLightAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Light = Cast<UPointLightComponent>(utils_unreal_component::Get_Component(InHandle));
        Refresh();
    }

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh();
    }

    UFUNCTION()
    private void OnPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        Refresh();
    }
}
