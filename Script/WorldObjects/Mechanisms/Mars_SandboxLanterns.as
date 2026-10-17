// Preconfigured pieces for the sandbox map's room 7, the dark room (Mars.Sandbox.BuildRoom7 in
// Script/Editor/Mars_SandboxMapBuilder.as). Not under Script/Editor: the saved map references them at runtime.

namespace constants_sandbox_lights
{
    // Resolved by name: the accessor exists only once a restarted editor has registered the tag.
    FGameplayTag Get_Channel()
    {
        return GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Lights");
    }
}

// A wall switch that toggles the room's ceiling lights: each press flips its source.
class UMars_Sandbox_LightSwitch_EntityScript : UMars_Switch_EntityScript
{
    default _ShowInPlaceActors = false;
    default PromptText = NSLOCTEXT("MarsInteraction", "ToggleLightsPrompt", "Toggle lights");

    // Not defaults: the spawn-params generator emits a non-default struct default as a positional constructor call,
    // which script structs do not have.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Control.Behavior = EMars_Control_Behavior::Toggle;
        Source.OutputChannel = constants_sandbox_lights::Get_Channel();
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_CeilingLight_EntityScript : UMars_LightFixture_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Sink.InputChannels.Add(constants_sandbox_lights::Get_Channel());
        return Super::DoConstruct(InHandle);
    }
}
