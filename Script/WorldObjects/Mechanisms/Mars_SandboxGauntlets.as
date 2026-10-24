// Preconfigured mechanisms and rewards for the sandbox gauntlets: cells off a hall north of the main floor, each a
// self-contained socket combining several mechanisms (Mars.Sandbox.BuildGauntlets and Mars.Sandbox.BuildGauntlet8 in
// Script/Editor/Mars_SandboxGauntletBuilder.as place them). Not under Script/Editor: the saved map references these
// classes at runtime. Struct fields other than channels are set in DoConstruct, as in Mars_SandboxMechanisms.as.
//
// The Blind Choir's seal glyph colors match on purpose: the silhouette (circle, triangle) is the key, not the color.

//--------------------------------------------------------------------------------------------------------------------------
// G1 - The Mourner's Table: the chef plate AND the backpack plate, pressed together, latch the truffle alcove open.
//--------------------------------------------------------------------------------------------------------------------------

// Oversized relief plates, released a beat after leaving so "both at once" is not a frame-perfect test.
UCLASS(Abstract)
class UMars_Gauntlet_ReliefPlate_EntityScript : UMars_PressurePlate_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        PlateSize = FVector(160.0, 160.0, 8.0);
        Trigger.BoxHalfExtents = FVector(80.0, 80.0, 30.0);
        Occupancy.RequiredCount = 1;
        Occupancy.ReleaseDelaySeconds = 0.25f;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Gauntlet_Mourner_ChefPlate_EntityScript : UMars_Gauntlet_ReliefPlate_EntityScript
{
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Mourner_Chef;
    default DecalTexture = assets::ChefCharacter_T();
}

// Only a dropped pack weighs on it: a worn or held pack's weight probe is off, and a chef is not a backpack.
class UMars_Gauntlet_Mourner_PackPlate_EntityScript : UMars_Gauntlet_ReliefPlate_EntityScript
{
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Mourner_Pack;
    default DecalTexture = assets::Backpack_T();

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(
            GameplayTags::Probe_Mars_Backpack);
        return Super::DoConstruct(InHandle);
    }
}

// Latched: once both plates were down together it stays open whoever steps off.
class UMars_Gauntlet_Mourner_AlcoveGate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Mourner_Chef);
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Mourner_Pack);
    default Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Truffle_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Truffle();
}

//--------------------------------------------------------------------------------------------------------------------------
// G3 - The Bellkeeper's Confession: three dials on the lower west wall, a pull chain on the gallery; the plaque over the
// reliquary gate shows the phrase. A wrong pull vents steam across the chain and snuffs a candle (Cleaver, then
// Tenderizer); the right one latches the reliquary gate and lays out what is left (the Ration always). The reliquary's
// hand wheel latches the return door to the hall.
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_gauntlet_bell
{
    // The one phrase: the panel's answer and the plaque's glyphs both read it.
    TArray<EMars_Bellkeeper_Glyph> Get_Phrase()
    {
        TArray<EMars_Bellkeeper_Glyph> Phrase;
        Phrase.Add(EMars_Bellkeeper_Glyph::Diamond);
        Phrase.Add(EMars_Bellkeeper_Glyph::Triangle);
        Phrase.Add(EMars_Bellkeeper_Glyph::Cross);
        return Phrase;
    }
}

class UMars_Gauntlet_Bell_Panel_EntityScript : UMars_Bellkeeper_EntityScript
{
    default _ShowInPlaceActors = false;
    default CommitChannel = GameplayTags::Mechanism_Channel_Gauntlet_Bell_Commit;
    default VentChannel = GameplayTags::Mechanism_Channel_Gauntlet_Bell_Vent;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Bell_Open;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Phrase = constants_gauntlet_bell::Get_Phrase();

        StartGlyphs.Reset();
        for (int32 Index = 0; Index < Phrase.Num(); ++Index)
        { StartGlyphs.Add(EMars_Bellkeeper_Glyph::Square); }

