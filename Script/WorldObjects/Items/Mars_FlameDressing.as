// How a flame looks: its light's colour and strength by pool (the belt knob is IntensityStowed), its shadows by pool and
// its flicker.
struct FMars_FlameLook
{
    UPROPERTY()
    FLinearColor Color = FLinearColor(1.0f, 0.67f, 0.35f, 1.0f);

    UPROPERTY()
    float32 IntensityHeld = 8000.0f;

    UPROPERTY()
    float32 IntensityStowed = 3000.0f;

    UPROPERTY()
    float32 IntensityWorld = 8000.0f;

    UPROPERTY()
    float32 SourceRadius = 2.0f;

    UPROPERTY()
    bool ShadowsHeld = true;

    // A second shadowed light on every carrier's hip costs more than it shows.
    UPROPERTY()
    bool ShadowsStowed = false;

    UPROPERTY()
    bool ShadowsWorld = true;

    // A low flame burns dimmer: intensity scales from this at empty to 1 at full.
    UPROPERTY()
    float32 EmptyIntensityScale = 0.6f;

    // Flicker: a steady flame wavers a little; a guttering one wavers hard and dips.
    UPROPERTY()
    float32 SteadyFlicker = 0.08f;

    UPROPERTY()
    float32 GutterFlicker = 0.35f;
}

// The brightness the dressing last applied (fuel scale x flicker; 0 while dark), for whatever else glows with the flame.
delegate void FMars_Delegate_FlameDressing_OnBrightness(float32 InBrightness);

// The one drawing of a flame, owned by the entity script that composed it (items and fixtures alike): a point light on the
// flame node reaching the kernel's light radius, and a small unlit teardrop. It follows OnLitChanged and OnConditionChanged
// itself; the owner calls Refresh when the flame's pool may have changed (a mount change). The flicker tick lives on the
// flame entity, so it dies with it; Teardown ends it early.
class UMars_FlameDressing : UObject
{
    private FCk_Handle_Flame _Flame;
    private FMars_FlameLook _Look;
    private UPointLightComponent _Light;
    private UStaticMeshComponent _FlameMesh;
    private FCk_Handle_Timer _FlickerTick;
    private float32 _FlickerClock = 0.0f;
    // The look's intensity for the pool of the last Refresh.
    private float32 _PoolIntensity = 0.0f;
    private FMars_Delegate_FlameDressing_OnBrightness _OnBrightness;

