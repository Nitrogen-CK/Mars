// Auto-generated multi-client AutoTest C++ stubs - DO NOT EDIT.
// Regenerated on editor startup and after every AngelScript recompile.
//
// =====================================================================
// WHAT IS THIS FILE?
// =====================================================================
//
// Each block below is the C++ orchestration glue for one AS-authored net
// test. The actual test body lives in the corresponding .as file under
// `Plugins/<X>/Script/Ck<Feature>/CkAutoTest_Net_*.as`. AS authors write
// one .as file - this generator produces the C++ stub from the AS class's
// CDO `_NetMode` default, choosing the Replicated- or Independent-mode
// shape automatically.
//
// `Replicated`-mode stubs spawn an `ACk_AutoTest_NetSubject` on the server
// then run the AS body on every world. `ServerAndClientsIndependent` stubs
// skip the spawn - the AS body operates on each world's TransientEntity
// without cross-world coordination.
//
// To author a new net test:
//   1. Drop a `Ck_AutoTest_Net_<Name>.as` under `Plugins/<X>/Script/Ck<Feature>/`.
//   2. Subclass `UCk_AutoTest_NetBase` (defaults to Replicated) or set
//      `default _NetMode = ECk_AutoTest_NetMode::ServerAndClientsIndependent;`
//      on a `UCk_AutoTest_Base` subclass.
//   3. Recompile AS - the generator emits the matching stub here on the
//      next PostCompile. No C++ edits required.
// =====================================================================

#include "Misc/AutomationTest.h"

#if WITH_EDITOR && WITH_DEV_AUTOMATION_TESTS

#include "Engine/World.h"

#include "CkTests/Net/CkAutoTest_NetSubject.h"
#include "CkTests/Net/CkNetAutomation_Common.h"

// --------------------------------------------------------------------------------------------------------------------

// Auto-generated from AS class Ck_AutoTest_Net_NetSpike_CrossActorHandleLateArrival (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_NetSpike_CrossActorHandleLateArrival = TEXT("/Script/Angelscript.Ck_AutoTest_Net_NetSpike_CrossActorHandleLateArrival");
    constexpr auto kTimeoutSeconds_NetSpike_CrossActorHandleLateArrival = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkNetSpikeNet_AS_NetSpike_CrossActorHandleLateArrival,
    "Ck.NetSpike.Net.AS_NetSpike_CrossActorHandleLateArrival",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkNetSpikeNet_AS_NetSpike_CrossActorHandleLateArrival::RunTest(const FString& Parameters)
{
    bSuppressLogErrors = true;
    bSuppressLogWarnings = true;

    constexpr auto NumPIEClients = 2;
    constexpr auto ExpectedTotalWorlds = 2;
    constexpr auto ReadyTimeoutSeconds = 30.0f;
    constexpr auto FramesAfterSpawn = 30;

    const auto MapPath = FString{TEXT("/Engine/Maps/Entry")};

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_StartPIEMultiClient(NumPIEClients, MapPath));
    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_WaitForPIEReady(ExpectedTotalWorlds, ReadyTimeoutSeconds));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunOnServer(
        FCk_NetAutoTest_ServerAction::CreateLambda([this](UWorld* InServer) -> void
        {
            auto SpawnInfo = FActorSpawnParameters{};
            SpawnInfo.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
            const auto SubjectClassPath = FSoftClassPath(TEXT("/Script/CkTests.Ck_AutoTest_NetSubject"));
            auto* SubjectClass = SubjectClassPath.TryLoadClass<ACk_AutoTest_NetSubject>();
            if (SubjectClass == nullptr)
            { AddError(TEXT("AS-test harness: failed to resolve NetSubject class via FSoftClassPath")); return; }
            auto* Subject = InServer->SpawnActor<ACk_AutoTest_NetSubject>(
                SubjectClass, FTransform::Identity, SpawnInfo);
            if (Subject == nullptr)
            { AddError(TEXT("AS-test harness: server-side SpawnActor returned null")); }
        })));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_TickWorlds(FramesAfterSpawn));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_NetSpike_CrossActorHandleLateArrival}, kTimeoutSeconds_NetSpike_CrossActorHandleLateArrival));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_EndPIE());

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_AssertCondition(this,
        FCk_NetAutoTest_Assertion::CreateLambda([]() -> bool
        {
            FAutomationTestBase::bSuppressLogErrors = false;
            FAutomationTestBase::bSuppressLogWarnings = false;
            return true;
        }),
        TEXT("restore log suppression statics")));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

