// Announces a piece once its geometry is terminal. A piece composed on Ready geometry (every cut half) was made Ready by
// Add and only announces here. One still importing keeps its tag and is polled: Ready records the volume; Failed ensures
// (an authored food mesh that does not import is a content defect), marks the piece Failed and announces the reason.
class UMars_Processor_FoodPiece_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_FoodPiece_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
        Query.Require(FMars_Tag_FoodPiece_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_FoodPiece& InState)
    {
        auto Piece = InHandle.As_FoodPiece();

        if (InState.Status == EMars_FoodPiece_Status::Pending)
        {
            const auto Geometry = Piece.Get_Geometry();
            const auto SetupState = utils_runtime_mesh::Get_SetupState(Geometry);
            if (SetupState == ECk_RuntimeMesh_SetupState::Pending)
            { return; }

            const auto IsImported = SetupState == ECk_RuntimeMesh_SetupState::Ready;
            const auto Failure = IsImported ? ECk_RuntimeMesh_SetupFailure::None : utils_runtime_mesh::Get_SetupFailure(Geometry);
            if (ck::EnsureIfNot(IsImported, f"[FoodPiece] [{Piece.ToString()}] failed to import its mesh: {Failure :n}"))
            {
                InState.Status = EMars_FoodPiece_Status::Failed;
                Piece.Request_TryRemove(FMars_Tag_FoodPiece_NeedsSetup);

                if (Piece.Has_Fragment(FMars_Fragment_FoodPiece_Signals))
                { Piece.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnFailed.Broadcast(Piece, Failure); }

                return;
            }

            InState.VolumeCm3 = utils_runtime_mesh::Get_Metrics(Geometry).Get_VolumeCm3();
            InState.Status = EMars_FoodPiece_Status::Ready;
        }

        Piece.Request_TryRemove(FMars_Tag_FoodPiece_NeedsSetup);

        ck::Trace(f"[FoodPiece] [{Piece.ToString()}] ready: {InState.MassKg :.4} kg, {InState.VolumeCm3 :.3} cm3");

        if (Piece.Has_Fragment(FMars_Fragment_FoodPiece_Signals))
        { Piece.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnReady.Broadcast(Piece); }
    }
}
