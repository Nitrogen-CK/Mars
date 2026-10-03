class UMars_DebugPage_Player : UMars_DebugPage_Base
{
    FString GetPageName() override
    {
        return "Player";
    }

    void DrawPage(float DeltaTime) override
    {
        auto PlayerEntity = TryGet_PlayerEntity();
        auto PC = GetSelectedPlayerController();
        auto Character = ck::IsValid(PC) ? Cast<AMars_PlayerCharacter>(PC.ControlledPawn) : nullptr;

        if (ck::Is_NOT_Valid(PlayerEntity) || ck::Is_NOT_Valid(Character))
        {
            DrawWarningBox("No Mars player pawn (or its entity is not ready yet).");
            return;
        }

        BeginPageScrollBox();

        DrawSectionHeading("State machine");
        auto StateMachine = PlayerEntity.As_StateMachine(ECk_SanityCheck::UnChecked);
        const FString RootState = ck::IsValid(StateMachine)
            ? Get_StateClassName(utils_state_machine::Get_CurrentStateClass(StateMachine))
            : "-";
        DrawKvRow("Root state", RootState, FLinearColor(0.6f, 0.9f, 1.0f));
        const auto IsDowned = utils_byte_attribute::Get_FinalValue(PlayerEntity, GameplayTags::ByteAttribute_Mars_Player_Downed) > 0;
        DrawKvRow("Downed", BoolText(IsDowned));
        mm::Spacer(0, 6);

        DrawSectionHeading("Movement");
        auto Movement = Character.CharacterMovement;
        DrawKvRow("Speed", f"{Character.GetVelocity().Size2D() :.0} uu/s");
        DrawKvRow("MaxWalkSpeed", f"{Movement.MaxWalkSpeed :.0}");
        DrawKvRow("Crouched", BoolText(Character.bIsCrouched));
        DrawKvRow("Falling", BoolText(Movement.IsFalling()));
        mm::Spacer(0, 6);

        DrawSectionHeading("Intents (CkIntent matcher)");
        auto Intents = PlayerEntity.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Intents))
        {
            DrawKvRow("Matcher", BoolText(ck::IsValid(Intents.Get_Matcher())));
            DrawKvRow("Move", Intents.Get_MoveDirection().ToString());
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Jump);
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Sprint);
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Crouch);
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Interact_Primary);
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Interact_Secondary);
            DrawIntentRow(Intents, GameplayTags::Mars_Intent_Interact_Use);
        }
        mm::Spacer(0, 6);

        DrawSectionHeading("Cheats");
        mm::BeginHorizontalBox();
        const FString DownedLabel = IsDowned ? "Revive" : "Down";
        if (DrawButton_WasClicked("Downed", DownedLabel))
        { utils_byte_attribute::Override(PlayerEntity, GameplayTags::ByteAttribute_Mars_Player_Downed, uint8(IsDowned ? 0 : 1)); }
        if (DrawButton_WasClicked("LaunchUp", "Launch up"))
        {
            const bool OverrideXY = false;
            const bool OverrideZ = true;
            Character.LaunchCharacter(FVector(0.0, 0.0, 900.0), OverrideXY, OverrideZ);
        }
        mm::EndHorizontalBox();

        EndPageScrollBox();
    }

    private void DrawIntentRow(FCk_Handle_InputIntents InIntents, FGameplayTag InIntent)
    {
        const auto Phase = InIntents.Get_IntentPhase(InIntent);
        const auto Color = Phase == ECk_Intent_Phase::Active ? FLinearColor(0.5f, 1.0f, 0.5f) : FLinearColor::White;
        DrawKvRow(InIntent.ToString(), f"{Phase :n}", Color);
    }
}
