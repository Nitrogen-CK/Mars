// How a flame looks: its light's colour and strength by pool (the belt knob is IntensityStowed), its shadows by pool, its
// flicker, and the Niagara flame (Flame_Mars_NS) scaled for it.
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

    // The Niagara flame's tongue height in cm (torch 18, lantern 10, brazier 45). 0 draws no effect: a fixture whose mesh
    // bakes its own flame (the candle) shows that one, driven dark through custom primitive data 1 (Set_BakedFlame).
    UPROPERTY()
    float32 FxSize = 18.0f;

    // Embers per second off the top of the flame; none behind glass.
    UPROPERTY()
    float32 FxEmberRate = 6.0f;

    // Behind glass: the tongues stay inside the lantern and no embers fly.
    UPROPERTY()
    bool FxEnclosed = false;
}

// The one flame effect, Flame_Mars_NS (Tools/Blender/mars_environment/unreal/mars_flame_niagara.py, contract in FLAME_FX.md
// beside it) and the user parameters the dressing writes. Until the asset exists the dressing falls back to the CkParticles
// Fire and SmokePlume behaviours at the flame node.
namespace constants_flame_fx
{
    const FString k_SystemPath = "/Game/Mars/Fx/Flame/Flame_Mars_NS.Flame_Mars_NS";

    // Tongue height, cm.
    const FName k_Size = n"Size";
    // 0..1, the kernel's brightness (fuel scale x flicker): a gutter dips it, dark is 0.
    const FName k_Intensity = n"Intensity";
    const FName k_Colour = n"Colour";
    // Embers per second.
    const FName k_EmberRate = n"EmberRate";
    // World cm/s the flame streams against (the carrier's velocity, negated).
    const FName k_Wind = n"Wind";
    // 0 open, 1 behind glass.
    const FName k_Enclosed = n"Enclosed";

    // CkParticles placeholders (CkParticles_Behaviors.ush): Fire is a campfire of about this size.
    const int32 k_FireBehavior = 3;
    const int32 k_SmokeBehavior = 12;
    const float32 k_FireBehaviorSizeCm = 45.0f;

    // The flame node's speed is clamped to this before it becomes Wind: a mount change is a step, not a gale.
    const float32 k_WindMaxCmPerS = 400.0f;

    // Custom primitive data slot of CandleFlame_Mars_M's Intensity Offset (-1 puts a baked flame out).
    const int32 k_BakedFlameCpd = 1;
}

// The brightness the dressing last applied (fuel scale x flicker; 0 while dark), for whatever else glows with the flame.
delegate void FMars_Delegate_FlameDressing_OnBrightness(float32 InBrightness);

// The one drawing of a flame, owned by the entity script that composed it (items and fixtures alike): a point light on the
// flame node reaching the kernel's light radius, and the Niagara flame (or a mesh's baked flame) on the same node. It
// follows OnLitChanged and OnConditionChanged itself; the owner calls Refresh when the flame's pool may have changed (a
// mount change). The flicker tick lives on the flame entity, so it dies with it; Teardown ends it early. Everything
// rendered is guarded by FApp::CanEverRender(): a headless lane gets the light handle and nothing else.
class UMars_FlameDressing : UObject
{
    private FCk_Handle_Flame _Flame;
    private FCk_Handle_Transform _FlameNode;
    private FMars_FlameLook _Look;
    private UPointLightComponent _Light;
    // Flame_Mars_NS on the flame node, or the CkParticles Fire placeholder spawned at it (then _FxIsPlaceholder).
    private UNiagaraComponent _Fx;
    private UNiagaraComponent _Smoke;
    private bool _FxIsPlaceholder = false;
    private bool _FxActive = false;
    // A mesh whose material bakes the flame (CandleFlame_Mars_M): custom primitive data 1 follows the brightness.
    private UStaticMeshComponent _BakedFlame;
    private FCk_Handle_Timer _FlickerTick;
    private float32 _FlickerClock = 0.0f;
    // The flame node's last world location while lit, for Wind; unset on the first tick after a light.
    private TOptional<FVector> _LastNodeLocation;
    // The look's intensity for the pool of the last Refresh.
    private float32 _PoolIntensity = 0.0f;
    private FMars_Delegate_FlameDressing_OnBrightness _OnBrightness;

