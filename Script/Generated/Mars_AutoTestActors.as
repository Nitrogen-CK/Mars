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

class AMars_AutoTest_Anchor_ComposeAddsTagAndParams_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Anchor_ComposeAddsTagAndParams");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Anchor_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Anchor_SpecValidateRejectsBadSpecs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorCandidate_LeverGateOpensOnChannel_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorCandidate_LeverGateOpensOnChannel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorCandidate_OneSidedLeverGateOpensFromItsSide_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorCandidate_OneSidedLeverGateOpensFromItsSide");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorCandidate_RubbleStaysClosed_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorCandidate_RubbleStaysClosed");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorCandidate_WarrensRowsRespectRoleAndEligibility_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorCandidate_WarrensRowsRespectRoleAndEligibility");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorCandidate_WarrensScoutLatchSupportsSequentialAccess_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorCandidate_WarrensScoutLatchSupportsSequentialAccess");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_CacheBudget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_CacheBudget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_CapProtectsConnectivity_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_CapProtectsConnectivity");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_ClosureSetsKeepReachability_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_ClosureSetsKeepReachability");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_DivergenceOverHistory_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_DivergenceOverHistory");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_HistoryKeepsDepth_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_HistoryKeepsDepth");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_LateAnchorResolves_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_LateAnchorResolves");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_PickRow_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_PickRow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_PinnedRowWins_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_PinnedRowWins");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_PlanRejectsBadData_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_PlanRejectsBadData");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_PresetTablesCoverRoles_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_PresetTablesCoverRoles");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_QuarryRespectsMinWalk_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_QuarryRespectsMinWalk");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_SameSeedSameLedger_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_SameSeedSameLedger");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_SeedFromOptions_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_SeedFromOptions");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_SolveDeterministic_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_SolveDeterministic");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_StableHash_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_StableHash");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_WarrensChannelsDeclared_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_WarrensChannelsDeclared");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_WarrensDistances_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_WarrensDistances");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_WarrensLeverSides_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_WarrensLeverSides");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AnchorResolver_WarrensPlanValidates_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AnchorResolver_WarrensPlanValidates");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_AdmissionIsAsynchronous_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_AdmissionIsAsynchronous");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_AuthoringValidationParity_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_AuthoringValidationParity");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_CapabilityStateMatrix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_CapabilityStateMatrix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_DecisionHistory_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_DecisionHistory");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_EmitterEvidence_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_EmitterEvidence");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_FrozenClipSurface_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_FrozenClipSurface");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_LoadedLookCreatureDefaults_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_LoadedLookCreatureDefaults");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_NativeReceiptBacklog_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_NativeReceiptBacklog");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_PublicPoseSurface_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_PublicPoseSurface");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_SeedReferenceGraphs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 180.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_SeedReferenceGraphs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_SeverRecoveryEvidence_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_SeverRecoveryEvidence");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_ShippedReferenceGraphs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_ShippedReferenceGraphs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_StableSelection_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_StableSelection");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_AttackCatalog_ValidationRejectsWholeGraph_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_AttackCatalog_ValidationRejectsWholeGraph");
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

class AMars_AutoTest_Backpack_SpecValidateRejectsBadCargoSlots_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Backpack_SpecValidateRejectsBadCargoSlots");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_AdmissionAcceptsAWholeBatterablePiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_AdmissionRefusesACutPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_AdmissionRefusesACutPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_AdmissionRefusesAFullBowl_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_AdmissionRefusesAFullBowl");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_AdmissionRefusesAnAlreadyBatteredPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_AdmissionRefusesANonBatterableFood");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_ATakeOutRefusedByTheTrayIsReadopted_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_ATakeOutRefusedByTheTrayIsReadopted");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_SpecValidateRejectsBadSpecs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 45.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 45.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BatterStation_LeavingMidCoatKeepsTheBatch");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BatterStation_TheOperatorsPrimaryDipsAndLiftsTheBowl_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BatterStation_TheOperatorsPrimaryDipsAndLiftsTheBowl");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_ACommitEdgeIsJudgedOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_ACommitEdgeIsJudgedOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_OwnedPanelConstructsAndTearsDownItsVent_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_OwnedPanelConstructsAndTearsDownItsVent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_RecommitRestartsThePoweredBurst_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_RecommitRestartsThePoweredBurst");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_RightCommitPaysTheRemainingRewardsOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_RightCommitPaysTheRemainingRewardsOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_SolveCancelsADedicatedRestart_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_SolveCancelsADedicatedRestart");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_SolveSettlesAnUnreleasedDial_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_SolveSettlesAnUnreleasedDial");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_SpecValidation_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_SpecValidation");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_TeardownCancelsADedicatedRestart_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_TeardownCancelsADedicatedRestart");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_TeardownMidPulseLeavesNoVent_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_TeardownMidPulseLeavesNoVent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Bellkeeper_WrongCommitsVentAndCostRewardsDownToTheLast_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Bellkeeper_WrongCommitsVentAndCostRewardsDownToTheLast");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BodyPart_ADirectSeverSeversOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BodyPart_ADirectSeverSeversOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BodyPart_CrushRuinsAndSeverPreservesCondition");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 25.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BodyPart_DepletionSeversLegAndRagdollsParts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BodyPart_HitsToTheThresholdBreakOnce_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BodyPart_HitsToTheThresholdBreakOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_BodyPart_SpillDamagesBody_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_BodyPart_SpillDamagesBody");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Brain_FactsDriveLeaf_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Brain_FactsDriveLeaf");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Brain_LeafConditionDrivesStateMachine_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Brain_LeafConditionDrivesStateMachine");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Brain_SettledGoalSatisfies_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Brain_SettledGoalSatisfies");
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

