// The lantern's assembly: a World-mode, Persistent world item whose definition carries UMars_ItemTrait_Lantern. It composes
// the Lantern kernel from the trait's Spec, then draws what the kernel decides: a point light reaching the kernel's light
// radius, the flame, and the glass glow (the mesh's Glow slot), following the item from the floor to the hand to a hook.
// Stowed in a hotbar slot that is not selected it is hidden altogether (the kernel's Stowed pool: dark and not burning).
// The kernel owns the fuel clock; this script owns only the flicker.
namespace constants_lantern_light
{
    // Mars_TestLamp's colour.
    const FLinearColor k_Color = FLinearColor(1.0f, 0.67f, 0.35f, 1.0f);
}

class UMars_Lantern_EntityScript : UMars_WorldItem_EntityScript
{
    // CampLantern_Mars_SM's glass slot (Glow_Mars_MI: Emissive "Color" x "Strength").
    private const int32 k_GlassSlot = 1;
    private const FName k_GlassStrengthParameter = n"Strength";
    private const float32 k_GlassStrength = 8.0f;

    // The flame's height over the lantern's pivot (its base), at the item's MeshScale.
    private const float64 k_FlameHeight = 14.0;

    // Mars_TestLamp's intensity, which the sandbox has been lit by.
    private const float32 k_Intensity = 8000.0f;
    private const float32 k_SourceRadius = 2.0f;
    // A low flame burns dimmer: intensity scales from this at empty to 1 at full.
    private const float32 k_EmptyIntensityScale = 0.6f;

    // Flicker: a steady flame wavers a little; a guttering one wavers hard and dips.
    private const float32 k_SteadyFlicker = 0.08f;
    private const float32 k_GutterFlicker = 0.35f;

