// Room 5 presets (the crawler room; Mars.Sandbox.BuildRoom5 in Script/Editor/Mars_SandboxMapBuilder.as places them).
// Not under Script/Editor: the saved map references them at runtime.

// The melee items, World-mode WorldItem presets like the room-1 rocks.
class UMars_Sandbox_Cleaver_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Cleaver();
}

class UMars_Sandbox_Tenderizer_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Tenderizer();
}

// The Room 5 crawlers: armed but passive until the Room 5 aggression lever powers their sink (channel
// Mechanism.Channel.Room5Aggression), then they hunt the player and strike with the rearing pincer (the body rears up
// with both front legs thrown high, then lunges as they slam down; the mouth's fangs flare and snap with it); pulling the
// lever back calms them. The spec and the sink are set in DoConstruct, not as subclass defaults: the spawn-params
// generator emits a non-default struct default as a positional constructor call. RoamBounds is Room 5 inset by 150 uu.
UCLASS(Abstract)
class UMars_Sandbox_Crawler_EntityScript : UMars_Crawler_EntityScript
{
    default _ShowInPlaceActors = false;

    private FMars_MechanismSink_Spec _Sink;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Spec.LegCount = Get_PresetLegCount();
        Spec.Layout = Get_PresetLayout();
        Spec.MinLegsToWalk = 3;
        Color = Get_PresetColor();
        Look = Get_PresetLook();
        Spec.RoamBounds = FBox(FVector(-3850.0, -550.0, 0.0), FVector(-2150.0, 550.0, 200.0));
        // Authored for the radial box crawler; another layout's rig and size get it refitted.
        Spec.Combat = utils_crawler::Fit_CombatToLayout(utils_crawler::Make_RearingPincerCombat(), Spec.Layout, Spec.LegCount);
        Spec.Combat.StartAggressive = ECk_EnableDisable::Disable;
        _Sink.InputChannels.Empty();
        _Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Room5Aggression"));

        const auto Flow = Super::DoConstruct(InHandle);
        ComposeAggressionSink(InHandle);
        return Flow;
    }

    // Only on a crawler that composed armed: a rejected spec has no crawler, and outside a local combat world the crawler
    // is unarmed and would refuse the aggression request.
    private void ComposeAggressionSink(FCk_Handle& InHandle)
    {
        const auto Crawler = InHandle.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Crawler) || Crawler.Get_IsCombatArmed() == false)
        { return; }

        auto SinkHandle = utils_mechanism_sink::Add(InHandle, _Sink);
        if (ck::IsValid(SinkHandle))
        { SinkHandle.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnAggressionSinkPoweredChanged")); }
    }

    UFUNCTION()
    private void OnAggressionSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        FCk_Handle Entity = InSink;
        auto Crawler = Entity.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Crawler))
        { return; }

        const auto Aggression = InPower == EMars_MechanismSink_Power::Powered ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(Aggression));
    }

    protected int32 Get_PresetLegCount() const
    { return 4; }

    protected FLinearColor Get_PresetColor() const
    { return FLinearColor(0.75f, 0.35f, 0.2f, 1.0f); }

    protected EMars_Crawler_Layout Get_PresetLayout() const
    { return EMars_Crawler_Layout::Radial; }

    // Empty: the boxes.
    protected FMars_Crawler_Look Get_PresetLook() const
    { return FMars_Crawler_Look(); }
}

class UMars_Sandbox_Crawler4_EntityScript : UMars_Sandbox_Crawler_EntityScript
{
}

class UMars_Sandbox_Crawler6_EntityScript : UMars_Sandbox_Crawler_EntityScript
{
    protected int32 Get_PresetLegCount() const override
    { return 6; }

    protected FLinearColor Get_PresetColor() const override
    { return FLinearColor(0.35f, 0.55f, 0.2f, 1.0f); }

    // The spider: its measured rig and the pieces cut from the same model (Tools/Blender/mars_monsters/
    // build_crawler_pieces.py); their slot carries Crawler_Mars_MI.
    protected EMars_Crawler_Layout Get_PresetLayout() const override
    { return EMars_Crawler_Layout::Spider; }

    protected FMars_Crawler_Look Get_PresetLook() const override
    {
        auto Pieces = FMars_Crawler_Look();
        Pieces.Body = Get_SpiderMesh("Body");
        // Rig order: front, mid and back on the right, then back, mid and front on the left; a left leg wears its right
        // twin's pieces.
        auto Pairs = TArray<FString>();
        Pairs.Add("Front");
        Pairs.Add("Mid");
        Pairs.Add("Back");
        Pairs.Add("Back");
        Pairs.Add("Mid");
        Pairs.Add("Front");
        for (const auto& Pair : Pairs)
        { Pieces.Legs.Add(FMars_Crawler_LegLook(Get_SpiderMesh(f"LegUpper{Pair}"), Get_SpiderMesh(f"LegLower{Pair}"))); }

        Pieces.Foot = Get_SpiderMesh("Foot");
        Pieces.Fang = Get_SpiderMesh("Fang");
        Pieces.FangRoot = FVector(87.4, 16.39, -28.95);
        return Pieces;
    }

    private TSoftObjectPtr<UStaticMesh> Get_SpiderMesh(FString InPart) const
    {
        const FString Name = f"Crawler_{InPart}_Mars_SM";
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(f"/Game/Mars/Gameplay/Monsters/Crawler/Meshes/{Name}.{Name}"));
    }
}

// The Room 5 aggression lever on the west wall: an instant toggle asserting Mechanism.Channel.Room5Aggression while
// thrown, which the Room 5 crawlers' sinks turn into Request_SetAggression. The behaviour is set in DoConstruct for the
// same spawn-params reason as the crawlers' spec.
class UMars_Sandbox_AggressionLever_EntityScript : UMars_Lever_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Room5Aggression");
    default PromptText = NSLOCTEXT("MarsInteraction", "RouseCrawlersPrompt", "Rouse the crawlers");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Control.Behavior = EMars_Control_Behavior::Toggle;
        return Super::DoConstruct(InHandle);
    }
}

// The Room 5 ground-nav field: the framework's placeable volume script with Room 5's bake settings. The bounds are
// local to the spawner's translation (rotation and scale are ignored): placed at (-3000, 0, 0) they cover the room,
// X -4000..-2000, Y -700..700, Z -100..400. The spec is a class default because the volume's C++ Construct reads it
// before any script hook runs.
class UMars_Sandbox_NavField_EntityScript : UCk_GroundNavVolume_EntityScript
{
    default _Params = utils_surface_navigator::Make_NavFieldSpec(FBox(FVector(-1000.0, -700.0, -100.0), FVector(1000.0, 700.0, 400.0)));
}