    void Setup(FCk_Handle_Flame InFlame, FCk_Handle_Transform InFlameNode, FMars_FlameLook InLook)
    {
        _Flame = InFlame;
        _FlameNode = InFlameNode;
        _Look = InLook;

        auto Node = InFlameNode;
        AddLight(Node);
        if (FApp::CanEverRender() && _Look.FxSize > 0.0f)
        { AddFlameFx(Node); }

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

    // InPart's mesh bakes a flame on CandleFlame_Mars_M (the candle, the brazier's tongues): its custom primitive data 1
    // follows the brightness, -1 while dark. The part's component may not exist yet; the dressing waits for it.
    void Set_BakedFlame(FCk_Handle_UnrealComponent InPart)
    {
        if (ck::Is_NOT_Valid(InPart))
        { return; }

        utils_unreal_component::BindTo_OnAdded(InPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnBakedFlameAdded"));
    }

    void Teardown()
    {
        DoDestroy_FlickerTick();
        if (ck::IsValid(_Flame))
        {
            _Flame.UnbindFrom_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));
            _Flame.UnbindFrom_OnConditionChanged(FMars_Delegate_Flame_OnConditionChanged(this, n"OnConditionChanged"));
        }

        // A hosted component dies with its node; a placeholder was spawned loose in the world.
        if (_FxIsPlaceholder)
        {
            if (ck::IsValid(_Fx))
            { _Fx.DestroyComponent(); }

            if (ck::IsValid(_Smoke))
            { _Smoke.DestroyComponent(); }
        }

        _Fx = nullptr;
        _Smoke = nullptr;
        _FxActive = false;
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

        Set_FxActive(IsLit);

        if (IsLit && ck::Is_NOT_Valid(_FlickerTick))
        { _FlickerTick = utils_timer::Create_Tick(_Flame.H(), FCk_Delegate_Timer(this, n"OnFlickerTick")); }
        else if (IsLit == false)
        { DoDestroy_FlickerTick(); }

        Apply_Brightness(IsLit ? 1.0f : 0.0f);
    }

