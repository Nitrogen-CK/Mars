// A focused interactable that dies without an unfocus (a pickup destroys the item under the view trace) must not keep
// a glove leaning. The focus target's anchor freezes where the item lay, so the lean would otherwise hold the glove a
// fixed world offset from its grip until something else is looked at. The feature drops a dead focus on its own; the
// lean needs no state machine, so none is added here.
class UMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean : UMars_AutoTestRig_Hands
{
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle _Anchor;
    private float32 _FocusLean = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        _FocusLean = Spec.Reach.Focus.Lean;
        auto Root = Add_Hands(InHandle, Spec);

        // Something to look at, ahead of and below the hand node: a transform-only interactable (no probe, no targets).
        auto AnchorNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(80.0, 0.0, -40.0)));
        _Anchor = AnchorNode;
        auto AnchorTransform = AnchorNode.As_Transform();
        _Interactable = utils_interactable::Create(AnchorTransform, FMars_Interactable_Spec());

        Add_Step("focus the interactable", n"Step_Focus");
        Add_Step_WaitUntil("a glove leans toward it", n"Check_IsLeaning", 0, 5.0f);
        Add_Step("destroy the focused interactable without an unfocus", n"Step_DestroyInteractable");
        Add_Step_WaitUntil("the focus is dropped and the lean eases out", n"Check_LeanCleared", 0, 5.0f);
        Add_Step("no focus target, no lean", n"Step_AssertCleared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(_Interactable, _Anchor));
    }

    UFUNCTION()
    private void Check_IsLeaning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_FocusTarget().IsSet() && Get_Lean() > _FocusLean * 0.5f);
    }

    UFUNCTION()
    private void Step_DestroyInteractable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Interactable.H());
    }

    UFUNCTION()
    private void Check_LeanCleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_FocusTarget().IsSet() == false && Get_Lean() < 0.01f);
    }

    UFUNCTION()
    private void Step_AssertCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Is_NOT_Valid(_Interactable), "the focused interactable was destroyed");
        Assert_True(_Hands.Get_FocusTarget().IsSet() == false, "a dead focus is no focus");

        const auto Lean = Get_Lean();
        Assert_True(Lean < 0.01f, f"the lean eased out (lean {Lean})");
    }

    // The larger of the two gloves' focus leans; which glove a point target picks is the resolver's business.
    private float32 Get_Lean() const
    {
        return Math::Max(_Hands.Get_FocusAlpha(EMars_Hand::Left), _Hands.Get_FocusAlpha(EMars_Hand::Right));
    }
}
