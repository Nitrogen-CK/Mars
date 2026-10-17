// The run the anchor resolver is playing: its seed, entrance, quarry and closures, every anchor's ledger row, and any
// planned anchor id this world never produced (a plan and its level out of step). Read-only.
class UMars_DebugPage_Anchors : UMars_DebugPage_Base
{
    FString GetPageName() override
    {
        return "Anchors";
    }

    void DrawPage(float DeltaTime) override
    {
        const auto AnyHandle = TryGet_PlayerEntity();
        if (ck::Is_NOT_Valid(AnyHandle))
        {
            DrawWarningBox("No Mars player entity to reach the world's anchor resolver through (or it is not ready yet).");
            return;
        }

        const auto Resolvers = utils_entity_tag::ForEach_Entity(AnyHandle, n"TAG_MarsAnchorResolver");
        if (Resolvers.Num() == 0)
        {
            DrawWarningBox("No anchor resolver in this world (not an anchored map).");
            return;
        }

        BeginPageScrollBox();
        for (auto Entity : Resolvers)
        {
            DrawResolver(Entity.As_AnchorResolver());
            mm::Spacer(0, 6);
        }
        EndPageScrollBox();
    }

    private FString Get_NamesText(const TArray<FName>& InNames) const
    {
        auto Text = "";
        for (const auto& Each : InNames)
        { Text = Text == "" ? Each.ToString() : f"{Text}, {Each.ToString()}"; }

        return Text == "" ? "none" : Text;
    }

    private void DrawResolver(FCk_Handle_AnchorResolver InResolver)
    {
        const auto Result = InResolver.Get_Result();
        DrawSectionHeading("Run");
        DrawKvRow("Seed", f"{Result.Seed}");
        DrawKvRow("Entrance", f"{Result.Entrance.ToString()} ({Result.PlayerStartTag.ToString()})");
        DrawKvRow("Quarry", Result.Quarry.ToString(), FLinearColor(1.0f, 0.5f, 0.4f));
        DrawKvRow("Closed", Get_NamesText(Result.Closed));
        DrawKvRow("Divergence", f"{Result.Divergence :.2}");
        DrawKvRow("Fallback", BoolText(Result.UsedFallback), Result.UsedFallback ? FLinearColor(1.0f, 0.65f, 0.3f) : FLinearColor::White);
        DrawKvRow("Candidates rejected", f"{Result.CandidatesRejected}");

        const auto Ledger = InResolver.Get_Ledger();
        DrawSectionHeading(f"Ledger ({Ledger.Num()} anchors)");
        for (const auto& Entry : Ledger)
        {
            const auto PinnedText = Entry.Pinned ? " - pinned" : "";
            const auto MismatchText = Entry.RoleMismatch ? " - ROLE MISMATCH" : "";
            DrawKvRow(Entry.AnchorId.ToString(), f"{Entry.ScriptName} - {Entry.Role :n} - row {Entry.RowIndex}{PinnedText}{MismatchText}",
                Entry.RoleMismatch ? FLinearColor(1.0f, 0.65f, 0.3f) : FLinearColor::White);
        }

        DrawSectionHeading("Unmatched plan ids");
        const auto Unmatched = InResolver.Get_UnmatchedPlannedIds();
        if (Unmatched.Num() == 0)
        { DrawKvRow("Unmatched", "none"); }
        else
        { DrawWarningBox(f"Planned but never resolved in this world: {Get_NamesText(Unmatched)}"); }
    }
}
