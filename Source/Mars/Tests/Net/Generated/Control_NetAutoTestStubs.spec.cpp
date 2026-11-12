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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientLetsGoBeforeTheThreshold (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientLetsGoBeforeTheThreshold = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientLetsGoBeforeTheThreshold");
    constexpr auto kTimeoutSeconds_Control_AClientLetsGoBeforeTheThreshold = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientLetsGoBeforeTheThreshold,
    "Ck.Control.Net.AS_Control_AClientLetsGoBeforeTheThreshold",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientLetsGoBeforeTheThreshold::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientLetsGoBeforeTheThreshold}, kTimeoutSeconds_Control_AClientLetsGoBeforeTheThreshold));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientPullsALeverPastTheThreshold (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientPullsALeverPastTheThreshold = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientPullsALeverPastTheThreshold");
    constexpr auto kTimeoutSeconds_Control_AClientPullsALeverPastTheThreshold = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientPullsALeverPastTheThreshold,
    "Ck.Control.Net.AS_Control_AClientPullsALeverPastTheThreshold",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientPullsALeverPastTheThreshold::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientPullsALeverPastTheThreshold}, kTimeoutSeconds_Control_AClientPullsALeverPastTheThreshold));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientsChainPullPulsesOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientsChainPullPulsesOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientsChainPullPulsesOnce");
    constexpr auto kTimeoutSeconds_Control_AClientsChainPullPulsesOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientsChainPullPulsesOnce,
    "Ck.Control.Net.AS_Control_AClientsChainPullPulsesOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientsChainPullPulsesOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientsChainPullPulsesOnce}, kTimeoutSeconds_Control_AClientsChainPullPulsesOnce));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientsDirectGripRequestIsDropped (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientsDirectGripRequestIsDropped = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientsDirectGripRequestIsDropped");
    constexpr auto kTimeoutSeconds_Control_AClientsDirectGripRequestIsDropped = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientsDirectGripRequestIsDropped,
    "Ck.Control.Net.AS_Control_AClientsDirectGripRequestIsDropped",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientsDirectGripRequestIsDropped::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientsDirectGripRequestIsDropped}, kTimeoutSeconds_Control_AClientsDirectGripRequestIsDropped));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientsEngageAndSetActiveRequestsAreDropped (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientsEngageAndSetActiveRequestsAreDropped = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientsEngageAndSetActiveRequestsAreDropped");
    constexpr auto kTimeoutSeconds_Control_AClientsEngageAndSetActiveRequestsAreDropped = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientsEngageAndSetActiveRequestsAreDropped,
    "Ck.Control.Net.AS_Control_AClientsEngageAndSetActiveRequestsAreDropped",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientsEngageAndSetActiveRequestsAreDropped::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientsEngageAndSetActiveRequestsAreDropped}, kTimeoutSeconds_Control_AClientsEngageAndSetActiveRequestsAreDropped));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AClientsGripReachesTheLedger (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AClientsGripReachesTheLedger = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AClientsGripReachesTheLedger");
    constexpr auto kTimeoutSeconds_Control_AClientsGripReachesTheLedger = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AClientsGripReachesTheLedger,
    "Ck.Control.Net.AS_Control_AClientsGripReachesTheLedger",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AClientsGripReachesTheLedger::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AClientsGripReachesTheLedger}, kTimeoutSeconds_Control_AClientsGripReachesTheLedger));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AControlWithoutADriverIsNotArbitrated (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AControlWithoutADriverIsNotArbitrated = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AControlWithoutADriverIsNotArbitrated");
    constexpr auto kTimeoutSeconds_Control_AControlWithoutADriverIsNotArbitrated = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AControlWithoutADriverIsNotArbitrated,
    "Ck.Control.Net.AS_Control_AControlWithoutADriverIsNotArbitrated",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AControlWithoutADriverIsNotArbitrated::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AControlWithoutADriverIsNotArbitrated}, kTimeoutSeconds_Control_AControlWithoutADriverIsNotArbitrated));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AControlWithoutADriverKeepsItsRule (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AControlWithoutADriverKeepsItsRule = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AControlWithoutADriverKeepsItsRule");
    constexpr auto kTimeoutSeconds_Control_AControlWithoutADriverKeepsItsRule = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AControlWithoutADriverKeepsItsRule,
    "Ck.Control.Net.AS_Control_AControlWithoutADriverKeepsItsRule",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AControlWithoutADriverKeepsItsRule::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AControlWithoutADriverKeepsItsRule}, kTimeoutSeconds_Control_AControlWithoutADriverKeepsItsRule));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ACrossedPullCarriesTheMirroredHandleHome (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ACrossedPullCarriesTheMirroredHandleHome = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ACrossedPullCarriesTheMirroredHandleHome");
    constexpr auto kTimeoutSeconds_Control_ACrossedPullCarriesTheMirroredHandleHome = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ACrossedPullCarriesTheMirroredHandleHome,
    "Ck.Control.Net.AS_Control_ACrossedPullCarriesTheMirroredHandleHome",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ACrossedPullCarriesTheMirroredHandleHome::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ACrossedPullCarriesTheMirroredHandleHome}, kTimeoutSeconds_Control_ACrossedPullCarriesTheMirroredHandleHome));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AGrabAndCrossInOneFrameEngagesOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AGrabAndCrossInOneFrameEngagesOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AGrabAndCrossInOneFrameEngagesOnce");
    constexpr auto kTimeoutSeconds_Control_AGrabAndCrossInOneFrameEngagesOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AGrabAndCrossInOneFrameEngagesOnce,
    "Ck.Control.Net.AS_Control_AGrabAndCrossInOneFrameEngagesOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AGrabAndCrossInOneFrameEngagesOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AGrabAndCrossInOneFrameEngagesOnce}, kTimeoutSeconds_Control_AGrabAndCrossInOneFrameEngagesOnce));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree");
    constexpr auto kTimeoutSeconds_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree,
    "Ck.Control.Net.AS_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree}, kTimeoutSeconds_Control_AGrabAndLetGoInOneFrameLeavesTheControlFree));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AGripEngagesAtMostOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AGripEngagesAtMostOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AGripEngagesAtMostOnce");
    constexpr auto kTimeoutSeconds_Control_AGripEngagesAtMostOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AGripEngagesAtMostOnce,
    "Ck.Control.Net.AS_Control_AGripEngagesAtMostOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AGripEngagesAtMostOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AGripEngagesAtMostOnce}, kTimeoutSeconds_Control_AGripEngagesAtMostOnce));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AGripIsReleasedWhenItsGripperIsDestroyed (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AGripIsReleasedWhenItsGripperIsDestroyed = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AGripIsReleasedWhenItsGripperIsDestroyed");
    constexpr auto kTimeoutSeconds_Control_AGripIsReleasedWhenItsGripperIsDestroyed = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AGripIsReleasedWhenItsGripperIsDestroyed,
    "Ck.Control.Net.AS_Control_AGripIsReleasedWhenItsGripperIsDestroyed",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AGripIsReleasedWhenItsGripperIsDestroyed::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AGripIsReleasedWhenItsGripperIsDestroyed}, kTimeoutSeconds_Control_AGripIsReleasedWhenItsGripperIsDestroyed));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AGrippedControlIsUnavailableToOthers (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AGrippedControlIsUnavailableToOthers = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AGrippedControlIsUnavailableToOthers");
    constexpr auto kTimeoutSeconds_Control_AGrippedControlIsUnavailableToOthers = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AGrippedControlIsUnavailableToOthers,
    "Ck.Control.Net.AS_Control_AGrippedControlIsUnavailableToOthers",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AGrippedControlIsUnavailableToOthers::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AGrippedControlIsUnavailableToOthers}, kTimeoutSeconds_Control_AGrippedControlIsUnavailableToOthers));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ALateBinderSeesTheGripAsItStands (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ALateBinderSeesTheGripAsItStands = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ALateBinderSeesTheGripAsItStands");
    constexpr auto kTimeoutSeconds_Control_ALateBinderSeesTheGripAsItStands = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ALateBinderSeesTheGripAsItStands,
    "Ck.Control.Net.AS_Control_ALateBinderSeesTheGripAsItStands",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ALateBinderSeesTheGripAsItStands::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ALateBinderSeesTheGripAsItStands}, kTimeoutSeconds_Control_ALateBinderSeesTheGripAsItStands));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ALateBinderSeesTheHandleWhereItIs (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ALateBinderSeesTheHandleWhereItIs = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ALateBinderSeesTheHandleWhereItIs");
    constexpr auto kTimeoutSeconds_Control_ALateBinderSeesTheHandleWhereItIs = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ALateBinderSeesTheHandleWhereItIs,
    "Ck.Control.Net.AS_Control_ALateBinderSeesTheHandleWhereItIs",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ALateBinderSeesTheHandleWhereItIs::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ALateBinderSeesTheHandleWhereItIs}, kTimeoutSeconds_Control_ALateBinderSeesTheHandleWhereItIs));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ALetGoSettlesTheMirroredHandle (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ALetGoSettlesTheMirroredHandle = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ALetGoSettlesTheMirroredHandle");
    constexpr auto kTimeoutSeconds_Control_ALetGoSettlesTheMirroredHandle = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ALetGoSettlesTheMirroredHandle,
    "Ck.Control.Net.AS_Control_ALetGoSettlesTheMirroredHandle",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ALetGoSettlesTheMirroredHandle::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ALetGoSettlesTheMirroredHandle}, kTimeoutSeconds_Control_ALetGoSettlesTheMirroredHandle));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_APendingEngageThatNeverArrivesSettlesBack (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_APendingEngageThatNeverArrivesSettlesBack = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_APendingEngageThatNeverArrivesSettlesBack");
    constexpr auto kTimeoutSeconds_Control_APendingEngageThatNeverArrivesSettlesBack = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_APendingEngageThatNeverArrivesSettlesBack,
    "Ck.Control.Net.AS_Control_APendingEngageThatNeverArrivesSettlesBack",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_APendingEngageThatNeverArrivesSettlesBack::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_APendingEngageThatNeverArrivesSettlesBack}, kTimeoutSeconds_Control_APendingEngageThatNeverArrivesSettlesBack));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_APullFromActiveRunsTowardStartOnAClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_APullFromActiveRunsTowardStartOnAClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_APullFromActiveRunsTowardStartOnAClient");
    constexpr auto kTimeoutSeconds_Control_APullFromActiveRunsTowardStartOnAClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_APullFromActiveRunsTowardStartOnAClient,
    "Ck.Control.Net.AS_Control_APullFromActiveRunsTowardStartOnAClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_APullFromActiveRunsTowardStartOnAClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_APullFromActiveRunsTowardStartOnAClient}, kTimeoutSeconds_Control_APullFromActiveRunsTowardStartOnAClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ARefusalAfterTheCrossingSettlesTheHandle (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ARefusalAfterTheCrossingSettlesTheHandle = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ARefusalAfterTheCrossingSettlesTheHandle");
    constexpr auto kTimeoutSeconds_Control_ARefusalAfterTheCrossingSettlesTheHandle = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ARefusalAfterTheCrossingSettlesTheHandle,
    "Ck.Control.Net.AS_Control_ARefusalAfterTheCrossingSettlesTheHandle",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ARefusalAfterTheCrossingSettlesTheHandle::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ARefusalAfterTheCrossingSettlesTheHandle}, kTimeoutSeconds_Control_ARefusalAfterTheCrossingSettlesTheHandle));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ARefusedPullCannotEngage (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ARefusedPullCannotEngage = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ARefusedPullCannotEngage");
    constexpr auto kTimeoutSeconds_Control_ARefusedPullCannotEngage = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ARefusedPullCannotEngage,
    "Ck.Control.Net.AS_Control_ARefusedPullCannotEngage",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ARefusedPullCannotEngage::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ARefusedPullCannotEngage}, kTimeoutSeconds_Control_ARefusedPullCannotEngage));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ARegripBeforeTheEngageArrivesEngagesOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ARegripBeforeTheEngageArrivesEngagesOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ARegripBeforeTheEngageArrivesEngagesOnce");
    constexpr auto kTimeoutSeconds_Control_ARegripBeforeTheEngageArrivesEngagesOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ARegripBeforeTheEngageArrivesEngagesOnce,
    "Ck.Control.Net.AS_Control_ARegripBeforeTheEngageArrivesEngagesOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ARegripBeforeTheEngageArrivesEngagesOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ARegripBeforeTheEngageArrivesEngagesOnce}, kTimeoutSeconds_Control_ARegripBeforeTheEngageArrivesEngagesOnce));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_AReportFromANonGripperIsDropped (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_AReportFromANonGripperIsDropped = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_AReportFromANonGripperIsDropped");
    constexpr auto kTimeoutSeconds_Control_AReportFromANonGripperIsDropped = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_AReportFromANonGripperIsDropped,
    "Ck.Control.Net.AS_Control_AReportFromANonGripperIsDropped",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_AReportFromANonGripperIsDropped::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_AReportFromANonGripperIsDropped}, kTimeoutSeconds_Control_AReportFromANonGripperIsDropped));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ASecondGripperIsRefused (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ASecondGripperIsRefused = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ASecondGripperIsRefused");
    constexpr auto kTimeoutSeconds_Control_ASecondGripperIsRefused = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ASecondGripperIsRefused,
    "Ck.Control.Net.AS_Control_ASecondGripperIsRefused",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ASecondGripperIsRefused::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ASecondGripperIsRefused}, kTimeoutSeconds_Control_ASecondGripperIsRefused));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_ReportsStayUnderTheRate (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_ReportsStayUnderTheRate = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_ReportsStayUnderTheRate");
    constexpr auto kTimeoutSeconds_Control_ReportsStayUnderTheRate = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_ReportsStayUnderTheRate,
    "Ck.Control.Net.AS_Control_ReportsStayUnderTheRate",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_ReportsStayUnderTheRate::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_ReportsStayUnderTheRate}, kTimeoutSeconds_Control_ReportsStayUnderTheRate));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_TheClientsHandleFollowsTheHostsPull (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_TheClientsHandleFollowsTheHostsPull = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_TheClientsHandleFollowsTheHostsPull");
    constexpr auto kTimeoutSeconds_Control_TheClientsHandleFollowsTheHostsPull = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_TheClientsHandleFollowsTheHostsPull,
    "Ck.Control.Net.AS_Control_TheClientsHandleFollowsTheHostsPull",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_TheClientsHandleFollowsTheHostsPull::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_TheClientsHandleFollowsTheHostsPull}, kTimeoutSeconds_Control_TheClientsHandleFollowsTheHostsPull));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_TheGrippersOwnHandleIgnoresTheLedger (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_TheGrippersOwnHandleIgnoresTheLedger = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_TheGrippersOwnHandleIgnoresTheLedger");
    constexpr auto kTimeoutSeconds_Control_TheGrippersOwnHandleIgnoresTheLedger = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_TheGrippersOwnHandleIgnoresTheLedger,
    "Ck.Control.Net.AS_Control_TheGrippersOwnHandleIgnoresTheLedger",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_TheGrippersOwnHandleIgnoresTheLedger::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_TheGrippersOwnHandleIgnoresTheLedger}, kTimeoutSeconds_Control_TheGrippersOwnHandleIgnoresTheLedger));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_TheHostsOwnPullEngages (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_TheHostsOwnPullEngages = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_TheHostsOwnPullEngages");
    constexpr auto kTimeoutSeconds_Control_TheHostsOwnPullEngages = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_TheHostsOwnPullEngages,
    "Ck.Control.Net.AS_Control_TheHostsOwnPullEngages",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_TheHostsOwnPullEngages::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_TheHostsOwnPullEngages}, kTimeoutSeconds_Control_TheHostsOwnPullEngages));

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

// Auto-generated from AS class Ck_AutoTest_Net_Control_TheServersHandleFollowsAClientsPull (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_Control_TheServersHandleFollowsAClientsPull = TEXT("/Script/Angelscript.Ck_AutoTest_Net_Control_TheServersHandleFollowsAClientsPull");
    constexpr auto kTimeoutSeconds_Control_TheServersHandleFollowsAClientsPull = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkControlNet_AS_Control_TheServersHandleFollowsAClientsPull,
    "Ck.Control.Net.AS_Control_TheServersHandleFollowsAClientsPull",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkControlNet_AS_Control_TheServersHandleFollowsAClientsPull::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_Control_TheServersHandleFollowsAClientsPull}, kTimeoutSeconds_Control_TheServersHandleFollowsAClientsPull));

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
