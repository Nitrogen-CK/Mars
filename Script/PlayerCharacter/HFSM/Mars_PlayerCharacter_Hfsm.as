// Root (on the player entity, initial = Alive)
// |- Alive       ->Downed [IsDowned]
// |    tasks: HotbarDrivesHeldItem, AliveSubSm, HandsSubSm
// |    modes: Alive keeps only what outlives both modes - the hotbar -> held-item link and the gloves' sub-SM. Every
// |           interaction task lives on the mode that uses it:
// |             Locomotion = the free-roam interaction mode (view-trace focus, resolver intents, levers, hotbar keys,
// |                          emotes, held-item use / drop / hints, ladders);
// |             Operating  = the station mode (the station owns pose, camera, the grip, LMB and the leave key).
// |           Every task is EnterExitOnly and signal-driven (the intent tasks through UMars_SmTask_IntentEdges' matcher
// |           edges), except ManipulateControl and EmoteWheelIntent, Tick tasks that read the look delta while a control
// |           is gripped / the emote wheel is open; the view needs no sync task - the interaction trace rides the camera
// |           director's view anchor (PlayerViewpoint)
// |    |- Alive sub-SM (initial = Locomotion)
// |    |    |- Locomotion   ->Operating [IsOperating]
// |    |    |    tasks: InteractionFocus, InteractionResolverBinds, Use/PrimaryIntentToResolver, ManipulateControl,
// |    |    |           HotbarIntents, EmoteIntents, EmoteWheelIntent, HeldItemDrivesUse, DropThrowIntent, HeldItemHints
// |    |    |           (Mars_PlayerCharacter_Hfsm_Inventory.as / _Emotes.as / _Tasks.as), ClimberMountIntent (Tick:
// |    |    |           walking into a ladder zone mounts it), LocomotionSubSm
// |    |    |    exit:  a climbing climber dismounts (Lost): Downed and Operating both leave the ladder
// |    |    |    `- Loco sub-SM (initial = Idle): Idle / Walk / Sprint / Crouch / Jump / Airborne / Climb
// |    |    |         every state but Climb ->Climb [IsClimbing] first; Climb ->Airborne [IsFalling] ->Idle [IsNotClimbing]
// |    |    |         (Mars_PlayerCharacter_Hfsm_Locomotion.as)
// |    |    `- Operating    ->Locomotion [IsNotOperating]   (the player holds a station: Mars_PlayerCharacter_Hfsm_Operating.as)
// |    |         tasks: PoseLock (Tick), Camera, Grip, LeaveIntent, Hints; leaving it any other way releases the station
// |    `- Hands sub-SM (initial = Rest): Rest / Reach / Grip / Return / Hold / Release / Push (Script/ECS/FPHands/Mars_FPHands_Hfsm.as)
// `- Downed      ->Alive [IsNotDowned]
//
// A parent's transitions keep firing while any descendant is active, and leaving a parent tears
// down its subtree - so Alive->Downed interrupts any locomotion or operating state, and Locomotion->Operating tears down
// every free-roam task (focus cleared, intents closed, manipulation ended, hints unregistered) before the station's enter.

class UMars_SmCondition_IsDowned : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Player_Downed;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

class UMars_SmCondition_IsNotDowned : UMars_SmCondition_IsDowned
{
    default _NegateResult = true;
}

class UMars_SmTask_AliveSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Locomotion;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmTask_LocomotionSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Loco_Idle;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDowned = AddTransition(InHandle, UMars_SmState_Downed);
        AddCondition(ToDowned, UMars_SmCondition_IsDowned);

        AddTask(InHandle, UMars_SmTask_HotbarDrivesHeldItem);
        AddTask(InHandle, UMars_SmTask_AliveSubSm);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Alive", n"PlayerSM", 2.0f, FLinearColor(0.3f, 1.0f, 0.3f, 1.0f));
    }
}

class UMars_SmState_Downed : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAlive = AddTransition(InHandle, UMars_SmState_Alive);
        AddCondition(ToAlive, UMars_SmCondition_IsNotDowned);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Downed", n"PlayerSM", 2.0f, FLinearColor(1.0f, 0.3f, 0.3f, 1.0f));
    }
}

// The free-roam interaction mode: every task that turns input or the view trace into an interaction, an item use, an emote
// or a ladder mount. Operating replaces it wholesale, so none of them can fire while a station holds the player.
class UMars_SmState_Locomotion : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperating = AddTransition(InHandle, UMars_SmState_Operating);
        AddCondition(ToOperating, UMars_SmCondition_IsOperating);

        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
        AddTask(InHandle, UMars_SmTask_ManipulateControl);
        AddTask(InHandle, UMars_SmTask_HotbarIntents);
        AddTask(InHandle, UMars_SmTask_EmoteIntents);
        AddTask(InHandle, UMars_SmTask_EmoteWheelIntent);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesUse);
        AddTask(InHandle, UMars_SmTask_DropThrowIntent);
        AddTask(InHandle, UMars_SmTask_HeldItemHints);
        AddTask(InHandle, UMars_SmTask_ClimberMountIntent);
        AddTask(InHandle, UMars_SmTask_LocomotionSubSm);
    }

    // Leaving Locomotion while climbing (Downed, or a station's Operating) leaves the ladder: the Climber's drain runs next
    // frame and restores walking, so a Downed player falls out of Flying and an operator's glide follows.
    UFUNCTION(BlueprintOverride)
    void DoExitState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Climber = ck::Ctx(InHandle).As_Climber(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Climber) || Climber.Get_IsClimbing() == false)
        { return; }

        Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
    }
}