        // Slightly longer than the burst vent's 2.0 s, so the power never cuts the burst short.
        VentPulseSeconds = 2.2f;

        // Offsets from the panel (cell -590, 600, 120) to the reliquary floor (cell X -560..-160, Y 1100..1400).
        Rewards.Reset();
        Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Cleaver()),
            FTransform(FVector(160.0, 620.0, -90.0))));
        Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Tenderizer()),
            FTransform(FVector(240.0, 620.0, -90.0))));
        Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Ration()),
            FTransform(FVector(320.0, 620.0, -90.0))));

        return Super::DoConstruct(InHandle);
    }
}

class UMars_Gauntlet_Bell_Clue_EntityScript : UMars_BellkeeperClue_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Phrase = constants_gauntlet_bell::Get_Phrase();
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Gauntlet_Bell_Chain_EntityScript : UMars_PullChain_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Bell_Commit;
}

// One burst per wrong pull, across the chain's pull stand, pushing the puller toward the north wall.
class UMars_Gauntlet_Bell_Vent_EntityScript : UMars_Vent_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Bell_Vent);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trap = utils_trap::Make_BurstVentSpec();
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Gauntlet_Bell_ReliquaryGate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Bell_Open);
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Bell_ReturnWheel_EntityScript : UMars_HandWheel_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Bell_Return;
}

class UMars_Gauntlet_Bell_ReturnDoor_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Bell_Return);
    default Sink.Latch = true;
}

class UMars_Gauntlet_Root_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Root();
}

//--------------------------------------------------------------------------------------------------------------------------
// G4 - The Censer's Window: a chain on either side lights three lamps; while any is lit the censer is braked at the far
// side of its lane and the shutter at the lane's end is up. The walled lane beside it always works.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Gauntlet_Censer_Chain_EntityScript : UMars_PullChain_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Censer_Chain;
}

// Three lamps, one going dark every 2 s: 6 s of window after the last pull.
class UMars_Gauntlet_Censer_Lamps_EntityScript : UMars_LampBank_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Censer_Chain);
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Censer_Window;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Countdown.Steps = 3;
        Countdown.SecondsPerStep = 2.0f;
        return Super::DoConstruct(InHandle);
    }
}

// Waits for an empty doorway before it drops.
class UMars_Gauntlet_Censer_Shutter_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Censer_Window);
    default WaitsForClearThreshold = true;
}

// Swings across its lane (local X) while the window is shut; the window's brake catches it at -25 degrees, its bob against
// the lane's west wall, and lets it go from there. Contact nudges rather than throws: the lane costs time, never the run.
class UMars_Gauntlet_Censer_EntityScript : UMars_Pendulum_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Censer_Window);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Oscillator.AmplitudeDegrees = 25.0f;
        Oscillator.PeriodSeconds = 3.0f;
        Oscillator.CatchAngleDegrees = TOptional<float32>(-25.0f);
        Pendulum.Powered = EMars_PoweredBehavior::SuppressWhilePowered;
        Hazard.PushImpulse = FVector(250.0, 0.0, 100.0);
        return Super::DoConstruct(InHandle);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// G5 - The Porter's Wager: a dropped pack on the slab holds the grace lamps full and the freight gate open; lifting it
// starts about 8 s of grace. Only the slab opens the gate from outside: a chain there would let a chef wearing the pack
// walk through and the slab would never matter. Beyond the gate, a dropped pack anywhere in the passage holds the lamps
// full too (so a pack left inside never strands its chef outside, and leaving with it is the same wager), and a chain
// lets a chef inside without the pack out.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Gauntlet_Porter_Slab_EntityScript : UMars_Gauntlet_ReliefPlate_EntityScript
{
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Porter_Slab;
    default DecalTexture = assets::Backpack_T();

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(
            GameplayTags::Probe_Mars_Backpack);
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Gauntlet_Porter_Chain_EntityScript : UMars_PullChain_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Porter_Rescue;
}