class AMars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CargoSlot_AFoodItemStowsIntoThePackAndRidesIt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CargoSlot_FoodDoesNotDriveADroppedPack_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CargoSlot_FoodDoesNotDriveADroppedPack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CargoSlot_SpecValidateRejectsBadSlot_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CargoSlot_SpecValidateRejectsBadSlot");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Climber_LocomotionExitDismounts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Climber_LocomotionExitDismounts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Climber_MountClimbsAndTopsOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Climber_MountClimbsAndTopsOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Climber_TopMountNeedsDescentBeforeTopOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ARefusedReachBeginsTheManipulationAtOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ASharedKeyPressStartsOneInteraction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ASharedKeyPressStartsOneInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_FreeTurnHandsOutItsPullUntilRelease_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_FreeTurnHandsOutItsPullUntilRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_GripBegunManipulationEngagesAtThreshold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_HeldGripRocksInsideTheArcUntilRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ManipulationWaitsForTheGrip_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ManipulationWaitsForTheGrip");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_MomentaryReleasesAndReArms_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_MomentaryReleasesAndReArms");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_NoInteractionOutlivesAPulledGrip_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_NoInteractionOutlivesAPulledGrip");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PendingGripFreezesCamera_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PendingGripFreezesCamera");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PromptClearsWhenALetGoGripEnds_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PromptClearsWhenALetGoGripEnds");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PromptClearsWhenAPulledGripEnds_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PromptClearsWhenAPulledGripEnds");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PullDegreesFollowTheScreenTangent_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PullDegreesFollowTheScreenTangent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PullFromActiveTowardStartEngagesOff_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PullFromActiveTowardStartEngagesOff");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_PullPastEngageAlphaEndsTheInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ReleaseBeforeEngageAlphaSettlesBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ReturnsToRestPullSpringsBackAndPullsAgain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_SpecValidateRejectsMismatchedPolicies");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ThresholdInteractionFailingSettlesBack_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ThresholdInteractionFailingSettlesBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Control_ViewStaysHeldUntilUseReleases_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Control_ViewStaysHeldUntilUseReleases");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ACancelPastTheGraspIsANoOp");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AFreshPressAfterReturnStartsTheNextAndSixAdmitSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AnAdmissionAnswersThroughTheOneSignal");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AnUnansweredAdmissionSettlesRejectedWithinTheBudget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AnUndockDuringAwaitAdmissionReturnsThePiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ARefilledSourceNeverReusesAPieceId");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ARejectedPieceWithNoPlatterLeftIsLetGo_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ARejectedPieceWithNoPlatterLeftIsLetGo");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ARejectedReleaseReturnsToThePlatterItCameFrom");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AReleaseLandsInTheStationInbox");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_AReservedPieceTakenOffThePlatterCancelsTheTransfer");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ChangingTheSourceCancelsAndUnsourcedIsEmpty");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_DestroyingTheStationMidTransferLeaksNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_RejectedAdmissionRestoresTheSlotAndTheHandReturns");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_ResetAtEveryPhaseLeavesTheStockOnThePlatter");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_SixPressesDuringOneTransferAdmitOnePiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_StaleAndDuplicateAcknowledgementsSpendNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_TheKernelMovesTheHandNode_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_TheKernelMovesTheHandNode");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CookingFeed_TheReleaseSampleFollowsTheMovingNodeAndInheritsItsVelocity");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Countdown_ChargeDrainsOneStepAtATime_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Countdown_ChargeDrainsOneStepAtATime");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Countdown_HoldWhilePoweredStaysFullThenDrains");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Countdown_RechargeWhileDrainingRefills_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Countdown_RechargeWhileDrainingRefills");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Countdown_SinkEdgeChargesAndSourceFollows");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Countdown_SpecValidateRejectsEmptyOrTimeless");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_ComposesWalkerPartsAndMonster_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_ComposesWalkerPartsAndMonster");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_CrippledCowers_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_CrippledCowers");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_DamageFlinchesThenResumesRoam_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_DamageFlinchesThenResumesRoam");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_DeathDetachesLegsAndDespawns_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_DeathDetachesLegsAndDespawns");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_RoamsWithinBounds_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_RoamsWithinBounds");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Crawler_StrikeSeversLegEndToEnd_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Crawler_StrikeSeversLegEndToEnd");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_AcquireAndLeash_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 80.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_AcquireAndLeash");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ActionScopeLoss_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ActionScopeLoss");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_AggressionToggle_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 50.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_AggressionToggle");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ApproachAndPrepare_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ApproachAndPrepare");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_BlockedRoute_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 70.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_BlockedRoute");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CancelBeforeCommit_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CancelBeforeCommit");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CancelReturnsThroughAction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CancelReturnsThroughAction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogAcquisitionConflict_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogAcquisitionConflict");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCues_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCues");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesActionLoss_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesActionLoss");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesCustomEmpty_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesCustomEmpty");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesCustomProfile_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesCustomProfile");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesJabEmpty_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesJabEmpty");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesJabProfile_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesJabProfile");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogCuesPincerCancel_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogCuesPincerCancel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogDisableBeforeAdmission_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogDisableBeforeAdmission");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogExplicitGrace_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogExplicitGrace");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogFrozenAttempt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogFrozenAttempt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogLeastRecent_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogLeastRecent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogNoCapability_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogNoCapability");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogParity_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogParity");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogParityRadialFour_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogParityRadialFour");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogParityRadialSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogParityRadialSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogProcessedSever_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogProcessedSever");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogSeverBeforeCandidateCommit_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogSeverBeforeCandidateCommit");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogSeverInRecover_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogSeverInRecover");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogSeverInWindup_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogSeverInWindup");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogTokensAndFallback_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogTokensAndFallback");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_CatalogZeroDelta_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_CatalogZeroDelta");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ClipDrivesPhases_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ClipDrivesPhases");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_Displacement_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_Displacement");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_DodgeCommitment_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_DodgeCommitment");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointAnatomy_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointAnatomy");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointAnatomyLeftOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointAnatomyLeftOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointAnatomyNeither_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointAnatomyNeither");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointAnatomyRightOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointAnatomyRightOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysics_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysics");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsDamageClosure_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsDamageClosure");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsDual_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsDual");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsDualReversed_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsDualReversed");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsFinalCandidateCancel_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsFinalCandidateCancel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsHitch_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsHitch");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsMiss_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsMiss");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterBystander_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterBystander");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterWall_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointPhysicsOtherEmitterWall");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialFour_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialFour");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteRadialSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteSpiderSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftCompleteSpiderSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialFour_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialFour");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftRadialSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleLeftSpiderSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleLeftSpiderSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleReturns_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleReturns");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialFour_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialFour");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleRightCancelRadialSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleRightCancelSpiderSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleRightCancelSpiderSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleRightRadialSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleRightRadialSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EndpointSingleRightSpiderSix_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EndpointSingleRightSpiderSix");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EngagesAndRetries_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 70.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EngagesAndRetries");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_EveryExit_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_EveryExit");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_HitchAndZeroTime_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_HitchAndZeroTime");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_HitExactlyOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 70.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_HitExactlyOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_InterruptPriority_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 120.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_InterruptPriority");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_JabThenWalks_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_JabThenWalks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_MissAndCooldown_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_MissAndCooldown");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_Obstruction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_Obstruction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_OffenseWindowFromReceipt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_OffenseWindowFromReceipt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PassiveAndNetworkGate_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PassiveAndNetworkGate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PhaseSequence_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PhaseSequence");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerCancelledInTheAirThenWalks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerClawSeveredMidStrike_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerClawSeveredMidStrike");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerKeyValidation_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerKeyValidation");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerNeedsBothClaws_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerNeedsBothClaws");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerStrike_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerStrike");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerStrikeSixLegs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerStrikeSixLegs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerStrikeSpider_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerStrikeSpider");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerThenWalks_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerThenWalks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerThenWalksSixLegs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PincerThenWalksSpider_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 90.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PincerThenWalksSpider");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_PrepareTimeout_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_PrepareTimeout");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_QueryPrimitives_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_QueryPrimitives");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ShippedClipsLoad_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ShippedClipsLoad");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ShunsAHeldLitLantern_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ShunsAHeldLitLantern");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_StaleGeneration_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_StaleGeneration");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_StartRejectionsNameTheBlocker_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_StartRejectionsNameTheBlocker");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_StationaryFacing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_StationaryFacing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_TerminalStrikeHit_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_TerminalStrikeHit");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CrawlerMelee_ZeroDeltaClocksHold_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CrawlerMelee_ZeroDeltaClocksHold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cutting_ChopWhileChoppingIsIgnored_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cutting_ChopWhileChoppingIsIgnored");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cutting_ResetCentresTheHandAndKeepsAChopInFlight_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cutting_ResetCentresTheHandAndKeepsAChopInFlight");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cutting_TheChopClockIsTheKernels_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cutting_TheChopClockIsTheKernels");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_ABusyBoardSaysSo_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_ABusyBoardSaysSo");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AChopCutsEveryPieceItStraddles");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_ACrossCutAfterATurnPartsAcrossTheFirstCut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AddFoodLandsTheJointWhenTheOperatorLeavesInTheReleaseFrame");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_AJointOnTheBoardCannotBePickedUp");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_ASweepRefusedByAFullTrayReplacesThePieces");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_ChopsCutTheJoint_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_ChopsCutTheJoint");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_InputDockRefusesACutPlatter");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_InputDockTakesWholeMeatOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_LeaveMidCutKeepsTheHalvesForTheNextOperator");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_MeatCutCostIsMeasured_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_MeatCutCostIsMeasured");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_SweepHandsPiecesToTheTray");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_SweepingTheBoardEmptyTakesTheNextJoint");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_SweepLeavesWhatTheTrayCannotTake");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_TheOperatorsKeysChopTurnAndSteerTheHand_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_TheOperatorsKeysChopTurnAndSteerTheHand");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_CuttingStation_TurnYawsTheBoardsPiecesAboutThePile");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cycle_RunsItsPhasesInOrderAndStopsAtTheEnd_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cycle_RunsItsPhasesInOrderAndStopsAtTheEnd");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Cycle_StopKeepsThePhaseAndAStartReentersPhaseZero_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Cycle_StopKeepsThePhaseAndAStartReentersPhaseZero");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_DamageDealer_ADisabledZoneRejects_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_DamageDealer_ADisabledZoneRejects");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_DamageDealer_FriendlyFireRejected_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_DamageDealer_FriendlyFireRejected");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_DamageDealer_ResolvesHurtboxToZone_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_DamageDealer_ResolvesHurtboxToZone");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_DamageDealer_ShapeTraceFindsSilentHurtbox");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_DamageDealer_SweepIgnoresOwnHurtboxes");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Devour_ACancelOrALostVictimEndsTheRunCancelled_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Devour_ACancelOrALostVictimEndsTheRunCancelled");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Devour_ADestroyedDevourerFreesItsVictim_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Devour_ADestroyedDevourerFreesItsVictim");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Devour_ASecondBeginWhileHoldingIsIgnored_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Devour_ASecondBeginWhileHoldingIsIgnored");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Devour_RunsEveryPhaseInOrderAndLetsGo_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Devour_RunsEveryPhaseInOrderAndLetsGo");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Devour_SpecValidateRejectsAPhaseWithNoTime_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Devour_SpecValidateRejectsAPhaseWithNoTime");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Dial_LockDropsStepsUntilUnlocked_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Dial_LockDropsStepsUntilUnlocked");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Dial_SpecValidation_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Dial_SpecValidation");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Dial_StepsWrapBothWaysWithOneBroadcastPerDrain_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Dial_StepsWrapBothWaysWithOneBroadcastPerDrain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Dial_TurnFollowsAndSettlesOnTheNearestDetent_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Dial_TurnFollowsAndSettlesOnTheNearestDetent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Emote_TagsMapToEveryEmoteAndBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Emote_WheelEntryNChoosesEmoteN_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Emote_WheelEntryNChoosesEmoteN");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_EmoteWheel_CancelOverAnEntryChoosesNothing_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_EmoteWheel_CancelOverAnEntryChoosesNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_EmoteWheel_OpenHoverChooseClose_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_EmoteWheel_OpenHoverChooseClose");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_EmoteWheel_SectorMathAndSpec_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_EmoteWheel_SectorMathAndSpec");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_ApplyWritesComponentPlate_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_ApplyWritesComponentPlate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_ApplyWritesPlate_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_ApplyWritesPlate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_ApplyWritesTheSameFrame_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_ApplyWritesTheSameFrame");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_BlinkCountsAtFixedInterval_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_BlinkCountsAtFixedInterval");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_EmoteOverStateLayer_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_EmoteOverStateLayer");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_ExpressionOverridesThenExpires_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_ExpressionOverridesThenExpires");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_ExpressionSuppressesBlink_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_ExpressionSuppressesBlink");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_LookFollowsGaze_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 14.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_LookFollowsGaze");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_LookMasterResolves_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_LookMasterResolves");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_LookMatchesMaterialSlots_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_LookMatchesMaterialSlots");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_OneEyeEmoteKeepsStateOnOtherEye");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_RetargetMidFadeKeepsDominantCell");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_StateSuppressesBlinkUnderEmote");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Eyes_WinkKeepsOneEye_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Eyes_WinkKeepsOneEye");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_EyesDummy_ComposesAndWrites_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_EyesDummy_ComposesAndWrites");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_AnUnlimitedFlameNeverGuttersAndCannotRefuel_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_AnUnlimitedFlameNeverGuttersAndCannotRefuel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_ASnuffsFlameGoesOutWhenStowedAndStaysOutWhenSelected_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_ASnuffsFlameGoesOutWhenStowedAndStaysOutWhenSelected");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_AStaysLitFlameKeepsBurningOnTheBeltAndSwapsToItsStowedProbe_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_AStaysLitFlameKeepsBurningOnTheBeltAndSwapsToItsStowedProbe");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_BurnsOnlyWhileLitThenGuttersAndGoesOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_BurnsOnlyWhileLitThenGuttersAndGoesOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_RefuelCapsAndRelightsInOneFrame_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_RefuelCapsAndRelightsInOneFrame");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Flame_SpecValidateRejectsBadFuelRadiiAndBornSpent_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Flame_SpecValidateRejectsBadFuelRadiiAndBornSpent");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_AChopAfterAWaitingTurnWaitsForIt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_CutReplacesHeldAndSeparatesHalves");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_CutTargetsOnlyStraddlingPiecesWithinBudget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_DestroyingBoardDestroysHeldOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_DrainsTheInboxAsPlace_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_DrainsTheInboxAsPlace");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_FullBoardOnlyKnocks_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_FullBoardOnlyKnocks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_HandoffReleaseLeavesNoBodyAndStopsAtMaxPieces");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_KinematicBodiedJointIsPlacedAndCut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_PartingKeepsEveryGap_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_PartingKeepsEveryGap");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_PlaceRefusesPastLimitDuplicateAndForeign");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_RotatedPieceCutsThroughItsCentre");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_SpecValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_TurnWaitsForTheInFlightCut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodBoard_TwoTurnsInOneDrainCompose");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_ABatteredVariantIsOptionalAndValidated");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_ACookStateSentMidCutReachesTheHalves_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_ACookStateSentMidCutReachesTheHalves");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_BatteredSurvivesACut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_BatteredSurvivesACut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_CentreCutConservesMassAndLineage");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_FullQueueRejectsWithoutRetry");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_GrazeIsTouchingOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_GrazeIsTouchingOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_HalvesSurviveGarbageCollectionAndRecut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_ImportReadyRecordsVolume_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_ImportReadyRecordsVolume");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_KindAndDefinitionFollowTheCut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_MeatSlabCutsIntoConservedPortions");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_MissLeavesSourceUsable_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_MissLeavesSourceUsable");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_OffCentreCutIsProportionalToVolume");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_OneHolderPerPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_OneHolderPerPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_SecondCutWhileCuttingIsRefusedBusy");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_SetCookStateAppliesBeforeACutInTheSameDrain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_SourceDestroyedWhilePendingCommitsNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_SpecValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FoodPiece_TooSmallPortionIsRejected_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FoodPiece_TooSmallPortionIsRejected");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_CenserSpillsPerHitThenRefills_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_CenserSpillsPerHitThenRefills");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_DestroyedTearsDownPlainHost_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_DestroyedTearsDownPlainHost");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_ExhaustedRegrows_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_ExhaustedRegrows");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_HuskWorldItemCracksIntoKernel_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_HuskWorldItemCracksIntoKernel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_RegrowEndingDuringTeardownIsQuiet_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_RegrowEndingDuringTeardownIsQuiet");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_ReleasesPerRequestThenExhausts_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_ReleasesPerRequestThenExhausts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_SpecValidateRejectsBadSpecs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_VineKnockFromThrownItemReleases_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_VineKnockFromThrownItemReleases");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Forage_VineStrikeDepletesThenRegrows_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Forage_VineStrikeDepletesThenRegrows");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_AHoldWhoseTargetDiesReleases");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_AOneHandedHoldKeepsBothGlovesWhereTheyRested_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_AOneHandedHoldKeepsBothGlovesWhereTheyRested");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_APlaceReachCarriesATwoHandedHoldToTheTarget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_EquippingReResolvesTheFocusLean_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_EquippingReResolvesTheFocusLean");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_FocusedInteractableDestroyedClearsLean");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_FocusMovingBetweenTargetsEasesTheOldLeanOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_FocusMovingBetweenTargetsEasesTheOldLeanOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_GripRotationPutsTheIndexSideWhereTheHandSays");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_InstantReachRunsReachGripReturnToNone");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_LookingUpLeavesTheGlovesLow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_PitchSpecRejectsFollowOutsideZeroToOne");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_PushRunsToNoneFromTheLaunchHold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_ReachOverrideExtendsPastMaxReach");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_ReleaseQueuedWithHoldLetsGo");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_RestGripsMatchTheReadyPose_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_RestGripsMatchTheReadyPose");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_RestResyncsToLiveTimedInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_SocketGripFollowsMovingPart_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_SocketGripFollowsMovingPart");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_SpecRejectsBadInput_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_SpecRejectsBadInput");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_SubSmExitResetsToNone_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_SubSmExitResetsToNone");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_TargetLostDuringHoldReleasesFromCurrentAlpha");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_TimedReachHoldsUntilRelease_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_TimedReachHoldsUntilRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_UnfocusEasesTheLeanOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_UnfocusEasesTheLeanOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FPHands_ViewerFacingGripTakesTheBarFromThePlayersSide");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ABatteredWholePieceFriesGolden_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ABatteredWholePieceFriesGolden");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ADippedScoopCannotLeaveThePot");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AdmissionRefusesAnUnbatteredPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AdmissionRejectsASeventhPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AdmissionRejectsASeventhPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ADrainedPieceKnockedOutIsNoLongerDrained");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_APieceOnAnotherPieceDrains_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_APieceOnAnotherPieceDrains");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_APieceThatNeverStillsDrainsAtTheBudget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_APourInTheCorridorIsIgnored_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_APourInTheCorridorIsIgnored");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AReadoptedPieceIsAnnouncedAgain_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AReadoptedPieceIsAnnouncedAgain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_AResetRejectsAnAddPieceInTheSameDrain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ASearedPieceRetargetsItsResting_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ASearedPieceRetargetsItsResting");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_DrainsTheInboxAsAddPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_DrainsTheInboxAsAddPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_SpecValidateRejectsBadSpecs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_TakeOutWritesOilCoat_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_TakeOutWritesOilCoat");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Fry_WhereaboutsFollowTheGeometry_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Fry_WhereaboutsFollowTheGeometry");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_APlatterSourcedPieceDrainsAndIsTakenOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_ATakeOutRefusedByTheTrayIsReadopted");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_ATakeOutThroughTheIntentIsCappedByTheTray");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_BatterHeatReachesThePieceDisplay");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_LeavingDuringCarryStillAdmits");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_TakeOutLoadsTheTray_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_TakeOutLoadsTheTray");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_FryStation_TheOperatorsKeysDriveTheSkimmer");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gate_ThresholdDefersCloseUntilClear_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gate_ThresholdDefersCloseUntilClear");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gate_UnsourcedSinkClosesStartOpenGate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gaze_HysteresisHoldsTarget_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gaze_HysteresisHoldsTarget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gaze_IgnoresOutOfRangeAndBehind");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gaze_NeverTargetsOwnOwner_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gaze_NeverTargetsOwnOwner");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gaze_PicksNearestInCone_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gaze_PicksNearestInCone");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Gaze_TargetDestroyedClears_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Gaze_TargetDestroyedClears");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HandSwing_StartRequestValidates_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HandSwing_StartRequestValidates");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HandSwing_StartRunsWindupStrikeRecoverToNone");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HangingChain_ARackHangsItsRowOnHooksAndChains_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HangingChain_ARackHangsItsRowOnHooksAndChains");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HangingChain_CatenaryLaysLinksAndSags");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hazard_ArmingHitsWhatIsAlreadyInside_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hazard_ArmingHitsWhatIsAlreadyInside");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hazard_LatestArmRequestWinsAndOnlyAChangeBroadcasts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hazard_LatestArmRequestWinsAndOnlyAChangeBroadcasts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hazard_TwoHazardsOnOneTriggerEachHitOnce_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hazard_TwoHazardsOnOneTriggerEachHitOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Health_DamageLowersCurrentAndSignals_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Health_DamageLowersCurrentAndSignals");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Health_DepletionLatchesOnceForSameFrameLethalHits");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Health_HealRaisesCurrentAndClampsAtMax");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Health_InvulnerableIgnoresDamage_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Health_InvulnerableIgnoresDamage");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HeldItem_SpawnFromWinsOverArrivalAndClearDropsIt_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HeldItem_SpawnFromWinsOverArrivalAndClearDropsIt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HeldItem_SyncsFromTheHotbarWithoutATask");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HeldItemUse_DropAndThrowInOneDrainLaunchOnce_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HeldItemUse_DropAndThrowInOneDrainLaunchOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HeldView_ItemSitsAtTheRightPalm_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HeldView_ItemSitsAtTheRightPalm");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HeldView_MakeMatchesFPHold_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HeldView_MakeMatchesFPHold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HitZone_DisabledZoneIgnoresHits_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HitZone_DisabledZoneIgnoresHits");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_HitZone_HitScalesByReactionAndForwardsToHealth");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_AStowWhileHoldingKeepsTheSelection");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_AStowWithNoSelectionSelectsTheSlot");
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

