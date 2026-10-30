// How a flame looks: its light's colour and strength by pool (the belt knob is IntensityStowed), its shadows by pool, its
// flicker, and the flame card and effect (Flame_Mars_NS) scaled for it.
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

    // The flame's height in cm (torch 18, lantern 10, brazier 45): the card's height and the effect's Size. 0 draws no
    // card and no effect: a fixture whose mesh bakes its own flame (the candle) shows that one, driven dark through custom
    // primitive data 1 (Set_BakedFlame).
    UPROPERTY()
    float32 FxSize = 18.0f;

    // Embers per second off the top of the flame; none behind glass.
    UPROPERTY()
    float32 FxEmberRate = 6.0f;

    // Behind glass: the card bends less, the embers stay in.
    UPROPERTY()
    bool FxEnclosed = false;
}

// The one flame drawing: a card (FlameCard_Mars_M on the engine Plane, Tools/Blender/mars_environment/unreal/mars_flame_ue.py,
// contract in FLAME_FX.md beside it) whose base is pinned at the flame node and whose tip the dressing bends by the
// carrier's motion through custom primitive data, plus Flame_Mars_NS (mars_flame_niagara.py) for the embers and the glow,
// driven by the user parameters named here.
namespace constants_flame_fx
{
    const FString k_SystemPath = "/Game/Mars/Fx/Flame/Flame_Mars_NS.Flame_Mars_NS";
    const FString k_CardMaterialPath = "/Game/Mars/Fx/Flame/Materials/FlameCard_Mars_MI.FlameCard_Mars_MI";
    // A strip with rows along its height (mars_flame_ue.build_card_mesh): the engine Plane has four vertices, which the
    // card's curl and ripple cannot bend. The Plane stands in only if the strip is missing.
    const FString k_CardMeshPath = "/Game/Mars/Fx/Flame/Meshes/FlameCard_Mars_SM.FlameCard_Mars_SM";

    // Niagara user parameters. Size: the flame height, cm. Intensity: 0..1, the kernel's brightness (fuel scale x flicker),
    // 0 dark. EmberRate: per second. Wind: world cm/s the embers drift with (the carrier's velocity, negated). Enclosed: 0 / 1.
    const FName k_Size = n"Size";
    const FName k_Intensity = n"Intensity";
    const FName k_Colour = n"Colour";
    const FName k_EmberRate = n"EmberRate";
    const FName k_Wind = n"Wind";
    const FName k_Enclosed = n"Enclosed";

    // The card's custom primitive data: 0 this flame's random phase, 1 Intensity (0..1), 2-4 Lean (world cm the tip is
    // pushed), 5 enclosed (1 caps the bend inside the glass), 6 height and 7 width (cm: the vertex shader builds the card
    // from these; the Plane's own scale only sizes its bounds).
    const int32 k_CardCpd_Phase = 0;
    const int32 k_CardCpd_Intensity = 1;
    const int32 k_CardCpd_Lean = 2;
    const int32 k_CardCpd_Height = 6;
    const int32 k_CardCpd_Width = 7;
    // The card is this wide for its height: wider than the flame (about 0.4 H), so the warped, eroded edge never reaches
    // the quad's border.
    const float32 k_CardWidthPerHeight = 0.9f;
    // The card stands wholly above its component (the plane's bounds are centred on it) and bends past them (its tip leans
    // up to 1.2 H out, it stretches): the bounds are scaled to keep it drawn.
    const float32 k_CardBoundsScale = 3.0f;
    // Lean: cm of tip push per cm/s of carrier speed, negative = against the motion (the flame trails the carrier, the
    // shader caps it at 0.45 H and swings the flame rather than stretching it); positive would make it lead. A walk
    // (420 cm/s) pushes the tip about 13 cm, a little over a torch's cap.
    const float32 k_LeanPerCmPerS = -0.03f;
    // The lean rides an underdamped spring toward that target, so it swings past and wobbles back when the carrier starts,
    // stops or turns, instead of sliding linearly into place.
    const float32 k_LeanSpringHz = 2.2f;
    const float32 k_LeanSpringDamping = 0.3f;

    // The flame node's speed is clamped to this before it leans the card or drifts the embers: a mount change is a step,
    // not a gale.
    const float32 k_WindMaxCmPerS = 400.0f;

    // Custom primitive data slot of CandleFlame_Mars_M's Intensity Offset (-1 puts a baked flame out).
    const int32 k_BakedFlameCpd = 1;
}

// `Mars.Flame.DebugLean 1`: every lit flame prints its node speed, its lean and whether its card exists, once a second.
const FConsoleVariable CVar_Mars_FlameDebugLean("Mars.Flame.DebugLean", 0);

