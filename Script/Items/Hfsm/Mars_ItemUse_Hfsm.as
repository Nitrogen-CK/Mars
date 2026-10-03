// Held-item use states. Each overrides UMars_SmState_InteractTarget_Enter on the held-item use interactable, so it runs
// once the Primary.UsableItem interaction completes (after the hold, for a Timed UseAction). The interactable owner is
// the player.

//--------------------------------------------------------------------------------------------------------------------------
// Consume
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_Consume : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_Consume;
}

// Destroys the held item when its UseAction says the use consumes it. The slot stays selected with empty hands.
class UMars_SmTask_ItemUse_Consume : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto HeldItem = utils_held_item::Get_UserHeldItem(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(HeldItem))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        // The use interactable only exists while the held item has a UseAction.
        auto Item = HeldItem.Get_CurrentItem();
        if (ck::EnsureIfNot(ck::IsValid(Item) && Item.Has_UseAction(),
            f"[ItemUse] Consume ran while [{HeldItem.ToString()}] holds no item with a UseAction"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
        if (UseAction.ConsumeOnSuccess)
        {
            auto Inventory = Item.Get_ParentInventory();
            if (ck::EnsureIfNot(ck::IsValid(Inventory), f"[ItemUse] Held item [{Item.ToString()}] is in no inventory"))
            {
                Mark_Result(ECk_SmTaskResult::Failed);
                return;
            }

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
class UMars_SmState_ItemUse_Throw : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_Throw;
}

class UMars_SmTask_ItemUse_Throw : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Context = Get_StateMachineContext();
        if (ck::EnsureIfNot(Context.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[ItemUse] Throw ran on [{Context.ToString()}] without an interaction context"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        // The use interactable is built by HeldItemUse, so its owner always has it.
        auto Player = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Use = Player.As_HeldItemUse();
        Use.Request_Throw();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Strike
//--------------------------------------------------------------------------------------------------------------------------

// Melee items (UMars_ItemTrait_Strike): one swing per use - windup, a viewpoint sphere sweep for hurtboxes, recovery.
class UMars_SmState_ItemUse_Strike : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_Strike;
}

enum EMars_ItemUse_StrikePhase
{
    // Before the sweep (WindupSeconds).
    Windup,
    // After the sweep (RecoverySeconds), hit or miss.
    Recovery
}

// On enter the player's third-person body starts its strike montage (AMars_PlayerCharacter::Request_Strike; an entity
// with no character, as in tests, has no body). After the trait's WindupSeconds, one sphere sweep from the player's
// viewpoint along its forward out to Reach through
// utils_damage_dealer::Try_StrikeSweep (filtered on Probe.Mars.HitZone; Blocking world policy, so a wall in front of a
// hurtbox stops the swing; Silent overlap notify). The first hurtbox hit is dealt through the player's DamageDealer,
// which resolves it to its zone. Succeeds RecoverySeconds after the sweep. Fails when the player has no dealer or
// viewpoint, or the held item has no Strike trait.
class UMars_SmTask_ItemUse_Strike : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

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
    private EMars_ItemUse_StrikePhase _Phase = EMars_ItemUse_StrikePhase::Windup;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Player = FCk_Handle();
        _Dealer = FCk_Handle_DamageDealer();
        _Item = FCk_Handle_Item();
        _Elapsed = 0.0f;
        _Phase = EMars_ItemUse_StrikePhase::Windup;

        auto Context = Get_StateMachineContext();
        if (ck::EnsureIfNot(Context.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[ItemUse] Strike ran on [{Context.ToString()}] without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        // Optional on the player: without a dealer or a viewpoint nothing can be struck.
        auto Player = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Dealer = Player.As_DamageDealer(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Dealer) || Player.Is_PlayerViewpoint() == false)
        {
            DoFail("the player has no DamageDealer or no PlayerViewpoint");
            return;
        }

        auto HeldItem = utils_held_item::Get_UserHeldItem(Context);
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

        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character))
        { Character.Request_Strike(); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Outcome != ECk_SmTaskResult::Running)
        { return _Outcome; }

        _Elapsed += float32(InDeltaT.Get_Seconds());

        if (_Phase == EMars_ItemUse_StrikePhase::Windup && _Elapsed >= _WindupSeconds)
        {
            _Phase = EMars_ItemUse_StrikePhase::Recovery;
            DoSwing();
        }

        if (_Phase == EMars_ItemUse_StrikePhase::Recovery && _Elapsed >= _WindupSeconds + _RecoverySeconds)
        { _Outcome = ECk_SmTaskResult::Succeeded; }

        return _Outcome;
    }

    private void DoSwing()
    {
        // Checked on enter; the player can only lose them by being torn down mid-swing.
        if (ck::Is_NOT_Valid(_Player) || ck::Is_NOT_Valid(_Dealer))
        { return; }

        auto Viewpoint = _Player.As_PlayerViewpoint();
        const auto View = utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint());
        const auto Forward = View.GetRotation().GetForwardVector();
        const auto Start = View.GetLocation();

        auto Template = utils_damage_dealer::Make_Event(_Dealer, _Damage, _DamageType);
        Template.Source.Causer = _Item;
        Template.Hit.Impulse = Forward * k_ImpulseSpeed;

        // The dealer is the player's entity, so the sweep skips the player's own bodies.
        utils_damage_dealer::Try_StrikeSweep(_Dealer, FMars_DamageDealer_Sweep(Start, Start + Forward * _Reach, _Radius), Template);
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[ItemUse] Strike failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
