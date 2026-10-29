// A Primary press while a world prompt is focused runs that prompt's interaction, not the held item's use: the player
// config's Primary intent lists the world Use channel before the held item's channel, and the resolver's channel order is
// its priority order (a lantern held in front of a hook hangs on Primary instead of working its shutter). The prompt
// keeps the key while blocked too (ByOfferedTargets), so a press at a blocked prompt does nothing rather than using the
// item. Reordering or dropping either channel, or the precedence, fails this.
class UMars_AutoTest_Player_PrimaryPrefersTheFocusedPromptOverTheHeldItemsUse : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("check the Primary intent's channel order", n"Step_PrimaryOrder");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PrimaryOrder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Mappings = mars::Mars_PlayerCharacter_Config.InteractionResolver.Get_IntentChannelMappings();

        auto Found = false;
        for (const auto& Mapping : Mappings)
        {
            if (Mapping.Get_Intent() != GameplayTags::InteractionIntent_Mars_Primary)
            { continue; }

            Found = true;
            const auto Channels = Mapping.Get_Channels();
            Assert_Equals_Int(Channels.Num(), 2, "the Primary intent maps the world Use channel and the held item's channel");
            if (Channels.Num() != 2)
            { return; }

            Assert_True(Channels[0] == GameplayTags::InteractionChannel_Mars_Use,
                "the world Use channel comes first, so a focused prompt outranks the held item");
            Assert_True(Channels[1] == GameplayTags::InteractionChannel_Mars_Primary_UsableItem,
                "the held item's use channel comes last");
            Assert_True(Mapping.Get_ChannelPrecedence() == ECk_InteractionResolver_ChannelPrecedence::ByOfferedTargets,
                "a focused prompt claims the key even while blocked: no fall-through to the held item's use");
        }

        Assert_True(Found, "the player config maps the Primary intent");
    }
}
