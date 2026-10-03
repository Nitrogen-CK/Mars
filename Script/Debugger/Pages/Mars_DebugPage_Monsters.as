// Every entity tagged TAG_MarsMonster in the selected player's world: its body health, dead flag and parts, and for a
// crawler its gait, legs, navigator, state machine (root and behaviour states) and brain (leaf and facts). Read-only: it
// never requests or writes anything.
class UMars_DebugPage_Monsters : UMars_DebugPage_Base
{
    FString GetPageName() override
    {
        return "Monsters";
    }

    void DrawPage(float DeltaTime) override
    {
        // Any live handle reaches the world's registry; the selected player's is the one the base page resolves.
        const auto AnyHandle = TryGet_PlayerEntity();
        if (ck::Is_NOT_Valid(AnyHandle))
        {
            DrawWarningBox("No Mars player entity to reach the world's monsters through (or it is not ready yet).");
            return;
        }

        const auto Monsters = utils_entity_tag::ForEach_Entity(AnyHandle, n"TAG_MarsMonster");

        BeginPageScrollBox();

        if (Monsters.Num() == 0)
        { DrawWarningBox("No monster in this world."); }

        for (auto Entity : Monsters)
        {
            const auto Monster = Entity.As_Monster(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Monster))
            { continue; }

            DrawMonster(Entity, Monster);
            mm::Spacer(0, 6);
        }

        EndPageScrollBox();
    }

    private void DrawMonster(FCk_Handle InEntity, FCk_Handle_Monster InMonster)
    {
        DrawSectionHeading(f"{utils_handle::Get_DebugName(InEntity)}  {InEntity.ToString()}");

        const auto IsDead = InMonster.Get_IsDead();
        DrawKvRow("Dead", BoolText(IsDead), IsDead ? FLinearColor(1.0f, 0.4f, 0.4f) : FLinearColor(0.5f, 1.0f, 0.5f));
        DrawKvRow("Body health", Get_HealthText(InMonster.Get_BodyHealth()));
        DrawKvRow("Parts attached", f"{InMonster.Get_AttachedPartCount()} / {InMonster.Get_Parts().Num()}");

        for (const auto& Part : InMonster.Get_Parts())
        {
            if (ck::Is_NOT_Valid(Part))
            { continue; }

            DrawKvRow(f"  {Part.Get_PartTag().ToString()}",
                f"{Part.Get_State() :n} | {Part.Get_Condition() :n} | {Get_HealthText(Part.Get_Health())}",
                Part.Get_State() == EMars_BodyPart_State::Attached ? FLinearColor::White : FLinearColor(0.6f, 0.6f, 0.6f));
        }

        const auto Crawler = InEntity.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Crawler))
        { DrawCrawler(Crawler); }

        auto StateMachine = InEntity.As_StateMachine(ECk_SanityCheck::UnChecked);
        const FString RootState = ck::IsValid(StateMachine)
            ? utils_state_machine::Get_CurrentStateClass(StateMachine).Get().GetName().ToString()
            : "-";
        DrawKvRow("SM root state", RootState, FLinearColor(0.6f, 0.9f, 1.0f));

        if (ck::IsValid(Crawler))
        {
            const TSubclassOf<UCk_SmState_EntityScript> BehaviorState = Crawler.Get_BehaviorStateClass();
            DrawKvRow("SM behaviour state", ck::IsValid(BehaviorState) ? BehaviorState.Get().GetName().ToString() : "-",
                FLinearColor(0.6f, 0.9f, 1.0f));
        }

        const auto Brain = InEntity.As_Brain(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Brain))
        { DrawBrain(Brain); }
    }

    private void DrawBrain(FCk_Handle_Brain InBrain)
    {
        DrawKvRow("Brain", InBrain.Get_IsEnabled() ? "enabled" : "disabled");
        DrawKvRow("Leaf", utils_brain::Get_ClassName(InBrain.Get_LeafClass()), FLinearColor(1.0f, 0.85f, 0.4f));

        for (const auto& Fact : InBrain.Get_Spec().Facts)
        { DrawKvRow(f"  {Fact.Key.ToString()}", BoolText(InBrain.Get_Fact(Fact.Key))); }
    }

    private void DrawCrawler(FCk_Handle_Crawler InCrawler)
    {
        const auto Gait = InCrawler.Get_Gait();
        if (ck::IsValid(Gait))
        {
            DrawKvRow("Gait", f"{utils_procedural_gait::Get_Status(Gait) :n}");
            DrawKvRow("Legs enabled", f"{utils_procedural_gait::Get_EnabledLegCount(Gait)} / {utils_procedural_gait::Get_Legs(Gait).Num()}");
        }

        const auto Navigator = InCrawler.Get_Navigator();
        if (ck::Is_NOT_Valid(Navigator))
        {
            DrawKvRow("Navigator", "-");
            return;
        }

        const auto Status = Navigator.Get_Status();
        const auto StatusText = Status == EMars_SurfaceNavigator_Status::Failed
            ? f"{Status :n} ({Navigator.Get_FailReason() :n})"
            : f"{Status :n}";
        DrawKvRow("Navigator", StatusText);
        DrawKvRow("Path mode", f"{Navigator.Get_PathMode() :n}");
        DrawKvRow("Goal", Navigator.Get_Goal().ToString());
        DrawKvRow("Waypoint", f"{Navigator.Get_WaypointIndex()} / {Navigator.Get_Waypoints().Num()}");
    }

    private FString Get_HealthText(FCk_Handle_Health InHealth) const
    {
        if (ck::Is_NOT_Valid(InHealth))
        { return "-"; }

        return f"{InHealth.Get_Current() :.0} / {InHealth.Get_Max() :.0}";
    }
}
