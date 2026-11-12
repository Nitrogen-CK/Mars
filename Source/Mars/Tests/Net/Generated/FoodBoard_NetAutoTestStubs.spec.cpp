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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_AChopAndATurnThatArriveTogether (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_AChopAndATurnThatArriveTogether = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_AChopAndATurnThatArriveTogether");
    constexpr auto kTimeoutSeconds_FoodBoard_AChopAndATurnThatArriveTogether = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_AChopAndATurnThatArriveTogether,
    "Ck.FoodBoard.Net.AS_FoodBoard_AChopAndATurnThatArriveTogether",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_AChopAndATurnThatArriveTogether::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_AChopAndATurnThatArriveTogether}, kTimeoutSeconds_FoodBoard_AChopAndATurnThatArriveTogether));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_AClientsChopCutsTheFoodOnTheBoard (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_AClientsChopCutsTheFoodOnTheBoard = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_AClientsChopCutsTheFoodOnTheBoard");
    constexpr auto kTimeoutSeconds_FoodBoard_AClientsChopCutsTheFoodOnTheBoard = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_AClientsChopCutsTheFoodOnTheBoard,
    "Ck.FoodBoard.Net.AS_FoodBoard_AClientsChopCutsTheFoodOnTheBoard",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_AClientsChopCutsTheFoodOnTheBoard::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_AClientsChopCutsTheFoodOnTheBoard}, kTimeoutSeconds_FoodBoard_AClientsChopCutsTheFoodOnTheBoard));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ACutAndATurnInOneFrame (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ACutAndATurnInOneFrame = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ACutAndATurnInOneFrame");
    constexpr auto kTimeoutSeconds_FoodBoard_ACutAndATurnInOneFrame = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ACutAndATurnInOneFrame,
    "Ck.FoodBoard.Net.AS_FoodBoard_ACutAndATurnInOneFrame",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ACutAndATurnInOneFrame::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ACutAndATurnInOneFrame}, kTimeoutSeconds_FoodBoard_ACutAndATurnInOneFrame));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ACutPartsTheHalvesOnTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ACutPartsTheHalvesOnTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ACutPartsTheHalvesOnTheClient");
    constexpr auto kTimeoutSeconds_FoodBoard_ACutPartsTheHalvesOnTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ACutPartsTheHalvesOnTheClient,
    "Ck.FoodBoard.Net.AS_FoodBoard_ACutPartsTheHalvesOnTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ACutPartsTheHalvesOnTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ACutPartsTheHalvesOnTheClient}, kTimeoutSeconds_FoodBoard_ACutPartsTheHalvesOnTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_AFullBoardOnlyKnocksOnTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_AFullBoardOnlyKnocksOnTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_AFullBoardOnlyKnocksOnTheClient");
    constexpr auto kTimeoutSeconds_FoodBoard_AFullBoardOnlyKnocksOnTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_AFullBoardOnlyKnocksOnTheClient,
    "Ck.FoodBoard.Net.AS_FoodBoard_AFullBoardOnlyKnocksOnTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_AFullBoardOnlyKnocksOnTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_AFullBoardOnlyKnocksOnTheClient}, kTimeoutSeconds_FoodBoard_AFullBoardOnlyKnocksOnTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach");
    constexpr auto kTimeoutSeconds_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach,
    "Ck.FoodBoard.Net.AS_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach}, kTimeoutSeconds_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands");
    constexpr auto kTimeoutSeconds_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands,
    "Ck.FoodBoard.Net.AS_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands}, kTimeoutSeconds_FoodBoard_ALateBinderStartsFromTheLedgerAsItStands));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach");
    constexpr auto kTimeoutSeconds_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach,
    "Ck.FoodBoard.Net.AS_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach}, kTimeoutSeconds_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ARefusedSweepReachesTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ARefusedSweepReachesTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ARefusedSweepReachesTheClient");
    constexpr auto kTimeoutSeconds_FoodBoard_ARefusedSweepReachesTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ARefusedSweepReachesTheClient,
    "Ck.FoodBoard.Net.AS_FoodBoard_ARefusedSweepReachesTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ARefusedSweepReachesTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ARefusedSweepReachesTheClient}, kTimeoutSeconds_FoodBoard_ARefusedSweepReachesTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines");
    constexpr auto kTimeoutSeconds_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines,
    "Ck.FoodBoard.Net.AS_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines}, kTimeoutSeconds_FoodBoard_ARemoteOperatorsSweepWithNoTrayIsRefusedOnBothMachines));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood");
    constexpr auto kTimeoutSeconds_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood,
    "Ck.FoodBoard.Net.AS_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood}, kTimeoutSeconds_FoodBoard_ARemoteOperatorsTurnPressTurnsTheFood));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ATurnAndACutInOneFrame (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ATurnAndACutInOneFrame = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ATurnAndACutInOneFrame");
    constexpr auto kTimeoutSeconds_FoodBoard_ATurnAndACutInOneFrame = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ATurnAndACutInOneFrame,
    "Ck.FoodBoard.Net.AS_FoodBoard_ATurnAndACutInOneFrame",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ATurnAndACutInOneFrame::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ATurnAndACutInOneFrame}, kTimeoutSeconds_FoodBoard_ATurnAndACutInOneFrame));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_ATurnYawsThePiecesOnTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_ATurnYawsThePiecesOnTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_ATurnYawsThePiecesOnTheClient");
    constexpr auto kTimeoutSeconds_FoodBoard_ATurnYawsThePiecesOnTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_ATurnYawsThePiecesOnTheClient,
    "Ck.FoodBoard.Net.AS_FoodBoard_ATurnYawsThePiecesOnTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_ATurnYawsThePiecesOnTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_ATurnYawsThePiecesOnTheClient}, kTimeoutSeconds_FoodBoard_ATurnYawsThePiecesOnTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_TheBoardsCountReachesTheClient (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_TheBoardsCountReachesTheClient = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_TheBoardsCountReachesTheClient");
    constexpr auto kTimeoutSeconds_FoodBoard_TheBoardsCountReachesTheClient = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_TheBoardsCountReachesTheClient,
    "Ck.FoodBoard.Net.AS_FoodBoard_TheBoardsCountReachesTheClient",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_TheBoardsCountReachesTheClient::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_TheBoardsCountReachesTheClient}, kTimeoutSeconds_FoodBoard_TheBoardsCountReachesTheClient));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_TheClientWroteNothing (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_TheClientWroteNothing = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_TheClientWroteNothing");
    constexpr auto kTimeoutSeconds_FoodBoard_TheClientWroteNothing = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_TheClientWroteNothing,
    "Ck.FoodBoard.Net.AS_FoodBoard_TheClientWroteNothing",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_TheClientWroteNothing::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_TheClientWroteNothing}, kTimeoutSeconds_FoodBoard_TheClientWroteNothing));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_TwoChopsThatArriveTogetherChopOnce (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_TwoChopsThatArriveTogetherChopOnce = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_TwoChopsThatArriveTogetherChopOnce");
    constexpr auto kTimeoutSeconds_FoodBoard_TwoChopsThatArriveTogetherChopOnce = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_TwoChopsThatArriveTogetherChopOnce,
    "Ck.FoodBoard.Net.AS_FoodBoard_TwoChopsThatArriveTogetherChopOnce",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_TwoChopsThatArriveTogetherChopOnce::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_TwoChopsThatArriveTogetherChopOnce}, kTimeoutSeconds_FoodBoard_TwoChopsThatArriveTogetherChopOnce));

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

// Auto-generated from AS class Ck_AutoTest_Net_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised (Replicated-mode).
// DO NOT EDIT - regenerated on editor startup and every successful AS recompile.

namespace
{
    constexpr auto kAsClassPath_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised = TEXT("/Script/Angelscript.Ck_AutoTest_Net_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised");
    constexpr auto kTimeoutSeconds_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised = 30.0f;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(
    FCkFoodBoardNet_AS_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised,
    "Ck.FoodBoard.Net.AS_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FCkFoodBoardNet_AS_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised::RunTest(const FString& Parameters)
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

    ADD_LATENT_AUTOMATION_COMMAND(FCk_Latent_RunAsTestOnAllWorlds(this, FString{kAsClassPath_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised}, kTimeoutSeconds_FoodBoard_TwoRefusedSweepsInOneFrameAreBothRaised));

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