    void Setup(FCk_Handle_Flame InFlame, FCk_Handle_Transform InFlameNode, FMars_FlameLook InLook)
    {
        _Flame = InFlame;
        _Look = InLook;

        auto Node = InFlameNode;
        AddLight(Node);
        AddFlameMesh(Node);

        _Flame.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));
        _Flame.BindTo_OnConditionChanged(FMars_Delegate_Flame_OnConditionChanged(this, n"OnConditionChanged"));
        Refresh();
    }

    // InDelegate hears every brightness the dressing applies, starting with the current one.
    void BindTo_OnBrightness(FMars_Delegate_FlameDressing_OnBrightness InDelegate)
    {
        _OnBrightness = InDelegate;
        Refresh();
    }

    void Teardown()
    {
        DoDestroy_FlickerTick();
        if (ck::IsValid(_Flame))
        {
            _Flame.UnbindFrom_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));
            _Flame.UnbindFrom_OnConditionChanged(FMars_Delegate_Flame_OnConditionChanged(this, n"OnConditionChanged"));
        }

        _Flame = FCk_Handle_Flame();
        _OnBrightness.Clear();
    }

    // Light and flame from the kernel's state now; the flicker tick runs only while lit.
    void Refresh()
    {
        if (ck::Is_NOT_Valid(_Flame))
        { return; }

        const auto IsLit = _Flame.Get_IsLit();
        const auto Pool = _Flame.Get_LightPool();
        _PoolIntensity = Get_Intensity(Pool);

        if (ck::IsValid(_Light))
        {
            _Light.SetVisibility(IsLit);
            if (IsLit)
            {
                _Light.SetAttenuationRadius(_Flame.Get_LightRadius());
                _Light.SetCastShadows(Get_CastsShadows(Pool));
            }
        }

        if (ck::IsValid(_FlameMesh))
        { _FlameMesh.SetVisibility(IsLit); }

        if (IsLit && ck::Is_NOT_Valid(_FlickerTick))
        { _FlickerTick = utils_timer::Create_Tick(_Flame.H(), FCk_Delegate_Timer(this, n"OnFlickerTick")); }
        else if (IsLit == false)
        { DoDestroy_FlickerTick(); }

        Apply_Brightness(IsLit ? 1.0f : 0.0f);
    }

    private void AddLight(FCk_Handle_Transform& InNode)
    {
        auto Archetype = Cast<UPointLightComponent>(NewObject(this, UPointLightComponent));
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetLightColor(_Look.Color);
        Archetype.SetIntensity(_Look.IntensityHeld);
        Archetype.SetSourceRadius(_Look.SourceRadius);
        Archetype.SetCastShadows(_Look.ShadowsHeld);
        Archetype.SetVisibility(false);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Flame_Light");
        auto Light = utils_unreal_component::Add(InNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Light, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded"));
    }

    // A small unlit teardrop; it never shadows the light inside it.
    private void AddFlameMesh(FCk_Handle_Transform& InNode)
    {
        auto Part = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(0.035, 0.035, 0.07)),
            engine::load::Sphere(), assets::load::CandleFlame_Mars_MI(), collision::profile::NoCollision, n"Flame_FlameMesh");
        Part.CastShadow = false;

        auto FlameMesh = InNode.Add_MeshPart(this, Part);
        if (ck::IsValid(FlameMesh))
        { utils_unreal_component::BindTo_OnAdded(FlameMesh, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFlameMeshAdded")); }
    }

    private float32 Get_Intensity(EMars_Flame_Pool InPool) const
    {
        switch (InPool)
        {
            case EMars_Flame_Pool::Held: return _Look.IntensityHeld;
            case EMars_Flame_Pool::Stowed: return _Look.IntensityStowed;
            default: return _Look.IntensityWorld;
        }
    }

    private bool Get_CastsShadows(EMars_Flame_Pool InPool) const
    {
        switch (InPool)
        {
            case EMars_Flame_Pool::Held: return _Look.ShadowsHeld;
            case EMars_Flame_Pool::Stowed: return _Look.ShadowsStowed;
            default: return _Look.ShadowsWorld;
        }
    }

    private void DoDestroy_FlickerTick()
    {
        if (ck::Is_NOT_Valid(_FlickerTick))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_FlickerTick.H());
        _FlickerTick = FCk_Handle_Timer();
    }

    // InWaver multiplies the fuel-scaled brightness; 0 darkens the light and whatever glows with it.
    private void Apply_Brightness(float32 InWaver)
    {
        const auto FuelScale = Math::Lerp(_Look.EmptyIntensityScale, 1.0f, _Flame.Get_FuelFraction());
        const auto Brightness = FuelScale * InWaver;

        if (ck::IsValid(_Light))
        { _Light.SetIntensity(_PoolIntensity * Brightness); }

        _OnBrightness.ExecuteIfBound(Brightness);
    }

    // Two incommensurate waves for a steady flame; a guttering one adds a hard, slow dip toward dark.
    private float32 Get_Waver(float32 InClock, EMars_Flame_Condition InCondition) const
    {
        const auto IsGuttering = InCondition == EMars_Flame_Condition::Guttering;
        const auto Amplitude = IsGuttering ? _Look.GutterFlicker : _Look.SteadyFlicker;
        const auto Wave = 0.6f * Math::Sin(InClock * 13.1f) + 0.4f * Math::Sin(InClock * 23.7f + 1.3f);
        auto Waver = 1.0f + Amplitude * Wave;
        if (IsGuttering)
        { Waver *= 1.0f - 0.7f * Math::Pow(Math::Max(0.0f, Math::Sin(InClock * 2.3f)), 8.0f); }

        return Math::Max(Waver, 0.05f);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLightAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Light = Cast<UPointLightComponent>(utils_unreal_component::Get_Component(InHandle));
        ck::EnsureIfNot(ck::IsValid(_Light), f"[Flame] [{_Flame.ToString()}] got no UPointLightComponent for its light");
        Refresh();
    }

    UFUNCTION()
    private void OnFlameMeshAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _FlameMesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::IsValid(_FlameMesh) && ck::IsValid(_Flame))
        { _FlameMesh.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Flame.H())); }

        Refresh();
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        Refresh();
    }

    UFUNCTION()
    private void OnConditionChanged(FCk_Handle_Flame InFlame, EMars_Flame_Condition InCondition)
    {
        Refresh();
    }

    UFUNCTION()
    private void OnFlickerTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Flame))
        { return; }

        _FlickerClock += float32(InDeltaT.Get_Seconds());
        Apply_Brightness(Get_Waver(_FlickerClock, _Flame.Get_Condition()));
    }
}
