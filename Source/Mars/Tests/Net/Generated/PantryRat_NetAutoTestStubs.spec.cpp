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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_AClientsRequestsAreDropped (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_AClientsRequestsAreDropped = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_AClientsRequestsAreDropped");
    constexpr auto kTimeoutSeconds_PantryRat_AClientsRequestsAreDropped = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_AClientsRequestsAreDropped,
    "Ck.PantryRat.Net.AS_PantryRat_AClientsRequestsAreDropped",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_AClientsRequestsAreDropped::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_AClientsRequestsAreDropped}, kTimeoutSeconds_PantryRat_AClientsRequestsAreDropped));

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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands");
    constexpr auto kTimeoutSeconds_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands,
    "Ck.PantryRat.Net.AS_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands}, kTimeoutSeconds_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands));

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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_ACopyFollowsTheRatOutOfTheDen (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_ACopyFollowsTheRatOutOfTheDen = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_ACopyFollowsTheRatOutOfTheDen");
    constexpr auto kTimeoutSeconds_PantryRat_ACopyFollowsTheRatOutOfTheDen = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_ACopyFollowsTheRatOutOfTheDen,
    "Ck.PantryRat.Net.AS_PantryRat_ACopyFollowsTheRatOutOfTheDen",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_ACopyFollowsTheRatOutOfTheDen::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_ACopyFollowsTheRatOutOfTheDen}, kTimeoutSeconds_PantryRat_ACopyFollowsTheRatOutOfTheDen));

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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_ARatComposesOnBothMachines (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_ARatComposesOnBothMachines = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_ARatComposesOnBothMachines");
    constexpr auto kTimeoutSeconds_PantryRat_ARatComposesOnBothMachines = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_ARatComposesOnBothMachines,
    "Ck.PantryRat.Net.AS_PantryRat_ARatComposesOnBothMachines",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_ARatComposesOnBothMachines::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_ARatComposesOnBothMachines}, kTimeoutSeconds_PantryRat_ARatComposesOnBothMachines));

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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines");
    constexpr auto kTimeoutSeconds_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines,
    "Ck.PantryRat.Net.AS_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines}, kTimeoutSeconds_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines));

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

// Auto-generated from AS class Ck_AutoTest_Net_PantryRat_ATheftsPhasesReachTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_PantryRat_ATheftsPhasesReachTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_PantryRat_ATheftsPhasesReachTheClient");
    constexpr auto kTimeoutSeconds_PantryRat_ATheftsPhasesReachTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkPantryRatNet_AS_PantryRat_ATheftsPhasesReachTheClient,
    "Ck.PantryRat.Net.AS_PantryRat_ATheftsPhasesReachTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkPantryRatNet_AS_PantryRat_ATheftsPhasesReachTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_PantryRat_ATheftsPhasesReachTheClient}, kTimeoutSeconds_PantryRat_ATheftsPhasesReachTheClient));

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
