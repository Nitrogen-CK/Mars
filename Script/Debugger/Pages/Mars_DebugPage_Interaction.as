class UMars_DebugPage_Interaction : UMars_DebugPage_Base
{
    FString GetPageName() override
    {
        return "Interaction";
    }

    void DrawPage(float DeltaTime) override
    {
        BeginPageScrollBox();

        DrawSectionHeading("Prompt display (selected player)");
        auto PlayerEntity = TryGet_PlayerEntity();
        if (ck::IsValid(PlayerEntity))
        { DrawPromptDisplay(PlayerEntity.As_InteractPromptDisplay()); }
        else
        { DrawWarningBox("No Mars player entity (or it is not ready yet)."); }
        mm::Spacer(0, 6);

        DrawSectionHeading("Test lamps");
        TArray<AMars_TestLamp> Lamps;
        GetAllActorsOfClass(Lamps);

        if (Lamps.Num() == 0)
        { DrawWarningBox("No AMars_TestLamp in this world."); }

        for (int32 Index = 0; Index < Lamps.Num(); ++Index)
        {
            auto Lamp = Lamps[Index];

            mm::HAlign_Fill();
            mm::BeginHorizontalBox();

            mm::Slot_Fill();
            mm::VAlign_Center();
            const FString StateLabel = Lamp.Light.IsVisible() ? "on" : "off";
            utils_mars_debugger::Text(f"{Lamp.GetName()}  [{StateLabel}]", FMars_Debugger_TextStyle(13));

            if (DrawButton_WasClicked(f"Toggle{Index}", "Toggle"))
            { Lamp.Toggle(); }

            mm::EndHorizontalBox();
        }

        EndPageScrollBox();
    }

    // The player character always composes a prompt display.
    private void DrawPromptDisplay(FCk_Handle_InteractPromptDisplay InDisplay)
    {
        auto Slots = InDisplay.Get_Slots();
        DrawKvRow("Visible slots", f"{Slots.Num()}");
        for (const auto& PromptSlot : Slots)
        {
            if (PromptSlot.Stack.IsEmpty() == false && ck::IsValid(PromptSlot.Stack.Last().PromptHandle))
            { DrawKvRow(PromptSlot.SlotKey.ToString(), PromptSlot.Stack.Last().PromptHandle.Get_DisplayText().ToString()); }
        }
    }
}
