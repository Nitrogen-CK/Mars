// Editor-only: Mars.ScreamingTurnip.BuildReviewRoom places the Screaming Turnip's review set-up into the CURRENTLY OPEN
// level and saves nothing: a 2400 x 1200 floor slab (top at Z 0, BlockAll, so the Jolt LiveExtract static world sees it),
// a turnip bed at the origin, a player start 250 cm in front of it facing it, and a second bed 1000 cm away along +X (the
// second location for a later out-of-range check). It never loads or creates a level (a level load from a console
// command issued through the MCP bridge hung the editor, 2026-11-05): open the review map by hand first, then save it by
// hand. Re-running it deletes everything it placed before (labels starting ScreamingTurnipReview_). Refuses while PIE runs.

#if EDITOR
UFUNCTION()
void Mars_BuildScreamingTurnipReviewRoomFunc(const TArray<FString>& Args)
{
    utils_screaming_turnip_review::Build();
}

const FConsoleCommand Mars_BuildScreamingTurnipReviewRoomCommand("Mars.ScreamingTurnip.BuildReviewRoom", n"Mars_BuildScreamingTurnipReviewRoomFunc");

namespace utils_screaming_turnip_review
{
    const FString k_Command = "Mars.ScreamingTurnip.BuildReviewRoom";
    const FString k_Prefix = "ScreamingTurnipReview_";

    const FVector k_FloorSize = FVector(2400.0, 1200.0, 20.0);
    const FVector k_FloorCentre = FVector(400.0, 0.0, -10.0);
    const FVector k_SecondBed = FVector(1000.0, 0.0, 0.0);
    const FVector k_PlayerStart = FVector(-250.0, 0.0, 100.0);

    void Build()
    {
        if (UUnrealEditorSubsystem::Get().GetGameWorld() != nullptr)
        {
            ck::Trace(f"[{k_Command}] Stop PIE first.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        if (ck::Is_NOT_Valid(UUnrealEditorSubsystem::Get().GetEditorWorld()))
        {
            ck::Trace(f"[{k_Command}] No editor level is open.", NAME_None, 2.0f, FLinearColor::Yellow);
            return;
        }

        ClearPrevious();

        auto Floor = utils_mars_map_builder::Spawn_Block(engine::load::Cube(),
            FMars_MapBuilder_Block(k_Prefix + "Floor", k_FloorCentre, k_FloorSize * 0.01));
        if (ck::IsValid(Floor))
        {
            Floor.StaticMeshComponent.SetCollisionProfileName(n"BlockAll");
            Floor.StaticMeshComponent.SetMaterial(0, utils_mars_map_builder::Get_ProtoGrid_Floor());
        }

        utils_mars_map_builder::Spawn_EntityScript(UMars_ScreamingTurnipBed_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "Bed", FVector::ZeroVector));
        utils_mars_map_builder::Spawn_EntityScript(UMars_ScreamingTurnipBed_EntityScript,
            FMars_MapBuilder_Placement(k_Prefix + "SecondBed", k_SecondBed));

        auto Start = UEditorActorSubsystem::Get().SpawnActorFromClass(APlayerStart, k_PlayerStart, FRotator::ZeroRotator);
        if (ck::IsValid(Start))
        { Start.SetActorLabel(k_Prefix + "PlayerStart"); }

        ck::Trace(f"[{k_Command}] done: placed into the open level, not saved");
    }

    void ClearPrevious()
    {
        auto Actors = UEditorActorSubsystem::Get();
        for (auto Actor : Actors.GetAllLevelActors())
        {
            if (ck::IsValid(Actor) && Actor.GetActorLabel().StartsWith(k_Prefix))
            { Actors.DestroyActor(Actor); }
        }
    }
}
#endif
