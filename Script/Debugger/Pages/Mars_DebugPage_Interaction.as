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
        auto Display = TryGet_PlayerEntity().As_InteractPromptDisplay(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Display))
        {
            auto Slots = Display.Get_Slots();
            DrawKvRow("Visible slots", f"{Slots.Num()}");
            for (const auto& PromptSlot : Slots)
            {
                if (PromptSlot.Stack.IsEmpty() == false && ck::IsValid(PromptSlot.Stack.Last().PromptHandle))
                { DrawKvRow(PromptSlot.SlotKey.ToString(), PromptSlot.Stack.Last().PromptHandle.Get_DisplayText().ToString()); }
            }
        }
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
            utils_mars_debugger::Text(f"{Lamp.GetName()}  [{StateLabel}]", 13);

            if (DrawButton(f"Toggle{Index}", "Toggle"))
            { Lamp.Toggle(); }

            mm::EndHorizontalBox();
        }

        EndPageScrollBox();
    }
}
