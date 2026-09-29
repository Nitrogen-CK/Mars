// Preconfigured mechanisms for the sandbox map's rooms 2 and 3 (Script/Editor/Mars_SandboxMapBuilder.as). ACk_EntitySpawner_UE's
// script slot is not script-writable, so the builder places these through the spawner's actor factory, which
// instances the class with these defaults. Not under Script/Editor: the saved map references them at runtime.

class UMars_Sandbox_LeverA_EntityScript : UMars_Lever_EntityScript
{
    default _ShowInPlaceActors = false;
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.A");
}

class UMars_Sandbox_LeverB_EntityScript : UMars_Lever_EntityScript
{
    default _ShowInPlaceActors = false;
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
        Control.Interaction = EMars_Control_Interaction::Timed;
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

class UMars_Sandbox_LeverK_EntityScript : UMars_Lever_EntityScript
{
    default _ShowInPlaceActors = false;
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
