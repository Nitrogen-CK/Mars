// Preconfigured mechanisms for the sandbox map's room 2 (Script/Editor/Mars_SandboxMapBuilder.as). ACk_EntitySpawner_UE's
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
        Switch.HoldSeconds = 4.0f;
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