class AMars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_SelectionChangesApplyInArrivalOrder");
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

class AMars_AutoTest_Hotbar_SpecValidateRejectsBadBagSlotCount_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Hotbar_SpecValidateRejectsBadBagSlotCount");
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

class AMars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_ATiltTargetCanBeSetWithoutALook");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_CommandedLiftFollowsTheLookAndHolds");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_FastUpwardLookKicksTheLiftAndItSettles");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_LiftKickFiresAfterThePoseWrite_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_LiftKickFiresAfterThePoseWrite");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_LookSteersTheTiltAndItLevelsOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_OrbitSwirlsTheNodeWhileDrivenAndEasesOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 6.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_PitchAndYawHoldsWhileDrivenAndParksWhenIdle");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_SlideFollowsTheLookAndALiftTargetCanBeSet");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Implement_SpecValidateRejectsBadTilts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Implement_SpecValidateRejectsBadTilts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_InputIntents_LookDeltaSequenceAdvancesPerDrain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_InputIntents_MoveDirectionLatestWinsAndMatcherChangesSignal_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_InputIntents_MoveDirectionLatestWinsAndMatcherChangesSignal");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_ACancelledInteractionStopsTheSubSm");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_AWhileLiveTargetTakesOneInteractionAtATime");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_FocusChangesApplyInArrivalOrder");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_FreeHandsTargetRejectsAFullHand");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_FullHandsBlockFocusedPromptAndLetGo");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_InteractingEntersFromIdleOnALiveInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Interactable_TheInitiatorComesFromTheLiveInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_InteractPromptDisplay_RefreshAndNonTopRemoval_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_InteractPromptDisplay_RefreshAndNonTopRemoval");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_KeyLock_KeptKeyUnlocksForGood_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_KeyLock_KeptKeyUnlocksForGood");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_KeyLock_RemovableKeyRelocks_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_KeyLock_RemovableKeyRelocks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_KeyLock_SpecValidateRejectsMissingParts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_KeyLock_SpecValidateRejectsMissingParts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_KeyLock_TwoKeysOpenOneGate_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_KeyLock_TwoKeysOpenOneGate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_KeyLock_WrongKeyIsBlocked_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_KeyLock_WrongKeyIsBlocked");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Ladder_SpecValidateRejectsBadDimensions_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Ladder_SpecValidateRejectsBadDimensions");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_LanFlow_DirectAddressValidation_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_LanFlow_DirectAddressValidation");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_LanternHook_ALitLanternAssertsItsSourceAndTakesTallow_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_LanternHook_ALitLanternAssertsItsSourceAndTakesTallow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_LanternHook_HangsAHeldLanternAndLightsItsWorldPool_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_LanternHook_HangsAHeldLanternAndLightsItsWorldPool");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_LanternHook_SpecValidateRejectsMissingParts_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_LanternHook_SpecValidateRejectsMissingParts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Monster_BodyDepletionSetsDeadAndSignals");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Monster_RegisterPartTalliesOnce_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Monster_RegisterPartTalliesOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_AHitOnTheMarkerCrushesAndAMissDoesNot_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_AHitOnTheMarkerCrushesAndAMissDoesNot");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_CollectTalliesADoneBatchOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_CollectTalliesADoneBatchOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_DisengageDropsTheStrikeInFlight_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_DisengageDropsTheStrikeInFlight");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_GrindFillsOnlyWhileHeldAndIdle_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_GrindFillsOnlyWhileHeldAndIdle");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_SpecValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_SpecValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_SwitchSeasoningOnlyOnAFreshBatch_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_SwitchSeasoningOnlyOnAFreshBatch");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mortar_TheLastHitOpensTheGrind_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mortar_TheLastHitOpensTheGrind");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Mover_ScrubStopsTheTweenAndSettleReturns");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Occupancy_ReentryDuringDelayCancelsRelease_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Occupancy_ReentryDuringDelayCancelsRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Occupancy_ReleaseDelayStartsOneTimerThatLaterExitsDoNotExtend_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Occupancy_ReleaseDelayStartsOneTimerThatLaterExitsDoNotExtend");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Occupancy_RequiredCountActivatesAndMovesTheMover_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Occupancy_RequiredCountActivatesAndMovesTheMover");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Occupancy_TwoOccupanciesShareOneTrigger_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Occupancy_TwoOccupanciesShareOneTrigger");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Pendulum_BrakingSwingKeepsItsHazardArmedUntilCaught_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Pendulum_BrakingSwingKeepsItsHazardArmedUntilCaught");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Pendulum_SinkPowerGatesTheSwing_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Pendulum_SinkPowerGatesTheSwing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_ADroppedPieceSettlesFreezesAndRidesTheTray");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AFoodTakenByTheGlovesWhileSettlingIsNotPulledBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AFoodTakenWhileSettlingIsNotPulledBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AMovingTrayDropsNothing_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AMovingTrayDropsNothing");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AnEscapeWhileTheTrayMovesWaitsForStillness");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_AStillMovingPieceFreezesAtMaxSeconds");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_DepositIsBlockedWhenFull_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_DepositIsBlockedWhenFull");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_DepositPlacesTheHeldFoodAndPickupTakesItBack");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_FullRefusesTheNext_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_FullRefusesTheNext");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_LoadedBodyGoesKinematicAndRides");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_LoadRefusesADuplicate_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_LoadRefusesADuplicate");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_LoadRefusesAForeignPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_LoadRefusesAForeignPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_LoadRefusesAFullPlatter_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_LoadRefusesAFullPlatter");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_LoadRefusesAPieceBeingCut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_LoadRefusesAPieceBeingCut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_PlaceHeldFoodFailsWhenThePieceDiesWhileLeaving_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_PlaceHeldFoodFailsWhenThePieceDiesWhileLeaving");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_SpecValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_SpecValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_UnloadResettlesTheRest_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_UnloadResettlesTheRest");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Platter_WorldItemCarriesItsPiecesThroughStowHoldAndRelease");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_APolicyCountsQueuedAndSettlingPieces");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_CuttingFeedSourcesAPlatterDockedInFlightOnArrival");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_DockFromTheHandIsOneCarryAndTakeIsOneHold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_DocksAWorldPlatterAndUndocksIntoTheOverflow");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_OnArrivedFollowsOnMountSettled");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_SpecValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_SpecValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlatterDock_TakeReachesWithBothGloves_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlatterDock_TakeReachesWithBothGloves");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_AFocusedLiveInteractionIsPinned_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_AFocusedLiveInteractionIsPinned");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_AHeldRowAtEntryIsNotAPress");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_AHeldUseDoesNotCarryToTheNextBestTarget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_APressDuringAPushStillReaches_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_APressDuringAPushStillReaches");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_FocusTakesTheNearestHitAndNestedPriorityOnly");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_LocomotionSpeedSprintMultipliesOnceAndWalkRemovesIt_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_LocomotionSpeedSprintMultipliesOnceAndWalkRemovesIt");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Player_PrimaryPrefersTheFocusedPromptOverTheHeldItemsUse_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Player_PrimaryPrefersTheFocusedPromptOverTheHeldItemsUse");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_PlayerViewpoint_EachHolderKeepsItsOwnHold_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_PlayerViewpoint_EachHolderKeepsItsOwnHold");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Resting_BoxOnAKinematicPlateRestsHopsAndSleeps");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Resting_SpecValidateRejectsNoTarget_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Resting_SpecValidateRejectsNoTarget");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Resting_TwoTargetsAreToldApart_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Resting_TwoTargetsAreToldApart");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Searing_SpecValidateRejectsBadPans_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Searing_SpecValidateRejectsBadPans");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Sequence_StepTimeoutResetsProgress_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Sequence_StepTimeoutResetsProgress");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Sequence_UnlatchedPulseEndsAndResets_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Sequence_UnlatchedPulseEndsAndResets");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Sequence_WrongInputResetsThenTheRightOrderCompletes_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Sequence_WrongInputResetsThenTheRightOrderCompletes");
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

