// Every EMars_FPEmote has a registered Mars.Emote.<name> tag, and the tag maps back to the same emote; tags that are not
// emotes map to nothing. The player config carries one glove and one body montage for every emote.
class UMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("map every emote to its tag and back", n"Step_RoundTrip");
        Add_Step("reject tags that are not emotes", n"Step_NotEmotes");
        Add_Step("check both montage tables cover every emote", n"Step_MontageTables");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_RoundTrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Canonical order: the emote wheel definition and both montage tables follow it.
        TArray<FString> Expected;
        Expected.Add("Wave");
        Expected.Add("ThumbsUp");
        Expected.Add("Point");
        Expected.Add("Clap");
        Expected.Add("FlipOff");
        Expected.Add("Cheer");
        Expected.Add("Laugh");
        Expected.Add("Bow");
        Expected.Add("Dance");
        Expected.Add("Shrug");
        Expected.Add("Rest");

        Assert_Equals_Int(utils_fphands::Get_EmoteCount(), Expected.Num(), "EMars_FPEmote has the 11 canonical emotes");

        for (int32 Index = 0; Index < Expected.Num(); ++Index)
        {
            const auto Emote = EMars_FPEmote(Index);
            const auto Tag = utils_fphands::Get_EmoteTag(Emote);
            Assert_True(Tag.IsValid(), f"emote {Index} has a registered tag");
            Assert_Equals_String(Tag.ToString(), f"Mars.Emote.{Expected[Index]}", f"emote {Index} is Mars.Emote.{Expected[Index]}");

            auto MappedBack = EMars_FPEmote::Wave;
            const auto Found = utils_fphands::TryGet_Emote(Tag, MappedBack);
            Assert_True(Found && MappedBack == Emote, f"Mars.Emote.{Expected[Index]} maps back to emote {Index}");
        }
    }

    UFUNCTION()
    private void Step_NotEmotes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Emote = EMars_FPEmote::Rest;
        Assert_False(utils_fphands::TryGet_Emote(FGameplayTag(), Emote), "an empty tag is no emote");
        Assert_False(utils_fphands::TryGet_Emote(GameplayTags::ResolveGameplayTag(n"Mars.Intent.EmoteWheel"), Emote),
            "a tag outside Mars.Emote is no emote");
        Assert_True(Emote == EMars_FPEmote::Rest, "a failed lookup leaves the out value alone");
    }

    UFUNCTION()
    private void Step_MontageTables(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Count = utils_fphands::Get_EmoteCount();
        auto Config = mars::Mars_PlayerCharacter_Config;
        Assert_Equals_Int(Config.FPHandsEmotes.Montages.Num(), Count, "one glove montage per emote");
        Assert_Equals_Int(Config.TPBody.Montages.EmoteMontages.Num(), Count, "one body montage per emote");
        for (int32 Value = 0; Value < Count; ++Value)
        {
            const auto Emote = EMars_FPEmote(Value);
            Assert_True(Config.FPHandsEmotes.Montages.Contains(Emote), f"the gloves have a montage for [{Emote :n}]");
            Assert_True(Config.TPBody.Montages.EmoteMontages.Contains(Emote), f"the body has a montage for [{Emote :n}]");
        }

        auto ShortTable = Config.TPBody;
        ShortTable.Montages.EmoteMontages.Remove(EMars_FPEmote::Rest);
        Assert_False(ShortTable.Validate().IsValid(), "a body montage table missing an emote is rejected");
    }
}
