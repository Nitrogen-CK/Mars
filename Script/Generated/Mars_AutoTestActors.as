// Auto-generated AutoTest actor wrappers - DO NOT EDIT.
// Regenerated on editor startup and after every AngelScript recompile.
//
// =====================================================================
// WHY DO THESE WRAPPERS LOOK SO WEIRD?
// =====================================================================
//
// You'd normally write a wrapper like this - short, type-safe:
//
//   class A<TestName>_Actor : ACk_AutoTestRunner
//   {
//       default _TestEntityScriptClass = U<TestName>;   // compile-time ref
//   }
//
// We don't, because that compile-time reference creates a deadlock when
// the entity-script .as file is deleted while the editor is running:
//
//   1. AS file watcher misses the delete for one cycle.
//   2. Generator emits a wrapper still referencing U<TestName>.
//   3. AS recompiles the generated file -> fails because U<TestName> is
//      gone -> PostCompile stops firing -> generator can't fix the file
//      it just emitted. Editor stays broken until manual recovery.
//
// The runtime-resolved form below sidesteps the deadlock: the entity-
// script class is referenced as a string literal inside an override of
// Get_TestEntityScriptClass, looked up at runtime via FSoftClassPath.
// AS doesn't resolve the string at compile time, so the wrapper compiles
// regardless of whether U<TestName> exists. If it's gone, the lookup
// returns null and the test reports a clear runtime failure; one sync
// pass later the wrapper is removed entirely. Self-healing.
//
// =====================================================================
// HAND-AUTHORED OPT-OUT
// =====================================================================
//
// For tests that need a custom _TimeoutSeconds or any other wrapper
// customization, hand-author your own A<TestName>_Actor class anywhere
// OUTSIDE Script/Generated/ using the simpler compile-time form:
//
//   class A<TestName>_Actor : ACk_AutoTestRunner
//   {
//       default _TestEntityScriptClass = U<TestName>;
//       default _TimeoutSeconds = 2.0f;
//   }
//
// The generator detects hand-authored wrappers by class name + source
// path and skips emission for that test, leaving yours authoritative.
// (Hand-authored wrappers don't carry the deletion-race risk because
// deleting the .as file removes BOTH classes atomically - no stale
// generated file to get out of sync.)

#if EDITOR

class AMars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_ActionHintDisplay_RegisterUnregisterByOwner");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_ActionHintDisplay_SuppressIsRefCounted_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_ActionHintDisplay_SuppressIsRefCounted");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_ActionHintDisplay_UnregisterDestroysRow_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_ActionHintDisplay_UnregisterDestroysRow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_ActionHintDisplay_UpdateBroadcastsOnlyOnChange");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Backpack_CargoStowThenTake_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Backpack_CargoStowThenTake");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CampSession_PlayBroadcastsOnceLobbyToLive");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CampSession_PlayTransitionsToLive_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CampSession_PlayTransitionsToLive");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CampSession_PlayWhileLiveIsIgnored_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CampSession_PlayWhileLiveIsIgnored");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CampSession_StartLiveSpecIsLive_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CampSession_StartLiveSpecIsLive");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_ConsumingSelectedKeepsSelection");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_LeavingOverflowParksSelection_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_LeavingOverflowParksSelection");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_SelectTogglesAndCycleSkipsOverflow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_SlotItemChangedBroadcasts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_SlotItemChangedBroadcasts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_StowFillsBagThenOverflow_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_StowFillsBagThenOverflow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_StowTargetIsNoneWhenFull_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_StowTargetIsNoneWhenFull");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_TakeTargetPrefersSelectedEmptyBagSlot");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Smoke_Boots_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Smoke_Boots");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_ArrivalSettlesAtOffset_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_ArrivalSettlesAtOffset");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_PersistentCarryHoldRelease_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_PersistentCarryHoldRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_PickupStows_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_PickupStows");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

#endif // EDITOR
