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

// The Room 5 crawlers. The spec is set in DoConstruct, not as subclass defaults: the spawn-params generator emits a
// non-default struct default as a positional constructor call. RoamBounds is Room 5 inset by 150 uu.
UCLASS(Abstract)
class UMars_Sandbox_Crawler_EntityScript : UMars_Crawler_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Spec.LegCount = Get_PresetLegCount();
        Spec.MinLegsToWalk = 3;
        Color = Get_PresetColor();
        Spec.RoamBounds = FBox(FVector(-3850.0, -550.0, 0.0), FVector(-2150.0, 550.0, 200.0));
        return Super::DoConstruct(InHandle);
    }

    protected int32 Get_PresetLegCount() const
    { return 4; }

    protected FLinearColor Get_PresetColor() const
    { return FLinearColor(0.75f, 0.35f, 0.2f, 1.0f); }
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
}

// The Room 5 ground-nav field: the framework's placeable volume script with Room 5's bake settings. The bounds are
// local to the spawner's translation (rotation and scale are ignored): placed at (-3000, 0, 0) they cover the room,
// X -4000..-2000, Y -700..700, Z -100..400. The spec is a class default because the volume's C++ Construct reads it
// before any script hook runs.
class UMars_Sandbox_NavField_EntityScript : UCk_GroundNavVolume_EntityScript
{
    default _Params = utils_surface_navigator::Make_NavFieldSpec(FBox(FVector(-1000.0, -700.0, -100.0), FVector(1000.0, 700.0, 400.0)));
}
