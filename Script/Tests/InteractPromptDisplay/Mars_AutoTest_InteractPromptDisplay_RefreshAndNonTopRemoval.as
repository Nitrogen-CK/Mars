// The display's stack, driven by its own requests: two Use prompts share the Use slot, the later on top (A appears, B
// updates the slot). A refresh of the top prompt re-broadcasts the slot; a refresh of the prompt under it broadcasts
// nothing. Removing the prompt under the top changes nothing on screen (no broadcast) and drops its display binding while
// the top keeps its own; removing the top then removes the slot. Each negative is read in the drain whose positive proves
// the requests ran.
class UMars_AutoTest_InteractPromptDisplay_RefreshAndNonTopRemoval : UCk_AutoTest_Base
{
    private FCk_Handle_InteractPromptDisplay _Display;
    private FCk_Handle_InteractPrompt _PromptA;
    private FCk_Handle_InteractPrompt _PromptB;

    // Every display edge in order: "Appeared", "Updated" or "Removed", with the prompt it carried.
    private TArray<FString> _Kinds;
    private TArray<FCk_Handle_InteractPrompt> _Prompts;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Holder = InHandle;
        _Display = utils_interact_prompt_display::Add(Holder);
        _Display.BindTo_OnPromptAppeared(FMars_Delegate_InteractPromptDisplay_OnPromptAppeared(this, n"OnAppeared"));
        _Display.BindTo_OnPromptUpdated(FMars_Delegate_InteractPromptDisplay_OnPromptUpdated(this, n"OnUpdated"));
        _Display.BindTo_OnPromptRemoved(FMars_Delegate_InteractPromptDisplay_OnPromptRemoved(this, n"OnRemoved"));

        _PromptA = Build_UsePrompt(InHandle, "Pull A");
        _PromptB = Build_UsePrompt(InHandle, "Pull B");

