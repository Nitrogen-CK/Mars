// On a copy without authority, every frame, for each piece whose ride waits (FMars_Tag_FoodPiece_AwaitsRide): applies the
// replicated ledger's ride again (utils_foodpiece::Update_Ride), which drops the tag once the piece rides its holder or the
// ledger no longer says it rides. Polled rather than woken by a notify: the holder arriving or a hand letting go raises
// nothing on the piece. Only Update_Ride stamps the tag, and never on the authority.
class UMars_Processor_FoodPiece_Ride : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_FoodPiece_AwaitsRide;
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FoodPiece_Mirror");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
        Query.Require(FMars_Tag_FoodPiece_AwaitsRide);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Piece = InHandle.As_FoodPiece();
        utils_foodpiece::Update_Ride(Piece);
    }
}
