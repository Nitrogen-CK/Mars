// Preconfigured mechanisms for the sandbox map's rooms 2 and 3 (Script/Editor/Mars_SandboxMapBuilder.as). ACk_EntitySpawner_UE's
// script slot is not script-writable, so the builder places these through the spawner's actor factory, which
// instances the class with these defaults. Not under Script/Editor: the saved map references them at runtime.
// Every sandbox lever is pulled (UMars_Sandbox_PulledLever_EntityScript); SwitchC, the seals and WheelJ stay pressed or held.

// The sandbox levers are pulled: Use grips the handle and the look input swings it over. Control fields are set in
// DoConstruct, like SwitchC and WheelJ, rather than as subclass defaults on the nested struct.
UCLASS(Abstract)
class UMars_Sandbox_PulledLever_EntityScript : UMars_Lever_EntityScript
{
    default _ShowInPlaceActors = false;
    default PromptText = NSLOCTEXT("MarsInteraction", "PullLeverHoldPrompt", "Grip lever");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_LeverA_EntityScript : UMars_Sandbox_PulledLever_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.A");
}

class UMars_Sandbox_LeverB_EntityScript : UMars_Sandbox_PulledLever_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.B");
}

class UMars_Sandbox_SwitchC_EntityScript : UMars_Switch_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.C");

    // Not a default: the spawn-params generator emits a non-default struct default as a positional constructor
    // call, which script structs do not have.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Control.ActiveSeconds = 4.0f;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_GateA_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.A"));
    default Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
}

class UMars_Sandbox_GateB_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.B"));
    default Sink.Rule = EMars_MechanismSink_Rule::AllSources;
}

class UMars_Sandbox_GateC_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.C"));
    default Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
}

//--------------------------------------------------------------------------------------------------------------------------
// Room 3
//--------------------------------------------------------------------------------------------------------------------------

class UMars_Sandbox_PlateF_EntityScript : UMars_PressurePlate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.F");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Occupancy.RequiredCount = 1;
        Occupancy.ReleaseDelaySeconds = 1.5f;
        return Super::DoConstruct(InHandle);
    }
}

// A second source on channel F that only a dropped backpack presses (the pack's weight probe is on only while it lies in
// the world): leave the pack on it and GateF opens. Marked with the backpack icon.
class UMars_Sandbox_BackpackPlateF_EntityScript : UMars_PressurePlate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.F");
    default DecalTexture = assets::Backpack_T();

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(
            GameplayTags::ResolveGameplayTag(n"Probe.Mars.Backpack"));
        Occupancy.RequiredCount = 1;
        Occupancy.ReleaseDelaySeconds = 0.5f;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_GateF_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.F"));
}

class UMars_Sandbox_SealG_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.G");
    default GlyphColor = FLinearColor(0.1f, 0.35f, 1.0f, 1.0f);
}

class UMars_Sandbox_SealH_EntityScript : UMars_Seal_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.H");
    default GlyphColor = FLinearColor(1.0f, 0.45f, 0.05f, 1.0f);
}

// Seal H, then seal G.
class UMars_Sandbox_SequenceI_EntityScript : UMars_SequenceNode_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.H"));
    default Sequence.Steps.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.G"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.I");
}

class UMars_Sandbox_GateI_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.I"));
    default Sink.Latch = true;
}

class UMars_Sandbox_WheelJ_EntityScript : UMars_HandWheel_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.J");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Control.Interaction = ECk_Interaction_CompletionPolicy::Timed;
        Control.HoldSeconds = 2.0f;
        Control.Behavior = EMars_Control_Behavior::Momentary;
        Control.ActiveSeconds = 8.0f;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_VentJ_EntityScript : UMars_Vent_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.J"));
    default Trap.Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

class UMars_Sandbox_LeverK_EntityScript : UMars_Sandbox_PulledLever_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.K");
}

class UMars_Sandbox_SpikesK_EntityScript : UMars_SpikeTrap_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.K"));
    default Trap.Powered = EMars_PoweredBehavior::SuppressWhilePowered;
}

// 25 degrees keeps the 80 uu bob (on a 250 uu arm) inside the 300 uu corridor it swings across.
class UMars_Sandbox_Pendulum_EntityScript : UMars_Pendulum_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Oscillator.AmplitudeDegrees = 25.0f;
        return Super::DoConstruct(InHandle);
    }
}

// Room 4: either chain charges the lamp bank over the gate (channel L); the bank asserts channel M while any lamp is lit,
// which holds the gate open. Five lamps, one going dark every 1.5 s: 7.5 s to get through after the last pull.
class UMars_Sandbox_ChainL_EntityScript : UMars_PullChain_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.L");
}

class UMars_Sandbox_LampsL_EntityScript : UMars_LampBank_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.L"));
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.M");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Countdown.Steps = 5;
        Countdown.SecondsPerStep = 1.5f;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_GateM_EntityScript : UMars_Gate_EntityScript
{
    default _ShowInPlaceActors = false;
    default Sink.InputChannels.Add(GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.M"));
}