// Auto-generated from AS class Ck_AutoTest_Net_NetSpike_CrossActorInventoryItemSurvivesItsSource (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_NetSpike_CrossActorInventoryItemSurvivesItsSource = TEXT("/Script/Angelscript.Ck_AutoTest_Net_NetSpike_CrossActorInventoryItemSurvivesItsSource");
    constexpr auto kTimeoutSeconds_NetSpike_CrossActorInventoryItemSurvivesItsSource = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkNetSpikeNet_AS_NetSpike_CrossActorInventoryItemSurvivesItsSource,
    "Ck.NetSpike.Net.AS_NetSpike_CrossActorInventoryItemSurvivesItsSource",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkNetSpikeNet_AS_NetSpike_CrossActorInventoryItemSurvivesItsSource::RunTest(const FString& Parameters)
{
    bSuppressLogErrors = true;
    bSuppressLogWarnings = true;

    constexpr auto NumPIEClients = 2;
    constexpr auto ExpectedTotalWorlds = 2;
    constexpr auto ReadyTimeoutSeconds = 30.0f;
    constexpr auto FramesAfterSpawn = 30;

    const auto MapPath = FString{TEXT("/Engine/Maps/Entry")};

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_StartPIEMultiClient(NumPIEClients, MapPath));
    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_WaitForPIEReady(ExpectedTotalWorlds, ReadyTimeoutSeconds));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunOnServer(
        FCk_NetAutoTest_ServerAction::CreateLambda([this](UWorld* InServer) -> void
        {
            auto SpawnInfo = FActorSpawnParameters{};
            SpawnInfo.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
            const auto SubjectClassPath = FSoftClassPath(TEXT("/Script/CkTests.Ck_AutoTest_NetSubject"));
            auto* SubjectClass = SubjectClassPath.TryLoadClass<ACk_AutoTest_NetSubject>();
            if (SubjectClass == nullptr)
            { AddError(TEXT("AS-test harness: failed to resolve NetSubject class via FSoftClassPath")); return; }
            auto* Subject = InServer->SpawnActor<ACk_AutoTest_NetSubject>(
                SubjectClass, FTransform::Identity, SpawnInfo);
            if (Subject == nullptr)
            { AddError(TEXT("AS-test harness: server-side SpawnActor returned null")); }
        })));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_TickWorlds(FramesAfterSpawn));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_NetSpike_CrossActorInventoryItemSurvivesItsSource}, kTimeoutSeconds_NetSpike_CrossActorInventoryItemSurvivesItsSource));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_EndPIE());

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_AssertCondition(this,
        FCk_NetAutoTest_Assertion::CreateLambda([]() -> bool
        {
            FAutomationTestBase::bSuppressLogErrors = false;
            FAutomationTestBase::bSuppressLogWarnings = false;
            return true;
        }),
        TEXT("restore log suppression statics")));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

