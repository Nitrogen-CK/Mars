// The sandbox's fail switch: a momentary push switch asserting Mechanism.Channel.ServiceFailed while it is down, which
// every steward's sink turns into a devouring (Mars_Steward_EntityScript.as). The player who presses it is the nearest
// one, so it is the one taken. Placed by Mars.Sandbox.PlaceFailSwitch on a pedestal in front of the sandbox's steward;
// it can also be dragged into any map from the Place Actors panel.
class UMars_Sandbox_FailSwitch_EntityScript : UMars_Switch_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(constants_steward::k_ServiceFailedChannel);
    default PromptText = NSLOCTEXT("MarsInteraction", "FailServicePrompt", "Fail the service");
}
