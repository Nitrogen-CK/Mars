// The shipped surface FX table. A new surface is a phys mat with a Surface.* tag and a row here; a surface without a row
// of its own plays its parent tag's row, then Surface.Default's.

namespace utils_surface_fx
{
    UMars_SurfaceFx_Table Get_Table()
    {
        return mars::SurfaceFx_Mars;
    }

    TSoftObjectPtr<USoundBase> Make_Sound(const FString& InObjectPath)
    {
        return TSoftObjectPtr<USoundBase>(FSoftObjectPath(InObjectPath));
    }

    // One variant for every intensity, at full volume.
    FMars_SurfaceFx_Cell Make_SoundCell(TSoftObjectPtr<USoundBase> InSound)
    {
        auto Variant = FMars_SurfaceFx_Variant();
        Variant.Sound = InSound;

        auto Cell = FMars_SurfaceFx_Cell();
        Cell.Variants.Add(Variant);
        return Cell;
    }

    FMars_SurfaceFx_Kinds Make_StepKinds(TSoftObjectPtr<USoundBase> InFootstep, TSoftObjectPtr<USoundBase> InLand)
    {
        auto Kinds = FMars_SurfaceFx_Kinds();
        Kinds.ByKind.Add(GameplayTags::SurfaceFx_Footstep, Make_SoundCell(InFootstep));
        Kinds.ByKind.Add(GameplayTags::SurfaceFx_Land, Make_SoundCell(InLand));
        return Kinds;
    }

    // Silent below the light knock's speed; the item's knock, louder with speed, up to the heavy speed; the surface's
    // hit (InHeavySound, InHeavyVfx, either may be null) at full volume from there.
    FMars_SurfaceFx_Cell Make_ImpactCell(TSoftObjectPtr<USoundBase> InHeavySound, TSoftObjectPtr<UNiagaraSystem> InHeavyVfx)
    {
        auto Light = FMars_SurfaceFx_Variant();
        Light.MinIntensity = constants_surface_fx::k_ImpactLightMinSpeed;
        Light.Sound = Make_Sound("/Game/Mars/Audio/WAVsCUEs/Impacts/ItemImpact_Mars_SND.ItemImpact_Mars_SND");
        Light.IntensityRange = FVector2D(constants_surface_fx::k_ImpactLightMinSpeed, constants_surface_fx::k_ImpactHeavyMinSpeed);
        Light.VolumeRange = FVector2D(constants_surface_fx::k_ImpactLightMinVolume, constants_surface_fx::k_ImpactLightMaxVolume);

        auto Heavy = FMars_SurfaceFx_Variant();
        Heavy.MinIntensity = constants_surface_fx::k_ImpactHeavyMinSpeed;
        Heavy.Sound = InHeavySound;
        Heavy.Vfx = InHeavyVfx;

        auto Cell = FMars_SurfaceFx_Cell();
        Cell.Variants.Add(Light);
        Cell.Variants.Add(Heavy);
        return Cell;
    }
}

// Asset literals live in mars:: so other files can name them (a global-scope asset is file-local).
namespace mars
{
    asset SurfaceFx_Mars of UMars_SurfaceFx_Table
    {
        const auto StoneStep = utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Concrete/Normal/cue/Stone_Footstep_Mars_SND.Stone_Footstep_Mars_SND");
        const auto StoneLand = utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Concrete/Normal/cue/Stone_Landed_Mars_SND.Stone_Landed_Mars_SND");
        const auto HitDefault = utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/Impacts/HitImpact_Default_Mars_SND.HitImpact_Default_Mars_SND");
        const auto HitDefaultVfx = TSoftObjectPtr<UNiagaraSystem>(FSoftObjectPath("/Game/Mars/Fx/Impacts/HitImpact_Default_Mars_FX.HitImpact_Default_Mars_FX"));

        // Untagged geometry is stone: the map builders' default block surface.
        FMars_SurfaceFx_Row Default;
        Default.Kinds = utils_surface_fx::Make_StepKinds(StoneStep, StoneLand);
        Default.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Impact, utils_surface_fx::Make_ImpactCell(HitDefault, HitDefaultVfx));
        Rows.Add(GameplayTags::Surface_Default, Default);

        FMars_SurfaceFx_Row Stone;
        Stone.Kinds = utils_surface_fx::Make_StepKinds(StoneStep, StoneLand);
        Rows.Add(GameplayTags::Surface_Stone, Stone);

