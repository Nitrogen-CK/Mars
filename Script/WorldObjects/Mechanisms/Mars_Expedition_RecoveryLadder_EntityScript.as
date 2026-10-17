// The lower scenic base always has a way back onto the expedition route.
class UMars_Expedition_RecoveryLadder_EntityScript : UMars_Ladder_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    float32 RiseCm = 800.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Ladder.Height = RiseCm;
        Ladder.Width = 90.0f;
        Ladder.TopExitDepth = 150.0f;
        return Super::DoConstruct(InHandle);
    }
}
