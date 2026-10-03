// Held-item use states. Each overrides UMars_SmState_InteractTarget_Enter on the held-item use interactable, so it runs
// once the Primary.UsableItem interaction completes (after the hold, for a Timed UseAction). The interactable owner is
// the player.

//--------------------------------------------------------------------------------------------------------------------------
// Consume
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_Consume : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ItemUse_Consume);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// Destroys the held item when its UseAction says the use consumes it. The slot stays selected with empty hands.
class UMars_SmTask_ItemUse_Consume : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto HeldItem = utils_item_use::Get_UserHeldItem(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(HeldItem))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_UseAction() == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
        if (UseAction.ConsumeOnSuccess)
        {
            auto Inventory = Item.Get_ParentInventory();
            auto Request = FCk_Request_Inventory_RemoveItem(Item);
            Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
            Inventory.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
        }

        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Throw
//--------------------------------------------------------------------------------------------------------------------------

// For items that want the Primary button to throw. The same launch Drop-hold-release reaches.
class UMars_SmState_ItemUse_Throw : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ItemUse_Throw);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

class UMars_SmTask_ItemUse_Throw : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Context = Get_StateMachineContext();
        if (Context.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Player = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Use = Player.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Use))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Use.Request_Throw();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Strike
//--------------------------------------------------------------------------------------------------------------------------

// Melee items (UMars_ItemTrait_Strike): one swing per use - windup, a viewpoint sphere sweep for hurtboxes, recovery.
class UMars_SmState_ItemUse_Strike : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_ItemUse_Strike);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// After the trait's WindupSeconds, one sphere sweep from the player's viewpoint along its forward out to Reach through
// utils_damage_dealer::Request_StrikeSweep (filtered on Probe.Mars.HitZone; Blocking world policy, so a wall in front of a
// hurtbox stops the swing; Silent overlap notify). The first hurtbox hit is dealt through the player's DamageDealer,
// which resolves it to its zone; a debug sphere marks the hit. Succeeds RecoverySeconds after
// the sweep, hit or miss. Fails when the player has no dealer or viewpoint, or the held item has no Strike trait.
class UMars_SmTask_ItemUse_Strike : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private const float32 k_DebugSphereSeconds = 0.5f;
    private const float32 k_ImpulseSpeed = 300.0f;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle _Player;
    private FCk_Handle_DamageDealer _Dealer;
    private FCk_Handle_Item _Item;

    // Copied from the trait on enter.
    private float32 _Damage = 0.0f;
    private FGameplayTag _DamageType;
    private float32 _Reach = 0.0f;
    private float32 _Radius = 0.0f;
    private float32 _WindupSeconds = 0.0f;
    private float32 _RecoverySeconds = 0.0f;

    private float32 _Elapsed = 0.0f;
    private bool _Swung = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Player = FCk_Handle();
        _Dealer = FCk_Handle_DamageDealer();
        _Item = FCk_Handle_Item();
        _Elapsed = 0.0f;
        _Swung = false;

        auto Context = Get_StateMachineContext();
        if (Context.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        {
            DoFail("no interaction context");
            return;
        }

        auto Player = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Dealer = Player.As_DamageDealer(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Dealer) || ck::Is_NOT_Valid(Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked)))
        {
            DoFail("the player has no DamageDealer or no PlayerViewpoint");
            return;
        }

        auto HeldItem = utils_item_use::Get_UserHeldItem(Context);
        auto Item = ck::IsValid(HeldItem) ? HeldItem.Get_CurrentItem() : FCk_Handle_Item();
        if (ck::Is_NOT_Valid(Item) || Item.Has_Strike() == false)
        {
            DoFail("the held item has no Strike trait");
            return;
        }

        const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
        _Damage = Strike.Damage;
        _DamageType = Strike.DamageType;
        _Reach = Strike.Reach;
        _Radius = Strike.Radius;
        _WindupSeconds = Strike.WindupSeconds;
        _RecoverySeconds = Strike.RecoverySeconds;

        _Player = Player;
        _Dealer = Dealer;
        _Item = Item;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Outcome != ECk_SmTaskResult::Running)
        { return _Outcome; }

        _Elapsed += float32(InDeltaT.Get_Seconds());

        if (_Swung == false && _Elapsed >= _WindupSeconds)
        {
            _Swung = true;
            DoSwing();
        }

        if (_Swung && _Elapsed >= _WindupSeconds + _RecoverySeconds)
        { _Outcome = ECk_SmTaskResult::Succeeded; }

        return _Outcome;
    }

    private void DoSwing()
    {
        if (ck::Is_NOT_Valid(_Player) || ck::Is_NOT_Valid(_Dealer))
        { return; }

        auto Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return; }

        const auto View = utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint());
        const auto Forward = View.GetRotation().GetForwardVector();
        const auto Start = View.GetLocation();

        auto Template = utils_damage_dealer::Make_Event(_Dealer, _Damage, _DamageType);
        Template.Causer = FCk_Handle(_Item);
        Template.Impulse = Forward * k_ImpulseSpeed;

        // The dealer is the player's entity, so the sweep skips the player's own bodies.
        const auto Result = utils_damage_dealer::Request_StrikeSweep(_Dealer,
            FMars_DamageDealer_Sweep(Start, Start + Forward * _Reach, _Radius), Template);

        // A miss returns a default result whose HitKind reads Probe; the hit entity tells a hit apart.
        if (Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe || ck::Is_NOT_Valid(Result.Get_HitEntity()))
        { return; }

        utils_debug_draw::DrawDebugSphere(Result.Get_HitLocation(), _Radius, 12, FLinearColor(1.0, 0.2, 0.1), k_DebugSphereSeconds, 2.0f);
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[ItemUse] Strike failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}

//--------------------------------------------------------------------------------------------------------------------------

namespace utils_item_use
{
    // The context is the InteractTarget; its InteractionContext names the player as the interactable owner.
    FCk_Handle_HeldItem Get_UserHeldItem(FCk_Handle InContext)
    {
        if (InContext.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return FCk_Handle_HeldItem(); }

        auto Player = InContext.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        return Player.As_HeldItem(ECk_SanityCheck::UnChecked);
    }
}
