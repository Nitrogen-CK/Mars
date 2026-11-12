// On a copy without authority, once per piece tagged FMars_Tag_FoodPiece_NeedsSuccession (the tag goes): rules on which of
// this machine's pieces stand, so a piece and one cut from it are never shown together. The pieces it has ruled on are kept
// in FMars_Fragment_FoodPiece_Kin on this processor's handle (the world's transient entity); gone ones are dropped on every
// run. For the tagged piece: when a standing piece was cut from it, it is superseded (whatever it was); else, when it is
// arriving, every standing piece it was cut from is superseded and it stands. Each change writes the standing first, then
// raises OnStandingChanged. Nothing is destroyed, moved or hidden here: the scripts that dress a piece follow the signal.
// It runs after the Replay and Mirror processors, so a piece built or a lineage adopted in a frame is ruled on in that frame.
// Local and read by no simulation; the authority's pieces never carry the tag and always stand.
class UMars_Processor_FoodPiece_Succession : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_FoodPiece_NeedsSuccession;
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FoodPiece_Replay");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FoodPiece_Mirror");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
        Query.Require(FMars_Tag_FoodPiece_NeedsSuccession);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_FoodPiece_NeedsSuccession);
        auto Piece = InHandle.As_FoodPiece();
        if (ck::EnsureIfNot(InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Local),
            f"[FoodPiece] [{InHandle.ToString()}] asks for succession without its local mirror state"))
        { return; }

        // A copy: a handler dresses a piece (it composes and may move the kin's storage).
        const auto Kin = Update_Kin(Piece);

        for (const auto& Other : Kin)
        {
            if (Other != Piece && Other.Get_Standing() == EMars_FoodPiece_Standing::Current && utils_foodpiece::Get_IsCutFrom(Other, Piece))
            {
                Change(Piece, EMars_FoodPiece_Standing::Superseded);
                return;
            }
        }

        if (Piece.Get_Standing() != EMars_FoodPiece_Standing::Arriving)
        { return; }

        for (const auto& Other : Kin)
        {
            if (Other == Piece || Other.Get_IsGone() || Other.Get_Standing() != EMars_FoodPiece_Standing::Current)
            { continue; }

            if (utils_foodpiece::Get_IsCutFrom(Piece, Other))
            {
                auto Ancestor = Other;
                Change(Ancestor, EMars_FoodPiece_Standing::Superseded);
            }
        }

        if (Piece.Get_IsGone() == false)
        { Change(Piece, EMars_FoodPiece_Standing::Current); }
    }

    // The kin without the gone, with InPiece added once; returned as a copy.
    private TArray<FCk_Handle_FoodPiece> Update_Kin(const FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle WorldEntity = _Handle;
        auto& Kin = WorldEntity.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Kin);
        for (int32 Index = Kin.Pieces.Num() - 1; Index >= 0; --Index)
        {
            if (Kin.Pieces[Index].Get_IsGone())
            { Kin.Pieces.RemoveAt(Index); }
        }

        if (Kin.Pieces.Contains(InPiece) == false)
        { Kin.Pieces.Add(InPiece); }

        return Kin.Pieces;
    }

    // The standing is written before the broadcast: a handler dresses the piece.
    private void Change(FCk_Handle_FoodPiece& InPiece, EMars_FoodPiece_Standing InStanding)
    {
        auto& Local = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Local);
        if (Local.Standing == InStanding)
        { return; }

        Local.Standing = InStanding;
        if (InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
        { return; }

        // Handlers dress the piece: scope the script world to the entity's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InPiece));
        InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnStandingChanged.Broadcast(InPiece, InStanding);
    }
}
