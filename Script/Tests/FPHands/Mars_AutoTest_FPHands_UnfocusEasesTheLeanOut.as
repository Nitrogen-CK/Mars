// Looking away from an interactable eases the gloves' lean back out instead of snapping: after the unfocus the focus
// target is kept while the lean decays, and only cleared once it has reached zero.
class UMars_AutoTest_FPHands_UnfocusEasesTheLeanOut : UCk_AutoTest_Base
{
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle _Owner;
    private float32 _LeanAtUnfocus = 0.0f;
    private bool _SawEaseOut = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);
        auto Player = InHandle;
        auto Spec = FMars_FPHands_Spec();
        Spec.HandNode = HandNode.As_Transform();
        _Hands = utils_fphands::Add(Player, Spec);

        // A plain interactable ahead and to the right: a point grip, one glove.
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto OwnerRoot = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, FVector(80.0, 30.0, 0.0)), ECk_Replication::DoesNotReplicate);
        _Interactable = utils_interactable::Create(OwnerRoot, FMars_Interactable_Spec());

        Add_Step("focus the interactable", n"Step_Focus");
        Add_Step_WaitUntil("the glove has leaned in", n"Check_LeanedIn", 0, 5.0f);
        Add_Step("look away", n"Step_Unfocus");
        Add_Step_WaitUntil("the lean has eased out and the focus target is cleared", n"Check_EasedOut", 0, 5.0f);
        Add_Step("the lean eased down over several frames before the target cleared", n"Step_AssertEased");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus(_Interactable, _Owner));
    }

    UFUNCTION()
    private void Check_LeanedIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Lean = Math::Max(_Hands.Get_FocusAlpha(EMars_Hand::Right), _Hands.Get_FocusAlpha(EMars_Hand::Left));
        Res.Set(_Hands.Get_FocusTarget().IsSet() && Lean > _Hands.Get_Spec().Reach.Focus.Lean * 0.9f);
    }

    UFUNCTION()
    private void Step_Unfocus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LeanAtUnfocus = Math::Max(_Hands.Get_FocusAlpha(EMars_Hand::Right), _Hands.Get_FocusAlpha(EMars_Hand::Left));
        _Hands.Request_SetFocus(FMars_Request_FPHands_SetFocus());
    }

    UFUNCTION()
    private void Check_EasedOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Lean = Math::Max(_Hands.Get_FocusAlpha(EMars_Hand::Right), _Hands.Get_FocusAlpha(EMars_Hand::Left));
        const auto HasTarget = _Hands.Get_FocusTarget().IsSet();

        // The snap bug: the target vanished the frame the focus did, taking the lean pose with it.
        if (HasTarget && Lean > 0.01f && Lean < _LeanAtUnfocus)
        { _SawEaseOut = true; }

        Res.Set(HasTarget == false);
    }

    UFUNCTION()
    private void Step_AssertEased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LeanAtUnfocus > 0.1f, f"the glove had leaned in before the unfocus (lean {_LeanAtUnfocus})");
        Assert_True(_SawEaseOut, "after the unfocus the focus target stayed while the lean decayed (no snap)");
        Assert_True(_Hands.Get_FocusAlpha(EMars_Hand::Right) == 0.0f && _Hands.Get_FocusAlpha(EMars_Hand::Left) == 0.0f, "the lean is fully out once the target clears");
    }
}