        FMars_SurfaceFx_Row StoneGritty;
        StoneGritty.Kinds = utils_surface_fx::Make_StepKinds(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Concrete/Gritty/cue/StoneGritty_Footstep_Mars_SND.StoneGritty_Footstep_Mars_SND"),
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Concrete/Gritty/cue/StoneGritty_Landed_Mars_SND.StoneGritty_Landed_Mars_SND"));
        Rows.Add(GameplayTags::Surface_Stone_Gritty, StoneGritty);

        FMars_SurfaceFx_Row Dirt;
        Dirt.Kinds = utils_surface_fx::Make_StepKinds(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Gravel/cue/Dirt_Footstep_Mars_SND.Dirt_Footstep_Mars_SND"),
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Gravel/cue/Dirt_Landed_Mars_SND.Dirt_Landed_Mars_SND"));
        Rows.Add(GameplayTags::Surface_Dirt, Dirt);

        FMars_SurfaceFx_Row Grass;
        Grass.Kinds = utils_surface_fx::Make_StepKinds(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Grass/cue/Grass_Footstep_Mars_SND.Grass_Footstep_Mars_SND"),
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Grass/cue/Grass_Landed_Mars_SND.Grass_Landed_Mars_SND"));
        Rows.Add(GameplayTags::Surface_Grass, Grass);

        FMars_SurfaceFx_Row Mud;
        Mud.Kinds = utils_surface_fx::Make_StepKinds(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/WaterandMud/cue/Mud_Footstep_Mars_SND.Mud_Footstep_Mars_SND"),
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/WaterandMud/cue/Mud_Landed_Mars_SND.Mud_Landed_Mars_SND"));
        Rows.Add(GameplayTags::Surface_Mud, Mud);

        FMars_SurfaceFx_Row Sand;
        Sand.Kinds = utils_surface_fx::Make_StepKinds(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Sand/cue/Sand_Footstep_Mars_SND.Sand_Footstep_Mars_SND"),
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Sand/cue/Sand_Landed_Mars_SND.Sand_Landed_Mars_SND"));
        Rows.Add(GameplayTags::Surface_Sand, Sand);

        // Carpet steps are a walk below a run's speed ratio and a run from there.
        auto CarpetRun = FMars_SurfaceFx_Variant();
        CarpetRun.MinIntensity = constants_surface_fx::k_RunSpeedRatio;
        CarpetRun.Sound = utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Carpet/cue/Carpet_Run_Mars_SND.Carpet_Run_Mars_SND");
        auto CarpetSteps = utils_surface_fx::Make_SoundCell(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Carpet/cue/Carpet_Walk_Mars_SND.Carpet_Walk_Mars_SND"));
        CarpetSteps.Variants.Add(CarpetRun);

        FMars_SurfaceFx_Row Carpet;
        Carpet.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Footstep, CarpetSteps);
        Carpet.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Land, utils_surface_fx::Make_SoundCell(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/FootstepsSoundsPack/Carpet/cue/Carpet_Landed_Mars_SND.Carpet_Landed_Mars_SND")));
        Rows.Add(GameplayTags::Surface_Carpet, Carpet);

        // Wood, Metal and Flesh have impacts only; their steps and landings are Default's until they have their own.
        FMars_SurfaceFx_Row Wood;
        Wood.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Impact, utils_surface_fx::Make_ImpactCell(HitDefault, HitDefaultVfx));
        Rows.Add(GameplayTags::Surface_Wood, Wood);

        FMars_SurfaceFx_Row Metal;
        Metal.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Impact, utils_surface_fx::Make_ImpactCell(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/Impacts/HitImpact_Metal_Mars_SND.HitImpact_Metal_Mars_SND"),
            TSoftObjectPtr<UNiagaraSystem>(FSoftObjectPath("/Game/Mars/Fx/Impacts/HitImpact_Metal_Mars_FX.HitImpact_Metal_Mars_FX"))));
        Rows.Add(GameplayTags::Surface_Metal, Metal);

        FMars_SurfaceFx_Row Flesh;
        Flesh.Kinds.ByKind.Add(GameplayTags::SurfaceFx_Impact, utils_surface_fx::Make_ImpactCell(
            utils_surface_fx::Make_Sound("/Game/Mars/Audio/WAVsCUEs/Impacts/HitImpact_Flesh_Mars_SND.HitImpact_Flesh_Mars_SND"),
            TSoftObjectPtr<UNiagaraSystem>()));
        Rows.Add(GameplayTags::Surface_Flesh, Flesh);
    }
}