// The brightness the dressing last applied (fuel scale x flicker; 0 while dark), for whatever else glows with the flame.
delegate void FMars_Delegate_FlameDressing_OnBrightness(float32 InBrightness);

// The one drawing of a flame, owned by the entity script that composed it (items and fixtures alike): a point light mid-flame
// over the flame node reaching the kernel's light radius, one flame card on the node, and the embers and glow effect on it
// (or a mesh's baked flame instead of both). It follows OnLitChanged and OnConditionChanged itself; the owner calls Refresh
// when the flame's pool may have changed (a mount change). The flicker tick lives on the flame entity, so it dies with it;
// Teardown ends it early. Everything rendered is guarded by FApp::CanEverRender(): a headless lane gets the light handle
// and nothing else.
class UMars_FlameDressing : UObject
{
    private FCk_Handle_Flame _Flame;
    private FCk_Handle_Transform _FlameNode;
    private FMars_FlameLook _Look;
    private UPointLightComponent _Light;
    // The flame card, visible while lit; its material reads the custom primitive data the dressing writes.
    private UStaticMeshComponent _Card;
    // Flame_Mars_NS (embers, glow) on the flame node; runs only while lit.
    private UNiagaraComponent _Fx;
    private bool _FxActive = false;
    // A mesh whose material bakes the flame (CandleFlame_Mars_M): custom primitive data 1 follows the brightness.
    private UStaticMeshComponent _BakedFlame;
    private FCk_Handle_Timer _FlickerTick;
    private float32 _FlickerClock = 0.0f;
    // The flame node's last world location while lit, for the lean and the wind; unset on the first tick after a light.
    // The last position the lean measured from, and when (game seconds); unset on the first tick after a light.
    private bool _HasPrevSample = false;
    private FVector _PrevSampleLocation = FVector::ZeroVector;
    private float64 _PrevSampleTime = 0.0;
    private FVector _LastVelocity = FVector::ZeroVector;
    private int32 _DebugTicks = 0;
    private float32 _DebugStepCm = 0.0f;
    // Where the card's tip is pushed (world cm), smoothed from the node's motion.
    private FVector _Lean = FVector::ZeroVector;
    private FVector _LeanVelocity = FVector::ZeroVector;
    private float32 _DebugClock = 0.0f;
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
        {
            AddFlameCard(Node);
            AddFlameFx(Node);
        }

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