class AMars_AutoTest_Station_AHolderReReservingIsANoOp_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_AHolderReReservingIsANoOp");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_AnOperatorReservesThroughTheUseInteraction");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_AReserveWhoseGripNeverLandsGivesUp");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_AUseWithFullHandsLeavesTheStationFree");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_BackLeavesTheStation_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_BackLeavesTheStation");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_DockMarkerIsHostedUnderTheDock_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_DockMarkerIsHostedUnderTheDock");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_OperatorDestroyedReleases_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_OperatorDestroyedReleases");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_ReserveRejectsSecondOperator_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_ReserveRejectsSecondOperator");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_ReserveWhileOperatingElsewhereRejected");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_ScopedReleaseKeepsHolder_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_ScopedReleaseKeepsHolder");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_StationDestroyedReleasesTheOperator_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_StationDestroyedReleasesTheOperator");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Station_ViewLocalMakesAViewNode_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Station_ViewLocalMakesAViewNode");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_GroundTraceReturnsOverridePhysMat");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_ImpactorOverrideWins_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_ImpactorOverrideWins");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_ResolveFallsBackExactParentDefault");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_ShippedTableValidatesAndLoads");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_ValidateRejectsInvalid_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_ValidateRejectsInvalid");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceFx_VariantByIntensity_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceFx_VariantByIntensity");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceNavigator_ProviderPathRoutesAroundWall");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceNavigator_SameFrameStopAndMoveToKeepArrivalOrder");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceNavigator_StopHaltsMovement_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceNavigator_StopHaltsMovement");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceNavigator_StraightLineArrives_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceNavigator_StraightLineArrives");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_SurfaceNavigator_StuckBehindWallFails_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_SurfaceNavigator_StuckBehindWallFails");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TPBody_ConfiguredBodyValidates_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TPBody_ConfiguredBodyValidates");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TPBody_HoldSpecValidates_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TPBody_HoldSpecValidates");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TPBody_SwingMovesTheHoldFrame_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TPBody_SwingMovesTheHoldFrame");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Trap_PhasesDriveTheMoverAndTheHazard_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Trap_PhasesDriveTheMoverAndTheHazard");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Trap_PoweredSinkSuppressesTheCycleAndResets_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Trap_PoweredSinkSuppressesTheCycleAndResets");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Trigger_CountsEachEntryAndExitOfAMovingOccupant_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Trigger_CountsEachEntryAndExitOfAMovingOccupant");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AdmissionNeedsTheHatchOpen");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AdmissionRefusesADuplicateAndAFullDrum");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AHeldGripRocksInsideTheArcAndNeverCompletes");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AnAdoptedPieceIsTheOneReleased");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AnEscapedPieceIsReseatedInsideTheDrum");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AReadoptPutsThePieceBackOnTheBooks_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AReadoptPutsThePieceBackOnTheBooks");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_AResetDestroysEveryPiece_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 10.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_AResetDestroysEveryPiece");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_ATakeOutWritesCrumb_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_ATakeOutWritesCrumb");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_CoverageGrowsOnlyWithPieceMotionAndNeverFalls");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 15.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_LeavingCancelsTheGripAndKeepsTheBatch");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_SpecValidateRejectsBadSpecs");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 12.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_Tumbler_TheHatchTogglesOnlyAtHomeAndSettled");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TumblerStation_APlatterSourcedPieceTumblesAndIsTakenOut");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_TumblerStation_LeavingMidGripSendsTheDrumHome_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 60.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_TumblerStation_LeavingMidGripSendsTheDrumHome");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AFoodItemStowsToABagSlotAndIsHeldWhenSelected");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AGripTakenMountArrivesWithTheGlovesReturn");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AHotbarGateCannotReenableALedgerHeldPickup");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AnItemWhoseCarrierDiesEndsItself");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AnItemWhoseHolderDiesEndsItself");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_APickupWaitsForTheGrip_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_APickupWaitsForTheGrip");
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

class AMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_OnMountSettledFiresOnceAtTheEndOfTheArrival");
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
    default _TimeoutSeconds = 20.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_PickupStows");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_SpecValidateRejectsMixedModes_Actor : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_SpecValidateRejectsMixedModes");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

class AMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 40.0f;
    UFUNCTION(BlueprintOverride)
    TSubclassOf<UCk_EntityScript_UE> Get_TestEntityScriptClass() const
    {
        auto Path = FSoftClassPath("/Script/Angelscript.Mars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory");
        TSubclassOf<UCk_EntityScript_UE> ResolvedClass;
        ResolvedClass = Path.TryLoadClass();
        return ResolvedClass;
    }
}

#endif // EDITOR