        Add_Step("add prompt A, then prompt B", n"Step_AddBoth");
        Add_Step_WaitUntil("the display broadcast both adds", n"Check_TwoEdges", 0, 0);
        Add_Step("A appeared; B updated the shared Use slot on top of it", n"Step_AssertStacked");
        Add_Step("refresh the prompt under the top, then the top", n"Step_RefreshBoth");
        Add_Step_WaitUntil("the display broadcast the top's refresh", n"Check_ThreeEdges", 0, 0);
        Add_Step("only the top's refresh broadcast", n"Step_AssertOneRefresh");
        Add_Step("remove the prompt under the top, and refresh the top", n"Step_RemoveUnderTheTop");
        Add_Step_WaitUntil("the display broadcast the top's refresh", n"Check_FourEdges", 0, 0);
        Add_Step("the removal broadcast nothing and left B alone in the slot", n"Step_AssertNonTopRemoved");
        Add_Step_WaitUntil("A's display binding is gone", n"Check_AUnbound", 0, 0);
        Add_Step("B keeps its binding; remove B", n"Step_RemoveTop");
        Add_Step_WaitUntil("the display broadcast the top's removal", n"Check_FiveEdges", 0, 0);
        Add_Step("B's removal removed the slot", n"Step_AssertSlotRemoved");
        Run_Steps(InHandle);
    }

    // A Use prompt on its own Instant control's target (no focus: the test drives the display directly).
    private FCk_Handle_InteractPrompt Build_UsePrompt(FCk_Handle InHandle, FString InText)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto Control = utils_control::Add(RootEntity, FMars_Control_Spec());

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString(InText))));
        auto Interactable = utils_interactable::Create(Root, Spec);
        return Interactable.Get_AllInteractTargets()[0].As_InteractPrompt();
    }

    private void Record(FString InKind, const FMars_InteractPromptDisplay_SlotEvent& InEvent)
    {
        Assert_True(InEvent.SlotKey == constants_interact_prompt_display::k_UseSlotKey,
            f"a {InKind} edge names the Use slot (got [{InEvent.SlotKey.ToString()}])");
        Assert_Equals_Int(InEvent.SortOrder, constants_interact_prompt::k_UseSortOrder, f"a {InKind} edge carries the Use order");
        _Kinds.Add(InKind);
        _Prompts.Add(InEvent.Prompt);
    }

    UFUNCTION()
    private void OnAppeared(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        Record("Appeared", InEvent);
    }

    UFUNCTION()
    private void OnUpdated(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        Record("Updated", InEvent);
    }

    UFUNCTION()
    private void OnRemoved(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        Record("Removed", InEvent);
    }

    private void Assert_Edge(int32 InIndex, FString InKind, const FCk_Handle_InteractPrompt& InPrompt, FString InPromptName)
    {
        if (_Kinds.Num() <= InIndex)
        {
            FinishFailure(f"edge [{InIndex}] never came ({_Kinds.Num()} edges)");
            return;
        }

        Assert_Equals_String(_Kinds[InIndex], InKind, f"edge [{InIndex}] is {InKind}");
        Assert_True(_Prompts[InIndex] == InPrompt, f"edge [{InIndex}] carries prompt {InPromptName}");
    }

    // The Use slot's stack, bottom first; empty when the slot is gone.
    private TArray<FCk_Handle_InteractPrompt> Get_UseStack() const
    {
        auto Stack = TArray<FCk_Handle_InteractPrompt>();
        for (const auto& Slot : _Display.Get_Slots())
        {
            if (Slot.SlotKey != constants_interact_prompt_display::k_UseSlotKey)
            { continue; }

            for (const auto& Entry : Slot.Stack)
            { Stack.Add(Entry.PromptHandle); }
        }

        return Stack;
    }

    UFUNCTION()
    private void Step_AddBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_PromptA, "prompt A was composed");
        Assert_Valid(_PromptB, "prompt B was composed");
        _Display.Request_AddPrompt(FMars_Request_InteractPromptDisplay_AddPrompt(_PromptA));
        _Display.Request_AddPrompt(FMars_Request_InteractPromptDisplay_AddPrompt(_PromptB));
    }

    UFUNCTION()
    private void Check_TwoEdges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Kinds.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertStacked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Kinds.Num(), 2, "two edges for two adds");
        Assert_Edge(0, "Appeared", _PromptA, "A");
        Assert_Edge(1, "Updated", _PromptB, "B");

        const auto Stack = Get_UseStack();
        Assert_Equals_Int(Stack.Num(), 2, "the Use slot stacks both prompts");
        if (Stack.Num() == 2)
        { Assert_True(Stack[0] == _PromptA && Stack[1] == _PromptB, "A under B"); }

        Assert_True(_PromptA.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding), "A is bound to the display");
        Assert_True(_PromptB.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding), "B is bound to the display");
    }

    UFUNCTION()
    private void Step_RefreshBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(_PromptA));
        _Display.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(_PromptB));
    }

    UFUNCTION()
    private void Check_ThreeEdges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Kinds.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertOneRefresh(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Kinds.Num(), 3, "the two refreshes broadcast one edge");
        Assert_Edge(2, "Updated", _PromptB, "B");
    }

    // Drained Refresh before Remove: B's refresh broadcasts in the same drain as A's removal.
    UFUNCTION()
    private void Step_RemoveUnderTheTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Display.Request_RemovePrompt(FMars_Request_InteractPromptDisplay_RemovePrompt(_PromptA));
        _Display.Request_RefreshPrompt(FMars_Request_InteractPromptDisplay_RefreshPrompt(_PromptB));
    }

    UFUNCTION()
    private void Check_FourEdges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Kinds.Num() >= 4);
    }

    UFUNCTION()
    private void Step_AssertNonTopRemoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Kinds.Num(), 4, "removing the prompt under the top broadcast nothing");
        Assert_Edge(3, "Updated", _PromptB, "B");

        const auto Stack = Get_UseStack();
        Assert_Equals_Int(Stack.Num(), 1, "the Use slot holds one prompt");
        if (Stack.Num() == 1)
        { Assert_True(Stack[0] == _PromptB, "B is left in the slot"); }
    }

    UFUNCTION()
    private void Check_AUnbound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PromptA.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding) == false);
    }

    UFUNCTION()
    private void Step_RemoveTop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PromptB.Has_Fragment(FMars_Fragment_InteractPrompt_DisplayBinding), "B keeps its display binding");
        _Display.Request_RemovePrompt(FMars_Request_InteractPromptDisplay_RemovePrompt(_PromptB));
    }

    UFUNCTION()
    private void Check_FiveEdges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Kinds.Num() >= 5);
    }

    UFUNCTION()
    private void Step_AssertSlotRemoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Kinds.Num(), 5, "B's removal broadcast one edge");
        Assert_Edge(4, "Removed", _PromptB, "B");
        Assert_Equals_Int(Get_UseStack().Num(), 0, "the Use slot is gone");
    }
}
