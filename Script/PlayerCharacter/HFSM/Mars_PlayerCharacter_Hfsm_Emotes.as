// Emote keys -> the first-person gloves. The intents are listed in EMars_FPEmote order.
class UMars_SmTask_EmoteIntents : UMars_SmTask_IntentEdges
{
    private AMars_PlayerCharacter _Character;
    private TArray<FGameplayTag> _EmoteIntents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Character = Cast<AMars_PlayerCharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));

        _EmoteIntents.Empty();
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Wave"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.ThumbsUp"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Point"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.Clap"));
        _EmoteIntents.Add(GameplayTags::ResolveGameplayTag(n"Mars.Intent.Emote.FlipOff"));

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Character = nullptr;
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        const auto Index = _EmoteIntents.FindIndex(InIntent);
        if (Index < 0 || ck::Is_NOT_Valid(_Character))
        { return; }

        _Character.Request_FPEmote(EMars_FPEmote(Index));
    }
}
