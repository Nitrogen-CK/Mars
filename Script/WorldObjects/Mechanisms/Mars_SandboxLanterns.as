// Preconfigured pieces for the sandbox map's room 7, the dark room (Mars.Sandbox.BuildRoom7 in
// Script/Editor/Mars_SandboxMapBuilder.as). Not under Script/Editor: the saved map references them at runtime.

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
        Source.OutputChannel = GameplayTags::Mechanism_Channel_Lights;
        return Super::DoConstruct(InHandle);
    }
}

class UMars_Sandbox_CeilingLight_EntityScript : UMars_LightFixture_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Sink.InputChannels.Add(GameplayTags::Mechanism_Channel_Lights);
        return Super::DoConstruct(InHandle);
    }
}

// The flame fixtures' pieces (Mars.Sandbox.PlaceFlames in Script/Editor/Mars_Flames_MapBuilder.as).
namespace utils_flame_fixture
{
    // By name: a tag added to the ini while the editor runs is registered only at its next start.
    FGameplayTag Get_SandboxChannel()
    {
        return FGameplayTag::RequestGameplayTag(n"Mechanism.Channel.Flames.Sandbox");
    }
}

// A candle whose lit flame asserts the room's flame channel.
class UMars_Sandbox_Candle_EntityScript : UMars_Candle_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Source.OutputChannel = utils_flame_fixture::Get_SandboxChannel();
        return Super::DoConstruct(InHandle);
    }
}

// A ceiling lamp lit only while every source on the room's flame channel is asserted: both candles lit.
class UMars_Sandbox_FlameLight_EntityScript : UMars_LightFixture_EntityScript
{
    default _ShowInPlaceActors = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Sink.InputChannels.Add(utils_flame_fixture::Get_SandboxChannel());
        Sink.Rule = EMars_MechanismSink_Rule::AllSources;
        return Super::DoConstruct(InHandle);
    }
}