// The passage beyond the freight gate (580 x 570, centred where the builder places it), sensing only a dropped pack.
class UMars_Gauntlet_Porter_PackInside_EntityScript : UMars_OccupancyVolume_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Porter_PackInside;

    protected FVector Get_BoxHalfExtents() const
    {
        return FVector(290.0, 285.0, 60.0);
    }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.Shape = EMars_Trigger_Shape::Box;
        Trigger.BoxHalfExtents = Get_BoxHalfExtents();
        Trigger.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 60.0));
        Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(
            GameplayTags::Probe_Mars_Backpack);
        Occupancy.RequiredCount = 1;
        Occupancy.ReleaseDelaySeconds = 0.0f;
        return Super::DoConstruct(InHandle);
    }
}

// Three lamps of 2.7 s: held full while a dropped pack lies on the slab or beyond the gate (or the chain is down), about
// 8 s of grace once none is.
class UMars_Gauntlet_Porter_Lamps_EntityScript : UMars_LampBank_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Porter_Slab);
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Porter_PackInside);
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Porter_Rescue);
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Porter_Window;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Countdown.Steps = 3;
        Countdown.SecondsPerStep = 2.7f;
        Countdown.HoldWhilePowered = true;
        return Super::DoConstruct(InHandle);
    }
}

// Barred, so the salt niche shows from the slab; waits for an empty doorway before it drops.
class UMars_Gauntlet_Porter_Gate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Porter_Window);
    default Leaf = EMars_Gate_Leaf::Bars;
    default WaitsForClearThreshold = true;
}

class UMars_Gauntlet_Salt_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Salt();
}

//--------------------------------------------------------------------------------------------------------------------------
// G6 - The Blind Choir: the lower hand wheel latches the bell loft's viewing shutter open; the bell's hidden face shows the
// order (circle, then triangle); the two lower seals in that order latch the fungus vault.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Gauntlet_Choir_Wheel_EntityScript : UMars_HandWheel_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Choir_Shutter;
}

class UMars_Gauntlet_Choir_Shutter_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Choir_Shutter);
    default Sink.Latch = true;
}

class UMars_Gauntlet_Choir_CircleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Choir_Circle;
    default Glyph = EMars_Seal_Glyph::Circle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

class UMars_Gauntlet_Choir_TriangleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Choir_Triangle;
    default Glyph = EMars_Seal_Glyph::Triangle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

// Circle, then triangle; pressable from the start, so a correct guess opens the vault too.
class UMars_Gauntlet_Choir_Sequence_EntityScript : UMars_SequenceNode_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sequence.Steps.Add(GameplayTags::Mechanism_Channel_Gauntlet_Choir_Circle);
    default Sequence.Steps.Add(GameplayTags::Mechanism_Channel_Gauntlet_Choir_Triangle);
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Choir_Open;
}

class UMars_Gauntlet_Choir_VaultGate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Choir_Open);
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Fungus_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Fungus();
}

//--------------------------------------------------------------------------------------------------------------------------
// G8 - The Chain Crossing: cranking the windlass hauls the plank bridge down across the channel; the far bank's lamp lights
// when it lands. The lanterns on the bridge's hinge posts are always lit.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Gauntlet_Chain_Bridge_EntityScript : UMars_ChainBridge_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::Mechanism_Channel_Gauntlet_Chain_Down;
}

// Warm and always lit; the builder rolls it over so it stands on its post.
class UMars_Gauntlet_Chain_Lantern_EntityScript : UMars_LightFixture_EntityScript
{
    default _ShowInPlaceActors = false;
    default LightColor = FLinearColor(1.0f, 0.62f, 0.3f, 1.0f);
    default Intensity = 3000.0f;
    default AttenuationRadius = 700.0f;
}

class UMars_Gauntlet_Chain_Lamp_EntityScript : UMars_LightFixture_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Gauntlet_Chain_Down);
    default LightColor = FLinearColor(1.0f, 0.62f, 0.3f, 1.0f);
}

class UMars_Gauntlet_Fig_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Fig();
}