    // The light sits mid-flame, half the tongue height over the flame node on a node of its own: inside the mesh of a big
    // fire (the brazier's coals and tongues) a light at the root reads as a sphere cut by geometry and leaks through it.
    // A flame without an effect (FxSize 0, the candle) keeps its light at the node.
    private void AddLight(FCk_Handle_Transform& InNode)
    {
        auto LightNode = utils_scene_node::Create(InNode, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, _Look.FxSize * 0.5))).As_Transform();
        utils_handle::Set_DebugName(LightNode.H(), n"Flame.Light");

        auto Archetype = Cast<UPointLightComponent>(NewObject(this, UPointLightComponent));
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetLightColor(_Look.Color);
        Archetype.SetIntensity(_Look.IntensityHeld);
        Archetype.SetSourceRadius(_Look.SourceRadius);
        Archetype.SetCastShadows(_Look.ShadowsHeld);
        Archetype.SetVisibility(false);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Flame_Light");
        auto Light = utils_unreal_component::Add(LightNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Light, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded"));
    }

    // Flame_Mars_NS as an archetype component on the flame node, created inactive (Activate(true) resets the system, so it
    // runs only on an off -> on edge). Without the asset the CkParticles Fire stands in, spawned at the node once lit.
    private void AddFlameFx(FCk_Handle_Transform& InNode)
    {
        auto System = System::LoadAsset_Blocking(TSoftObjectPtr<UNiagaraSystem>(FSoftObjectPath(constants_flame_fx::k_SystemPath)));
        if (ck::Is_NOT_Valid(System))
        {
            _FxIsPlaceholder = true;
            return;
        }

        auto Archetype = NewObject(this, UNiagaraComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetAsset(System);
        Archetype.SetAutoActivate(false);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Flame_Fx");
        auto Fx = utils_unreal_component::Add(InNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Fx, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFxAdded"));
    }

    // The look's static parameters; Intensity and Wind follow the flame each tick.
    private void Apply_FxParameters(UNiagaraComponent InFx)
    {
        InFx.SetVariableFloat(constants_flame_fx::k_Size, _Look.FxSize);
        InFx.SetVariableFloat(constants_flame_fx::k_EmberRate, _Look.FxEnclosed ? 0.0f : _Look.FxEmberRate);
        InFx.SetVariableFloat(constants_flame_fx::k_Enclosed, _Look.FxEnclosed ? 1.0f : 0.0f);
        InFx.SetVariableLinearColor(constants_flame_fx::k_Colour, _Look.Color);
        InFx.SetVariableVec3(constants_flame_fx::k_Wind, FVector::ZeroVector);
    }

    // The CkParticles stand-ins at the flame node: Fire scaled to FxSize, a smoke plume over an open flame. Nothing until
    // their templates are ready (the flicker tick retries).
    private bool Ensure_Placeholder()
    {
        if (ck::IsValid(_Fx))
        { return true; }

        if (utils_particles::Get_IsBehaviorTemplateReady(constants_flame_fx::k_FireBehavior) == false)
        { return false; }

        const auto Node = utils_transform::Get_EntityCurrentTransform(_FlameNode);
        _Fx = utils_particles::Spawn_BehaviorAtLocation(constants_flame_fx::k_FireBehavior, Node.GetLocation(), FRotator::ZeroRotator);
        if (ck::Is_NOT_Valid(_Fx))
        { return false; }

        if (_Look.FxEnclosed == false && utils_particles::Get_IsBehaviorTemplateReady(constants_flame_fx::k_SmokeBehavior))
        { _Smoke = utils_particles::Spawn_BehaviorAtLocation(constants_flame_fx::k_SmokeBehavior, Node.GetLocation(), FRotator::ZeroRotator); }

        _FxActive = true;
        return true;
    }

    private float32 Get_PlaceholderScale() const
    {
        return _Look.FxSize / constants_flame_fx::k_FireBehaviorSizeCm;
    }

    // Runs the flame effect on an off -> on edge and stops it on the other.
    private void Set_FxActive(bool InActive)
    {
        if (_FxIsPlaceholder)
        {
            if (InActive && Ensure_Placeholder() == false)
            { return; }

            if (ck::Is_NOT_Valid(_Fx) || InActive == _FxActive)
            { return; }

            _FxActive = InActive;
            Set_PlaceholderActive(_Fx, InActive);
            if (ck::IsValid(_Smoke))
            { Set_PlaceholderActive(_Smoke, InActive); }

            return;
        }

        if (ck::Is_NOT_Valid(_Fx) || InActive == _FxActive)
        { return; }

        _FxActive = InActive;
        if (InActive)
        { _Fx.Activate(true); }
        else
        { _Fx.Deactivate(); }
    }

    private void Set_PlaceholderActive(UNiagaraComponent InFx, bool InActive)
    {
        if (InActive)
        { InFx.Activate(true); }
        else
        { InFx.Deactivate(); }
    }

    // The placeholders were spawned loose: they follow the node by hand.
    private void Move_PlaceholderTo(FVector InLocation)
    {
        if (ck::IsValid(_Fx))
        { _Fx.SetWorldLocation(InLocation); }

        if (ck::IsValid(_Smoke))
        { _Smoke.SetWorldLocation(InLocation); }
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
        _LastNodeLocation.Reset();
        if (ck::Is_NOT_Valid(_FlickerTick))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_FlickerTick.H());
        _FlickerTick = FCk_Handle_Timer();
    }

    // InWaver multiplies the fuel-scaled brightness; 0 darkens the light, the effect, a baked flame and whatever glows with
    // it.
    private void Apply_Brightness(float32 InWaver)
    {
        const auto FuelScale = Math::Lerp(_Look.EmptyIntensityScale, 1.0f, _Flame.Get_FuelFraction());
        const auto Brightness = FuelScale * InWaver;

        if (ck::IsValid(_Light))
        { _Light.SetIntensity(_PoolIntensity * Brightness); }

        if (ck::IsValid(_Fx) && _FxActive)
        {
            if (_FxIsPlaceholder)
            { utils_particles::Request_ApplyTuningValues(_Fx, Get_PlaceholderScale(), Brightness, 1.0f, 1.0f); }
            else
            { _Fx.SetVariableFloat(constants_flame_fx::k_Intensity, Brightness); }
        }

        // CandleFlame_Mars_M's Intensity Offset: 0 is the authored flame, -1 is out.
        if (ck::IsValid(_BakedFlame))
        { _BakedFlame.SetCustomPrimitiveDataFloat(constants_flame_fx::k_BakedFlameCpd, Brightness - 1.0f); }

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

    // The flame streams against the node's motion: Wind is the node's velocity negated and capped.
    private void Apply_Wind(FVector InNodeLocation, float32 InDeltaSeconds)
    {
        if (_LastNodeLocation.IsSet() && InDeltaSeconds > 0.0f && ck::IsValid(_Fx) && _FxIsPlaceholder == false)
        {
            auto Wind = (_LastNodeLocation.GetValue() - InNodeLocation) / InDeltaSeconds;
            if (Wind.Size() > constants_flame_fx::k_WindMaxCmPerS)
            { Wind = Wind.GetSafeNormal() * constants_flame_fx::k_WindMaxCmPerS; }

            _Fx.SetVariableVec3(constants_flame_fx::k_Wind, Wind);
        }

        _LastNodeLocation = TOptional<FVector>(InNodeLocation);
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
    private void OnFxAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Fx = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Fx), f"[Flame] [{_Flame.ToString()}] got no UNiagaraComponent for its flame"))
        { return; }

        if (ck::IsValid(_Flame))
        { _Fx.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Flame.H())); }

        Apply_FxParameters(_Fx);
        _Fx.Deactivate();
        _FxActive = false;
        Refresh();
    }

    UFUNCTION()
    private void OnBakedFlameAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _BakedFlame = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
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

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        _FlickerClock += DeltaSeconds;

        // A placeholder that was not ready at the light is spawned here.
        if (_FxIsPlaceholder && ck::Is_NOT_Valid(_Fx))
        { Set_FxActive(true); }

        if (ck::IsValid(_Fx) && ck::IsValid(_FlameNode))
        {
            const auto NodeLocation = utils_transform::Get_EntityCurrentTransform(_FlameNode).GetLocation();
            if (_FxIsPlaceholder)
            { Move_PlaceholderTo(NodeLocation); }
            else
            { Apply_Wind(NodeLocation, DeltaSeconds); }
        }

        Apply_Brightness(Get_Waver(_FlickerClock, _Flame.Get_Condition()));
    }
}