        // The hosted components die with their nodes.
        _Fx = nullptr;
        _Card = nullptr;
        _FxActive = false;
        _Flame = FCk_Handle_Flame();
        _OnBrightness.Clear();
    }

    // Light, card and effect from the kernel's state now; the flicker tick runs only while lit.
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

        if (ck::IsValid(_Card))
        { _Card.SetVisibility(IsLit); }

        Set_FxActive(IsLit);

        if (IsLit && ck::Is_NOT_Valid(_FlickerTick))
        { _FlickerTick = utils_timer::Create_Tick(_Flame.H(), FCk_Delegate_Timer(this, n"OnFlickerTick")); }
        else if (IsLit == false)
        { DoDestroy_FlickerTick(); }

        Apply_Brightness(IsLit ? 1.0f : 0.0f);
    }

    // The light sits mid-flame, half the flame height over the flame node on a node of its own: inside the mesh of a big
    // fire (the brazier's coals and tongues) a light at the root reads as a sphere cut by geometry and leaks through it.
    // A flame without a card (FxSize 0, the candle) keeps its light at the node.
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

    // The flame card: the engine Plane (100 cm, pivot at its centre) rolled upright so its local Y is up, scaled to the
    // flame's width and height, AT the node: its vertex shader builds the flame upward from the component's own origin
    // (a billboard about the vertical axis whatever the node's rotation) and bends its tip by the Lean the dressing
    // writes, so the component must sit exactly where the flame's foot is; the scaled bounds cover the flame above it.
    // Its material instance carries the look's colour.
    private void AddFlameCard(FCk_Handle_Transform& InNode)
    {
        auto Material = System::LoadAsset_Blocking(TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath(constants_flame_fx::k_CardMaterialPath)));
        if (ck::Is_NOT_Valid(Material))
        { return; }

        UStaticMesh Mesh = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(constants_flame_fx::k_CardMeshPath)));
        if (ck::Is_NOT_Valid(Mesh))
        { Mesh = engine::load::Plane(); }

        const auto Height = float64(_Look.FxSize);
        const auto Width = Height * constants_flame_fx::k_CardWidthPerHeight;
        auto Part = FMars_MeshPart(
            FTransform(FRotator(0.0, 0.0, 90.0), FVector::ZeroVector, FVector(Width * 0.01, Height * 0.01, 1.0)),
            Mesh, Material, collision::profile::NoCollision, n"Flame_Card");
        Part.CastShadow = false;
        Part.ReceivesDecals = false;

        auto Card = InNode.Add_MeshPart(this, Part);
        if (ck::IsValid(Card))
        { utils_unreal_component::BindTo_OnAdded(Card, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnCardAdded")); }
    }

    // Flame_Mars_NS as an archetype component on the flame node, created inactive (Activate(true) resets the system, so it
    // runs only on an off -> on edge). Without the asset the card burns alone.
    private void AddFlameFx(FCk_Handle_Transform& InNode)
    {
        auto System = System::LoadAsset_Blocking(TSoftObjectPtr<UNiagaraSystem>(FSoftObjectPath(constants_flame_fx::k_SystemPath)));
        if (ck::Is_NOT_Valid(System))
        { return; }

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

    // The card's constant data: its colour (the instance's "Colour") and its own phase; the lean starts at rest.
    private void Apply_CardParameters(UStaticMeshComponent InCard)
    {
        auto Material = InCard.CreateDynamicMaterialInstance(0);
        if (ck::IsValid(Material))
        { Material.SetVectorParameterValue(n"Colour", _Look.Color); }

        InCard.SetBoundsScale(constants_flame_fx::k_CardBoundsScale);
        InCard.SetCustomPrimitiveDataFloat(constants_flame_fx::k_CardCpd_Phase, Math::RandRange(0.0f, 1.0f));
        InCard.SetCustomPrimitiveDataFloat(constants_flame_fx::k_CardCpd_Height, _Look.FxSize);
        InCard.SetCustomPrimitiveDataFloat(constants_flame_fx::k_CardCpd_Width, _Look.FxSize * constants_flame_fx::k_CardWidthPerHeight);
        Write_Lean(FVector::ZeroVector);
    }

    private void Write_Lean(FVector InLean)
    {
        if (ck::Is_NOT_Valid(_Card))
        { return; }

        const auto Enclosed = _Look.FxEnclosed ? 1.0f : 0.0f;
        _Card.SetCustomPrimitiveDataVector4(constants_flame_fx::k_CardCpd_Lean, FVector4(InLean.X, InLean.Y, InLean.Z, Enclosed));
    }

    // Runs the effect on an off -> on edge and stops it on the other.
    private void Set_FxActive(bool InActive)
    {
        if (ck::Is_NOT_Valid(_Fx) || InActive == _FxActive)
        { return; }

        _FxActive = InActive;
        if (InActive)
        { _Fx.Activate(true); }
        else
        { _Fx.Deactivate(); }
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
        _HasPrevSample = false;
        _LastVelocity = FVector::ZeroVector;
        _Lean = FVector::ZeroVector;
        _LeanVelocity = FVector::ZeroVector;
        Write_Lean(_Lean);
        if (ck::Is_NOT_Valid(_FlickerTick))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_FlickerTick.H());
        _FlickerTick = FCk_Handle_Timer();
    }

    // InWaver multiplies the fuel-scaled brightness; 0 darkens the light, the card, the effect, a baked flame and whatever
    // glows with it.
    private void Apply_Brightness(float32 InWaver)
    {
        const auto FuelScale = Math::Lerp(_Look.EmptyIntensityScale, 1.0f, _Flame.Get_FuelFraction());
        const auto Brightness = FuelScale * InWaver;

        if (ck::IsValid(_Light))
        { _Light.SetIntensity(_PoolIntensity * Brightness); }

        if (ck::IsValid(_Card))
        { _Card.SetCustomPrimitiveDataFloat(constants_flame_fx::k_CardCpd_Intensity, Brightness); }

        if (ck::IsValid(_Fx) && _FxActive)
        { _Fx.SetVariableFloat(constants_flame_fx::k_Intensity, Brightness); }

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

    // The flame inherits the carrier's motion: the card's tip is pushed against the node's velocity (smoothed, so it leans
    // into a run and rights itself after a stop) and the embers drift with the same wind.
    // Velocity is measured against game time between samples, not against the tick's delta: a tick that sees the same
    // clock (a second call in one frame) or the same position (a transform not yet pushed this frame) is skipped, so the
    // next real step is measured over the time it actually took.
    private void Apply_Motion(FVector InNodeLocation, float32 InDeltaSeconds)
    {
        ++_DebugTicks;
        const auto Now = System::GetGameTimeInSeconds();
        if (_HasPrevSample == false)
        {
            _PrevSampleLocation = InNodeLocation;
            _PrevSampleTime = Now;
            _HasPrevSample = true;
            return;
        }

        const auto Elapsed = float32(Now - _PrevSampleTime);
        const auto Step = InNodeLocation - _PrevSampleLocation;
        auto Velocity = _LastVelocity;
        if (Elapsed > 1e-4f && Step.SizeSquared() > 1e-6)
        {
            Velocity = Step / Elapsed;
            if (Velocity.Size() > constants_flame_fx::k_WindMaxCmPerS)
            { Velocity = Velocity.GetSafeNormal() * constants_flame_fx::k_WindMaxCmPerS; }

            _PrevSampleLocation = InNodeLocation;
            _PrevSampleTime = Now;
            _DebugStepCm = float32(Step.Size());
        }
        else if (Elapsed > 0.1f)
        {
            // standing still for a tenth of a second: at rest
            Velocity = FVector::ZeroVector;
            _PrevSampleTime = Now;
        }

        _LastVelocity = Velocity;
        Advance_LeanSpring(Velocity * constants_flame_fx::k_LeanPerCmPerS, InDeltaSeconds);
        Write_Lean(_Lean);
        Print_DebugLean(Velocity, InDeltaSeconds);

        if (ck::IsValid(_Fx) && _FxActive)
        { _Fx.SetVariableVec3(constants_flame_fx::k_Wind, -Velocity); }
    }

    // A damped spring from the lean toward InTarget (semi-implicit Euler in steps of at most 1/60 s, so a long frame
    // cannot blow it up).
    private void Advance_LeanSpring(FVector InTarget, float32 InDeltaSeconds)
    {
        const auto Omega = 2.0f * PI * constants_flame_fx::k_LeanSpringHz;
        auto Remaining = Math::Min(InDeltaSeconds, 0.1f);
        while (Remaining > 0.0f)
        {
            const auto Step = Math::Min(Remaining, 1.0f / 60.0f);
            const auto Acceleration = (InTarget - _Lean) * (Omega * Omega) - _LeanVelocity * (2.0f * constants_flame_fx::k_LeanSpringDamping * Omega);
            _LeanVelocity = _LeanVelocity + Acceleration * Step;
            _Lean = _Lean + _LeanVelocity * Step;
            Remaining -= Step;
        }
    }

    // Once a second while Mars.Flame.DebugLean is on.
    private void Print_DebugLean(FVector InVelocity, float32 InDeltaSeconds)
    {
        if (CVar_Mars_FlameDebugLean.GetInt() == 0)
        { return; }

        _DebugClock += InDeltaSeconds;
        if (_DebugClock < 1.0f)
        { return; }

        _DebugClock = 0.0f;
        const auto NodeLocation = ck::IsValid(_FlameNode) ? utils_transform::Get_EntityCurrentTransform(_FlameNode).GetLocation() : FVector::ZeroVector;
        const auto CardLocation = ck::IsValid(_Card) ? _Card.GetWorldLocation() : FVector::ZeroVector;
        Print(f"[Flame] [{_Flame.ToString()}] ticks/s [{_DebugTicks}] last step [{_DebugStepCm :.2}] cm dt [{InDeltaSeconds :.4}] speed [{InVelocity.Size() :.0}] cm/s lean [{_Lean}] node [{NodeLocation}] card at [{CardLocation}] card [{ck::IsValid(_Card)}] fx [{ck::IsValid(_Fx)}]", 1.0f);
        _DebugTicks = 0;
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
    private void OnCardAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Card = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Card), f"[Flame] [{_Flame.ToString()}] got no UStaticMeshComponent for its card"))
        { return; }

        if (ck::IsValid(_Flame))
        { _Card.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Flame.H())); }

        Apply_CardParameters(_Card);
        Refresh();
    }

    UFUNCTION()
    private void OnFxAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Fx = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Fx), f"[Flame] [{_Flame.ToString()}] got no UNiagaraComponent for its effect"))
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

        // The card's own rendered position is the motion source (it is what moves on screen); the node's entity transform
        // only when there is no card.
        if (ck::IsValid(_Card))
        { Apply_Motion(_Card.GetWorldLocation(), DeltaSeconds); }
        else if (ck::IsValid(_FlameNode) && ck::IsValid(_Fx))
        { Apply_Motion(utils_transform::Get_EntityCurrentTransform(_FlameNode).GetLocation(), DeltaSeconds); }

        Apply_Brightness(Get_Waver(_FlickerClock, _Flame.Get_Condition()));
    }
}