// Auto-generated from AS class Ck_AutoTest_Net_NetSpike_SameActorHandleResolves (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_NetSpike_SameActorHandleResolves = TEXT("/Script/Angelscript.Ck_AutoTest_Net_NetSpike_SameActorHandleResolves");
    constexpr auto kTimeoutSeconds_NetSpike_SameActorHandleResolves = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkNetSpikeNet_AS_NetSpike_SameActorHandleResolves,
    "Ck.NetSpike.Net.AS_NetSpike_SameActorHandleResolves",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkNetSpikeNet_AS_NetSpike_SameActorHandleResolves::RunTest(const FString& Parameters)
{
    bSuppressLogErrors = true;
    bSuppressLogWarnings = true;

    constexpr auto NumPIEClients = 2;
    constexpr auto ExpectedTotalWorlds = 2;
    constexpr auto ReadyTimeoutSeconds = 30.0f;
    constexpr auto FramesAfterSpawn = 30;

    const auto MapPath = FString{TEXT("/Engine/Maps/Entry")};

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_StartPIEMultiClient(NumPIEClients, MapPath));
    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_WaitForPIEReady(ExpectedTotalWorlds, ReadyTimeoutSeconds));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunOnServer(
        FCk_NetAutoTest_ServerAction::CreateLambda([this](UWorld* InServer) -> void
        {
            auto SpawnInfo = FActorSpawnParameters{};
            SpawnInfo.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
            const auto SubjectClassPath = FSoftClassPath(TEXT("/Script/CkTests.Ck_AutoTest_NetSubject"));
            auto* SubjectClass = SubjectClassPath.TryLoadClass<ACk_AutoTest_NetSubject>();
            if (SubjectClass == nullptr)
            { AddError(TEXT("AS-test harness: failed to resolve NetSubject class via FSoftClassPath")); return; }
            auto* Subject = InServer->SpawnActor<ACk_AutoTest_NetSubject>(
                SubjectClass, FTransform::Identity, SpawnInfo);
            if (Subject == nullptr)
            { AddError(TEXT("AS-test harness: server-side SpawnActor returned null")); }
        })));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_TickWorlds(FramesAfterSpawn));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_NetSpike_SameActorHandleResolves}, kTimeoutSeconds_NetSpike_SameActorHandleResolves));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_EndPIE());

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_AssertCondition(this,
        FCk_NetAutoTest_Assertion::CreateLambda([]() -> bool
        {
            FAutomationTestBase::bSuppressLogErrors = false;
            FAutomationTestBase::bSuppressLogWarnings = false;
            return true;
        }),
        TEXT("restore log suppression statics")));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

// Auto-generated from AS class Ck_AutoTest_Net_NetSpike_TwoInventoriesOnOneOwner (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_NetSpike_TwoInventoriesOnOneOwner = TEXT("/Script/Angelscript.Ck_AutoTest_Net_NetSpike_TwoInventoriesOnOneOwner");
    constexpr auto kTimeoutSeconds_NetSpike_TwoInventoriesOnOneOwner = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkNetSpikeNet_AS_NetSpike_TwoInventoriesOnOneOwner,
    "Ck.NetSpike.Net.AS_NetSpike_TwoInventoriesOnOneOwner",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkNetSpikeNet_AS_NetSpike_TwoInventoriesOnOneOwner::RunTest(const FString& Parameters)
{
    bSuppressLogErrors = true;
    bSuppressLogWarnings = true;

    constexpr auto NumPIEClients = 2;
    constexpr auto ExpectedTotalWorlds = 2;
    constexpr auto ReadyTimeoutSeconds = 30.0f;
    constexpr auto FramesAfterSpawn = 30;

    const auto MapPath = FString{TEXT("/Engine/Maps/Entry")};

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_StartPIEMultiClient(NumPIEClients, MapPath));
    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_WaitForPIEReady(ExpectedTotalWorlds, ReadyTimeoutSeconds));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunOnServer(
        FCk_NetAutoTest_ServerAction::CreateLambda([this](UWorld* InServer) -> void
        {
            auto SpawnInfo = FActorSpawnParameters{};
            SpawnInfo.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
            const auto SubjectClassPath = FSoftClassPath(TEXT("/Script/CkTests.Ck_AutoTest_NetSubject"));
            auto* SubjectClass = SubjectClassPath.TryLoadClass<ACk_AutoTest_NetSubject>();
            if (SubjectClass == nullptr)
            { AddError(TEXT("AS-test harness: failed to resolve NetSubject class via FSoftClassPath")); return; }
            auto* Subject = InServer->SpawnActor<ACk_AutoTest_NetSubject>(
                SubjectClass, FTransform::Identity, SpawnInfo);
            if (Subject == nullptr)
            { AddError(TEXT("AS-test harness: server-side SpawnActor returned null")); }
        })));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_TickWorlds(FramesAfterSpawn));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_NetSpike_TwoInventoriesOnOneOwner}, kTimeoutSeconds_NetSpike_TwoInventoriesOnOneOwner));

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_EndPIE());

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_AssertCondition(this,
        FCk_NetAutoTest_Assertion::CreateLambda([]() -> bool
        {
            FAutomationTestBase::bSuppressLogErrors = false;
            FAutomationTestBase::bSuppressLogWarnings = false;
            return true;
        }),
        TEXT("restore log suppression statics")));

    return true;
}

// --------------------------------------------------------------------------------------------------------------------

#endif // WITH_EDITOR && WITH_DEV_AUTOMATION_TESTS
