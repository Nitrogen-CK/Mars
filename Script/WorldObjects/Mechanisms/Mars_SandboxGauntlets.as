// Preconfigured mechanisms and rewards for the sandbox gauntlets: five cells off a hall north of the main floor, each a
// self-contained socket combining several mechanisms (Mars.Sandbox.BuildGauntlets in
// Script/Editor/Mars_SandboxGauntletBuilder.as places them). Not under Script/Editor: the saved map references these
// classes at runtime. Struct fields other than channels are set in DoConstruct, as in Mars_SandboxMechanisms.as.
//
// The seals' glyph colors match on purpose: the silhouette (circle, triangle) is the key, not the color.

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
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Mourner.Chef");
    default DecalTexture = assets::ChefCharacter_T();
}

// Only a dropped pack weighs on it: a worn or held pack's weight probe is off, and a chef is not a backpack.
class UMars_Gauntlet_Mourner_PackPlate_EntityScript : UMars_Gauntlet_ReliefPlate_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Mourner.Pack");
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
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Mourner.Chef"));
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Mourner.Pack"));
    default Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Truffle_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Truffle();
}

//--------------------------------------------------------------------------------------------------------------------------
// G3 - The Bellkeeper's Confession: the lower circle seal, then the upper triangle seal, latch the reliquary gate; the
// reliquary's hand wheel latches the return door to the hall.
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Gauntlet_Bell_CircleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Circle");
    default Glyph = EMars_Seal_Glyph::Circle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

class UMars_Gauntlet_Bell_TriangleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Triangle");
    default Glyph = EMars_Seal_Glyph::Triangle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

// Circle, then triangle. No step timeout; a wrong seal resets the unfinished progress.
class UMars_Gauntlet_Bell_Sequence_EntityScript : UMars_SequenceNode_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Circle"));
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Triangle"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Open");
}

class UMars_Gauntlet_Bell_ReliquaryGate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Open"));
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Bell_ReturnWheel_EntityScript : UMars_HandWheel_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Return");
}

class UMars_Gauntlet_Bell_ReturnDoor_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Bell.Return"));
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
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Censer.Chain");
}

// Three lamps, one going dark every 2 s: 6 s of window after the last pull.
class UMars_Gauntlet_Censer_Lamps_EntityScript : UMars_LampBank_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Censer.Chain"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Censer.Window");

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
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Censer.Window"));
    default WaitsForClearThreshold = true;
}

// Swings across its lane (local X) while the window is shut; the window's brake catches it at -25 degrees, its bob against
// the lane's west wall, and lets it go from there. Contact nudges rather than throws: the lane costs time, never the run.
class UMars_Gauntlet_Censer_EntityScript : UMars_Pendulum_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Censer.Window"));

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
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Slab");
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
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Rescue");
}

// The passage beyond the freight gate (580 x 570, centred where the builder places it), sensing only a dropped pack.
class UMars_Gauntlet_Porter_PackInside_EntityScript : UMars_OccupancyVolume_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.PackInside");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.Shape = EMars_Trigger_Shape::Box;
        Trigger.BoxHalfExtents = FVector(290.0, 285.0, 60.0);
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
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Slab"));
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.PackInside"));
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Rescue"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Window");

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
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.Window"));
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
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Shutter");
}

class UMars_Gauntlet_Choir_Shutter_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Shutter"));
    default Sink.Latch = true;
}

class UMars_Gauntlet_Choir_CircleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Circle");
    default Glyph = EMars_Seal_Glyph::Circle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

class UMars_Gauntlet_Choir_TriangleSeal_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Triangle");
    default Glyph = EMars_Seal_Glyph::Triangle;
    default GlyphColor = FLinearColor(1.0f, 0.6f, 0.15f, 1.0f);
}

// Circle, then triangle; pressable from the start, so a correct guess opens the vault too.
class UMars_Gauntlet_Choir_Sequence_EntityScript : UMars_SequenceNode_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Circle"));
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Triangle"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Open");
}

class UMars_Gauntlet_Choir_VaultGate_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Choir.Open"));
    default Sink.Latch = true;
    default Leaf = EMars_Gate_Leaf::Bars;
}

class UMars_Gauntlet_Fungus_EntityScript : UMars_WorldItem_EntityScript
{
    default Definition = mars_items::Fungus();
}
