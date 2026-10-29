#if EDITOR
// Read-only companion to Mars_ExpeditionAcceptance. Explicit context scopes queries to the player's PIE world.
class UMars_StewardService_ReviewProbe : UObject
{
    UFUNCTION()
    int32 GetPromptCount(AMars_PlayerCharacter InChef) const
    {
        auto Display = ck::ToEntity(InChef).As_InteractPromptDisplay(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Display) ? Display.Get_Slots().Num() : -1;
    }

    UFUNCTION()
    FVector GetViewLocation(AMars_PlayerCharacter InChef) const
    {
        if (ck::Is_NOT_Valid(InChef))
        { return FVector::ZeroVector; }
        auto Player = ck::ToEntity(InChef).As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Player) ? Player.Get_Camera().Get_ViewInfo().Location : FVector::ZeroVector;
    }

    UFUNCTION()
    bool GetGateOpen(AMars_Camp_PlayerController InController) const
    {
        auto Gate = FindGate(InController);
        return ck::IsValid(Gate) && Gate.Get_IsOpen();
    }

    UFUNCTION()
    float32 GetGateAlpha(AMars_Camp_PlayerController InController) const
    {
        auto Gate = FindGate(InController);
        if (ck::Is_NOT_Valid(Gate))
        { return -1.0f; }
        return Gate.Get_MovingNode().As_Mover().Get_Alpha();
    }

    private FCk_Handle_Gate FindGate(AMars_Camp_PlayerController InController) const
    {
        if (ck::Is_NOT_Valid(InController))
        { return FCk_Handle_Gate(); }
        auto Context = ck::ToEntity(InController);
        if (ck::Is_NOT_Valid(Context))
        { return FCk_Handle_Gate(); }
        for (auto Entity : utils_entity_tag::ForEach_Entity(Context, n"TAG_MarsCampMissionGate"))
        { return Entity.As_Gate(ECk_SanityCheck::UnChecked); }
        return FCk_Handle_Gate();
    }
}
#endif
