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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AClientPlacesAPlatterOfFood (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AClientPlacesAPlatterOfFood = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AClientPlacesAPlatterOfFood");
    constexpr auto kTimeoutSeconds_PlatterDock_AClientPlacesAPlatterOfFood = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AClientPlacesAPlatterOfFood,
    "Ck.PlatterDock.Net.AS_PlatterDock_AClientPlacesAPlatterOfFood",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AClientPlacesAPlatterOfFood::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AClientPlacesAPlatterOfFood}, kTimeoutSeconds_PlatterDock_AClientPlacesAPlatterOfFood));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AClientPlacesItsPlatterOnTheDock (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AClientPlacesItsPlatterOnTheDock = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AClientPlacesItsPlatterOnTheDock");
    constexpr auto kTimeoutSeconds_PlatterDock_AClientPlacesItsPlatterOnTheDock = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AClientPlacesItsPlatterOnTheDock,
    "Ck.PlatterDock.Net.AS_PlatterDock_AClientPlacesItsPlatterOnTheDock",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AClientPlacesItsPlatterOnTheDock::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AClientPlacesItsPlatterOnTheDock}, kTimeoutSeconds_PlatterDock_AClientPlacesItsPlatterOnTheDock));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AClientsDirectActIsDropped (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AClientsDirectActIsDropped = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AClientsDirectActIsDropped");
    constexpr auto kTimeoutSeconds_PlatterDock_AClientsDirectActIsDropped = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AClientsDirectActIsDropped,
    "Ck.PlatterDock.Net.AS_PlatterDock_AClientsDirectActIsDropped",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AClientsDirectActIsDropped::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AClientsDirectActIsDropped}, kTimeoutSeconds_PlatterDock_AClientsDirectActIsDropped));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AClientTakesTheDockedPlatter (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AClientTakesTheDockedPlatter = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AClientTakesTheDockedPlatter");
    constexpr auto kTimeoutSeconds_PlatterDock_AClientTakesTheDockedPlatter = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AClientTakesTheDockedPlatter,
    "Ck.PlatterDock.Net.AS_PlatterDock_AClientTakesTheDockedPlatter",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AClientTakesTheDockedPlatter::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AClientTakesTheDockedPlatter}, kTimeoutSeconds_PlatterDock_AClientTakesTheDockedPlatter));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ADockedPileRidesOnTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ADockedPileRidesOnTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ADockedPileRidesOnTheClient");
    constexpr auto kTimeoutSeconds_PlatterDock_ADockedPileRidesOnTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ADockedPileRidesOnTheClient,
    "Ck.PlatterDock.Net.AS_PlatterDock_ADockedPileRidesOnTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ADockedPileRidesOnTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ADockedPileRidesOnTheClient}, kTimeoutSeconds_PlatterDock_ADockedPileRidesOnTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ADockedPlatterMountsOnTheClientsDock (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ADockedPlatterMountsOnTheClientsDock = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ADockedPlatterMountsOnTheClientsDock");
    constexpr auto kTimeoutSeconds_PlatterDock_ADockedPlatterMountsOnTheClientsDock = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ADockedPlatterMountsOnTheClientsDock,
    "Ck.PlatterDock.Net.AS_PlatterDock_ADockedPlatterMountsOnTheClientsDock",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ADockedPlatterMountsOnTheClientsDock::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ADockedPlatterMountsOnTheClientsDock}, kTimeoutSeconds_PlatterDock_ADockedPlatterMountsOnTheClientsDock));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ALateBinderReadsTheDockAsItStands (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ALateBinderReadsTheDockAsItStands = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ALateBinderReadsTheDockAsItStands");
    constexpr auto kTimeoutSeconds_PlatterDock_ALateBinderReadsTheDockAsItStands = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ALateBinderReadsTheDockAsItStands,
    "Ck.PlatterDock.Net.AS_PlatterDock_ALateBinderReadsTheDockAsItStands",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ALateBinderReadsTheDockAsItStands::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ALateBinderReadsTheDockAsItStands}, kTimeoutSeconds_PlatterDock_ALateBinderReadsTheDockAsItStands));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ALateReaderIgnoresAnOlderRefusal (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ALateReaderIgnoresAnOlderRefusal = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ALateReaderIgnoresAnOlderRefusal");
    constexpr auto kTimeoutSeconds_PlatterDock_ALateReaderIgnoresAnOlderRefusal = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ALateReaderIgnoresAnOlderRefusal,
    "Ck.PlatterDock.Net.AS_PlatterDock_ALateReaderIgnoresAnOlderRefusal",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ALateReaderIgnoresAnOlderRefusal::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ALateReaderIgnoresAnOlderRefusal}, kTimeoutSeconds_PlatterDock_ALateReaderIgnoresAnOlderRefusal));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AnUndockAndADockInOneFrame (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AnUndockAndADockInOneFrame = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AnUndockAndADockInOneFrame");
    constexpr auto kTimeoutSeconds_PlatterDock_AnUndockAndADockInOneFrame = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AnUndockAndADockInOneFrame,
    "Ck.PlatterDock.Net.AS_PlatterDock_AnUndockAndADockInOneFrame",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AnUndockAndADockInOneFrame::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AnUndockAndADockInOneFrame}, kTimeoutSeconds_PlatterDock_AnUndockAndADockInOneFrame));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_AnUndockedPlatterLeavesTheClientsDock (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_AnUndockedPlatterLeavesTheClientsDock = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_AnUndockedPlatterLeavesTheClientsDock");
    constexpr auto kTimeoutSeconds_PlatterDock_AnUndockedPlatterLeavesTheClientsDock = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_AnUndockedPlatterLeavesTheClientsDock,
    "Ck.PlatterDock.Net.AS_PlatterDock_AnUndockedPlatterLeavesTheClientsDock",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_AnUndockedPlatterLeavesTheClientsDock::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_AnUndockedPlatterLeavesTheClientsDock}, kTimeoutSeconds_PlatterDock_AnUndockedPlatterLeavesTheClientsDock));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_APlaceAndATakeInOneFrame (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_APlaceAndATakeInOneFrame = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_APlaceAndATakeInOneFrame");
    constexpr auto kTimeoutSeconds_PlatterDock_APlaceAndATakeInOneFrame = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_APlaceAndATakeInOneFrame,
    "Ck.PlatterDock.Net.AS_PlatterDock_APlaceAndATakeInOneFrame",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_APlaceAndATakeInOneFrame::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_APlaceAndATakeInOneFrame}, kTimeoutSeconds_PlatterDock_APlaceAndATakeInOneFrame));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ARealCuttingStationComposesOnBothMachines (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ARealCuttingStationComposesOnBothMachines = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ARealCuttingStationComposesOnBothMachines");
    constexpr auto kTimeoutSeconds_PlatterDock_ARealCuttingStationComposesOnBothMachines = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ARealCuttingStationComposesOnBothMachines,
    "Ck.PlatterDock.Net.AS_PlatterDock_ARealCuttingStationComposesOnBothMachines",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ARealCuttingStationComposesOnBothMachines::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ARealCuttingStationComposesOnBothMachines}, kTimeoutSeconds_PlatterDock_ARealCuttingStationComposesOnBothMachines));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ARefusedPlaceNamesItsInitiator (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ARefusedPlaceNamesItsInitiator = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ARefusedPlaceNamesItsInitiator");
    constexpr auto kTimeoutSeconds_PlatterDock_ARefusedPlaceNamesItsInitiator = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ARefusedPlaceNamesItsInitiator,
    "Ck.PlatterDock.Net.AS_PlatterDock_ARefusedPlaceNamesItsInitiator",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ARefusedPlaceNamesItsInitiator::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ARefusedPlaceNamesItsInitiator}, kTimeoutSeconds_PlatterDock_ARefusedPlaceNamesItsInitiator));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ASweepLandsOnTheClientsTray (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ASweepLandsOnTheClientsTray = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ASweepLandsOnTheClientsTray");
    constexpr auto kTimeoutSeconds_PlatterDock_ASweepLandsOnTheClientsTray = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ASweepLandsOnTheClientsTray,
    "Ck.PlatterDock.Net.AS_PlatterDock_ASweepLandsOnTheClientsTray",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ASweepLandsOnTheClientsTray::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ASweepLandsOnTheClientsTray}, kTimeoutSeconds_PlatterDock_ASweepLandsOnTheClientsTray));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_ATakeAndAPlaceInOneFrame (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_ATakeAndAPlaceInOneFrame = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_ATakeAndAPlaceInOneFrame");
    constexpr auto kTimeoutSeconds_PlatterDock_ATakeAndAPlaceInOneFrame = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_ATakeAndAPlaceInOneFrame,
    "Ck.PlatterDock.Net.AS_PlatterDock_ATakeAndAPlaceInOneFrame",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_ATakeAndAPlaceInOneFrame::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_ATakeAndAPlaceInOneFrame}, kTimeoutSeconds_PlatterDock_ATakeAndAPlaceInOneFrame));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_TheClientIsOfferedWhatTheHostIs (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_TheClientIsOfferedWhatTheHostIs = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_TheClientIsOfferedWhatTheHostIs");
    constexpr auto kTimeoutSeconds_PlatterDock_TheClientIsOfferedWhatTheHostIs = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_TheClientIsOfferedWhatTheHostIs,
    "Ck.PlatterDock.Net.AS_PlatterDock_TheClientIsOfferedWhatTheHostIs",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_TheClientIsOfferedWhatTheHostIs::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_TheClientIsOfferedWhatTheHostIs}, kTimeoutSeconds_PlatterDock_TheClientIsOfferedWhatTheHostIs));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_TheClientWroteNothing (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_TheClientWroteNothing = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_TheClientWroteNothing");
    constexpr auto kTimeoutSeconds_PlatterDock_TheClientWroteNothing = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_TheClientWroteNothing,
    "Ck.PlatterDock.Net.AS_PlatterDock_TheClientWroteNothing",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_TheClientWroteNothing::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_TheClientWroteNothing}, kTimeoutSeconds_PlatterDock_TheClientWroteNothing));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_TheDocksReachTheClientUnderTheirStation (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_TheDocksReachTheClientUnderTheirStation = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_TheDocksReachTheClientUnderTheirStation");
    constexpr auto kTimeoutSeconds_PlatterDock_TheDocksReachTheClientUnderTheirStation = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_TheDocksReachTheClientUnderTheirStation,
    "Ck.PlatterDock.Net.AS_PlatterDock_TheDocksReachTheClientUnderTheirStation",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_TheDocksReachTheClientUnderTheirStation::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_TheDocksReachTheClientUnderTheirStation}, kTimeoutSeconds_PlatterDock_TheDocksReachTheClientUnderTheirStation));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_TheLabelReadsTheDocksTheHostSees (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_TheLabelReadsTheDocksTheHostSees = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_TheLabelReadsTheDocksTheHostSees");
    constexpr auto kTimeoutSeconds_PlatterDock_TheLabelReadsTheDocksTheHostSees = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_TheLabelReadsTheDocksTheHostSees,
    "Ck.PlatterDock.Net.AS_PlatterDock_TheLabelReadsTheDocksTheHostSees",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_TheLabelReadsTheDocksTheHostSees::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_TheLabelReadsTheDocksTheHostSees}, kTimeoutSeconds_PlatterDock_TheLabelReadsTheDocksTheHostSees));

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

// Auto-generated from AS class Ck_AutoTest_Net_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce");
    constexpr auto kTimeoutSeconds_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPlatterDockNet_AS_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce,
    "Ck.PlatterDock.Net.AS_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPlatterDockNet_AS_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce}, kTimeoutSeconds_PlatterDock_TwoTakesInOneFrameMoveThePlatterOnce));

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