    private FCk_Handle_Lantern _Lantern;
    private UPointLightComponent _Light;
    private UStaticMeshComponent _FlameMesh;
    private UStaticMeshComponent _Body;
    private UMaterialInstanceDynamic _Glass;
    private FCk_Handle_Timer _FlickerTick;
    private float32 _FlickerClock = 0.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // Super destroyed itself (bad definition) - nothing to compose on.
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(WorldItem))
        { return Flow; }

        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Lantern LanternTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Lantern);
        const auto IsPersistent = WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        const auto IsLantern = Mode == EMars_WorldItem_Mode::World && IsPersistent && ck::IsValid(LanternTrait);
        if (ck::EnsureIfNot(IsLantern,
            f"[Lantern] [{InHandle.ToString()}] needs World mode and a Persistent definition with a Lantern trait (mode [{Mode :n}], persistent [{IsPersistent}], lantern trait [{ck::IsValid(LanternTrait)}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        // A rejected spec already ensured in utils_lantern::Add; the lantern then stays dark.
        _Lantern = utils_lantern::Add(InHandle, LanternTrait.Spec);
        if (ck::Is_NOT_Valid(_Lantern))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Root = InHandle.As_Transform();
        auto FlameNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, k_FlameHeight))).As_Transform();
        utils_handle::Set_DebugName(FlameNode.H(), n"Lantern.Flame");
        AddLight(FlameNode);
        AddFlame(FlameNode);

        _Lantern.BindTo_OnLitChanged(FMars_Delegate_Lantern_OnLitChanged(this, n"OnLitChanged"));
        _Lantern.BindTo_OnFlameChanged(FMars_Delegate_Lantern_OnFlameChanged(this, n"OnFlameChanged"));
        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_Light"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddLight(FCk_Handle_Transform& InNode)
    {
        auto Archetype = Cast<UPointLightComponent>(NewObject(this, UPointLightComponent));
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetLightColor(constants_lantern_light::k_Color);
        Archetype.SetIntensity(k_Intensity);
        Archetype.SetSourceRadius(k_SourceRadius);
        Archetype.SetCastShadows(true);
        Archetype.SetVisibility(false);

        auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Lantern_Light");
        auto Light = utils_unreal_component::Add(InNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Light, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLightAdded"));
    }

    // A small unlit teardrop; it never shadows the light inside it.
    private void AddFlame(FCk_Handle_Transform& InNode)
    {
        auto Part = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(0.035, 0.035, 0.07)),
            engine::load::Sphere(), assets::load::CandleFlame_Mars_MI(), collision::profile::NoCollision, n"Lantern_FlameMesh");
        Part.CastShadow = false;

        auto Flame = InNode.Add_MeshPart(this, Part);
        if (ck::IsValid(Flame))
        { utils_unreal_component::BindTo_OnAdded(Flame, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnFlameAdded")); }
    }

    // The lantern's own body never shadows its flame; its glass glows only while it is lit.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        _Body = InMesh;
        InMesh.SetCastShadow(false);
        if (InMesh.GetNumMaterials() > k_GlassSlot)
        { _Glass = InMesh.CreateDynamicMaterialInstance(k_GlassSlot); }

        Refresh();
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Presentation
    //--------------------------------------------------------------------------------------------------------------------------

    // Light, flame and glass from the kernel's state now, the body hidden while stowed; the flicker tick runs only while
    // it is lit.
    private void Refresh()
    {
        if (ck::Is_NOT_Valid(_Lantern))
        { return; }

        if (ck::IsValid(_Body))
        { _Body.SetVisibility(_Lantern.Get_IsStowed() == false); }

        const auto IsLit = _Lantern.Get_IsLit();
        if (ck::IsValid(_Light))
        {
            _Light.SetVisibility(IsLit);
            if (IsLit)
            { _Light.SetAttenuationRadius(_Lantern.Get_LightRadius()); }
        }

        if (ck::IsValid(_FlameMesh))
        { _FlameMesh.SetVisibility(IsLit); }

        if (IsLit && ck::Is_NOT_Valid(_FlickerTick))
        { _FlickerTick = utils_timer::Create_Tick(_Lantern.H(), FCk_Delegate_Timer(this, n"OnFlickerTick")); }
        else if (IsLit == false && ck::IsValid(_FlickerTick))
        {
            utils_entity_lifetime::Request_DestroyEntity(_FlickerTick.H());
            _FlickerTick = FCk_Handle_Timer();
        }

        Apply_Brightness(IsLit ? 1.0f : 0.0f);
    }

    // InWaver multiplies the fuel-scaled brightness of the light and the glass; 0 darkens both.
    private void Apply_Brightness(float32 InWaver)
    {
        const auto FuelScale = Math::Lerp(k_EmptyIntensityScale, 1.0f, _Lantern.Get_FuelFraction());
        const auto Brightness = FuelScale * InWaver;

        if (ck::IsValid(_Light))
        { _Light.SetIntensity(k_Intensity * Brightness); }

        if (ck::IsValid(_Glass))
        { _Glass.SetScalarParameterValue(k_GlassStrengthParameter, k_GlassStrength * Brightness); }
    }

    // Two incommensurate waves for a steady flame; a guttering one adds a hard, slow dip toward dark.
    private float32 Get_Waver(float32 InClock, EMars_Lantern_Flame InFlame) const
    {
        const auto IsGuttering = InFlame == EMars_Lantern_Flame::Guttering;
        const auto Amplitude = IsGuttering ? k_GutterFlicker : k_SteadyFlicker;
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
        ck::EnsureIfNot(ck::IsValid(_Light), f"[Lantern] [{_Lantern.ToString()}] got no UPointLightComponent for its light");
        Refresh();
    }

    UFUNCTION()
    private void OnFlameAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _FlameMesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::IsValid(_FlameMesh))
        { _FlameMesh.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Lantern.H())); }

        Refresh();
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Lantern InLantern, bool InIsLit)
    {
        Refresh();
    }

    UFUNCTION()
    private void OnFlameChanged(FCk_Handle_Lantern InLantern, EMars_Lantern_Flame InFlame)
    {
        Refresh();
    }

    // The light radius and the body's visibility follow the mount (hand, stowed, world).
    UFUNCTION()
    private void OnMountChanged_Light(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        Refresh();
    }

    UFUNCTION()
    private void OnFlickerTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Lantern))
        { return; }

        _FlickerClock += float32(InDeltaT.Get_Seconds());
        Apply_Brightness(Get_Waver(_FlickerClock, _Lantern.Get_Flame()));
    }
}
