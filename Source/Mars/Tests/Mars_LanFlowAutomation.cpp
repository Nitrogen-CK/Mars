#include "Misc/AutomationTest.h"

#if WITH_EDITOR && WITH_DEV_AUTOMATION_TESTS

#include "Editor.h"
#include "Editor/UnrealEdEngine.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/NetConnection.h"
#include "Engine/NetDriver.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/GameStateBase.h"
#include "GameFramework/PlayerController.h"
#include "HAL/IConsoleManager.h"
#include "IPAddress.h"
#include "../Online/Mars_GameSession.h"
#include "PlayInEditorDataTypes.h"
#include "Settings/LevelEditorPlaySettings.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UnrealEdGlobals.h"
#include "UObject/SoftObjectPath.h"
#include "UObject/StructOnScope.h"
#include "UObject/UnrealType.h"

DEFINE_LOG_CATEGORY_STATIC(LogMarsLanAutomation, Log, All);

namespace MarsLanAutomation
{
    constexpr TCHAR CampMapObject[] = TEXT("/Game/Mars/Maps/Camp_Mars_MAP.Camp_Mars_MAP");
    constexpr TCHAR FlowClassPath[] = TEXT("/Script/Angelscript.Mars_LanFlow_Subsystem");
    constexpr TCHAR CampControllerClassPath[] = TEXT("/Script/Angelscript.Mars_Camp_PlayerController");
    constexpr TCHAR GameplayControllerClassPath[] = TEXT("/Script/Angelscript.Mars_Gameplay_PlayerController");
    constexpr TCHAR ChefClassPath[] = TEXT("/Script/Angelscript.Mars_PlayerCharacter");
    constexpr TCHAR ViewerClassPath[] = TEXT("/Script/Angelscript.Mars_Camp_ViewerPawn");

    struct FParty
    {
        FName ServiceId = NAME_None;
        int32 Revision = INDEX_NONE;
        bool bDeparting = false;
    };

    struct FPlaySettingsSnapshot
    {
        int32 Clients = 1;
        EPlayNetMode NetMode = EPlayNetMode::PIE_Standalone;
        bool bOneProcess = true;
        bool bSeparateServer = false;
    };

    UWorld* WorldFor(UGameInstance* GameInstance)
    {
        UWorld* World = IsValid(GameInstance) ? GameInstance->GetWorld() : nullptr;
        return IsValid(World) && World->GetGameInstance() == GameInstance ? World : nullptr;
    }

    TArray<UGameInstance*> InitialInstances()
    {
        TArray<TPair<int32, UGameInstance*>> Ordered;
        if (GEngine == nullptr)
        { return {}; }

        for (const FWorldContext& Context : GEngine->GetWorldContexts())
        {
            UWorld* World = Context.World();
            if (Context.WorldType == EWorldType::PIE && IsValid(World) && World->HasBegunPlay() &&
                World->GetNetMode() == NM_Standalone && IsValid(World->GetGameInstance()))
            { Ordered.Emplace(Context.PIEInstance, World->GetGameInstance()); }
        }
        Ordered.Sort([](const auto& A, const auto& B) { return A.Key < B.Key; });

        TArray<UGameInstance*> Result;
        for (const auto& Entry : Ordered)
        { Result.Add(Entry.Value); }
        return Result;
    }

    bool HasAnyPIEWorld()
    {
        if (GEngine == nullptr)
        { return false; }
        for (const FWorldContext& Context : GEngine->GetWorldContexts())
        {
            if (Context.WorldType == EWorldType::PIE && IsValid(Context.World()))
            { return true; }
        }
        return false;
    }

    UObject* FlowFor(UGameInstance* GameInstance)
    {
        UClass* Class = FSoftClassPath(FlowClassPath).TryLoadClass<UGameInstanceSubsystem>();
        return IsValid(GameInstance) && IsValid(Class) ? GameInstance->GetSubsystemBase(Class) : nullptr;
    }

    bool Invoke(UObject* Target, FName Name, FName NameArgument = NAME_None, const FString* StringArgument = nullptr)
    {
        UFunction* Function = IsValid(Target) ? Target->FindFunction(Name) : nullptr;
        if (Function == nullptr)
        { return false; }

        FStructOnScope Parameters(Function);
        uint8* Memory = Parameters.GetStructMemory();
        if (NameArgument != NAME_None)
        {
            FNameProperty* Property = FindFProperty<FNameProperty>(Function, TEXT("InServiceId"));
            if (Property == nullptr)
            { return false; }
            Property->SetPropertyValue_InContainer(Memory, NameArgument);
        }
        if (StringArgument != nullptr)
        {
            FStrProperty* Property = FindFProperty<FStrProperty>(Function, TEXT("InDirectAddress"));
            if (Property == nullptr)
            { return false; }
            Property->SetPropertyValue_InContainer(Memory, *StringArgument);
        }
        Target->ProcessEvent(Function, Memory);
        return true;
    }

    bool IsFlowSessionActive(UObject* Flow)
    {
        UFunction* Function = IsValid(Flow) ? Flow->FindFunction(TEXT("IsSessionActive")) : nullptr;
        FBoolProperty* Result = Function != nullptr ? CastField<FBoolProperty>(Function->GetReturnProperty()) : nullptr;
        if (Result == nullptr)
        { return false; }
        FStructOnScope Parameters(Function);
        Flow->ProcessEvent(Function, Parameters.GetStructMemory());
        return Result->GetPropertyValue_InContainer(Parameters.GetStructMemory());
    }

    bool IsFlowBusy(UObject* Flow)
    {
        UFunction* Function = IsValid(Flow) ? Flow->FindFunction(TEXT("IsBusy")) : nullptr;
        FBoolProperty* Result = Function != nullptr ? CastField<FBoolProperty>(Function->GetReturnProperty()) : nullptr;
        if (Result == nullptr)
        { return true; }
        FStructOnScope Parameters(Function);
        Flow->ProcessEvent(Function, Parameters.GetStructMemory());
        return Result->GetPropertyValue_InContainer(Parameters.GetStructMemory());
    }

    FString FlowStatus(UObject* Flow)
    {
        UFunction* Function = IsValid(Flow) ? Flow->FindFunction(TEXT("GetStatus")) : nullptr;
        FStrProperty* Result = Function != nullptr ? CastField<FStrProperty>(Function->GetReturnProperty()) : nullptr;
        if (Result == nullptr)
        { return {}; }
        FStructOnScope Parameters(Function);
        Flow->ProcessEvent(Function, Parameters.GetStructMemory());
        return Result->GetPropertyValue_InContainer(Parameters.GetStructMemory());
    }

    FName CommittedService(UObject* Flow)
    {
        UFunction* Function = IsValid(Flow) ? Flow->FindFunction(TEXT("GetCommittedServiceId")) : nullptr;
        FNameProperty* Result = Function != nullptr ? CastField<FNameProperty>(Function->GetReturnProperty()) : nullptr;
        if (Result == nullptr)
        { return NAME_None; }
        FStructOnScope Parameters(Function);
        Flow->ProcessEvent(Function, Parameters.GetStructMemory());
        return Result->GetPropertyValue_InContainer(Parameters.GetStructMemory());
    }

    bool IsMap(UWorld* World, const TCHAR* Leaf)
    {
        if (!IsValid(World))
        { return false; }
        const FString Package = World->GetOutermost()->GetName();
        const FString Directory = TEXT("/Game/Mars/Maps/");
        const FString Plain = Directory + Leaf;
        return Package == Plain || (Package.StartsWith(Directory + TEXT("UEDPIE_")) &&
            Package.EndsWith(FString(TEXT("_")) + Leaf));
    }

    bool IsScriptClass(const AActor* Actor, const TCHAR* Path)
    {
        UClass* Class = FSoftClassPath(Path).TryLoadClass<AActor>();
        return IsValid(Actor) && IsValid(Class) && Actor->IsA(Class);
    }

    AMars_GameSession* CampSession(UWorld* World)
    {
        if (!IsValid(World))
        { return nullptr; }
        for (TActorIterator<AMars_GameSession> It(World); It; ++It)
        { return *It; }
        return nullptr;
    }

    bool ReadParty(UWorld* World, FParty& Out)
    {
        AGameStateBase* State = IsValid(World) ? World->GetGameState() : nullptr;
        FStructProperty* Party = IsValid(State) ? FindFProperty<FStructProperty>(State->GetClass(), TEXT("_PartyState")) : nullptr;
        if (Party == nullptr)
        { return false; }

        const void* Memory = Party->ContainerPtrToValuePtr<void>(State);
        const FNameProperty* Service = FindFProperty<FNameProperty>(Party->Struct, TEXT("ServiceId"));
        const FIntProperty* Revision = FindFProperty<FIntProperty>(Party->Struct, TEXT("Revision"));
        const FBoolProperty* Departing = FindFProperty<FBoolProperty>(Party->Struct, TEXT("IsDeparting"));
        if (Service == nullptr || Revision == nullptr || Departing == nullptr)
        { return false; }

        Out.ServiceId = Service->GetPropertyValue_InContainer(Memory);
        Out.Revision = Revision->GetPropertyValue_InContainer(Memory);
        Out.bDeparting = Departing->GetPropertyValue_InContainer(Memory);
        return true;
    }

    APlayerController* LocalController(UWorld* World)
    {
        if (!IsValid(World))
        { return nullptr; }
        for (FConstPlayerControllerIterator It = World->GetPlayerControllerIterator(); It; ++It)
        {
            APlayerController* Controller = It->Get();
            if (IsValid(Controller) && Controller->IsLocalController())
            { return Controller; }
        }
        return nullptr;
    }

    bool HasRemoteController(UWorld* World)
    {
        if (!IsValid(World))
        { return false; }
        for (FConstPlayerControllerIterator It = World->GetPlayerControllerIterator(); It; ++It)
        {
            APlayerController* Controller = It->Get();
            if (IsValid(Controller) && !Controller->IsLocalController() && IsValid(Controller->GetNetConnection()))
            { return true; }
        }
        return false;
    }

    class FDirectJoinCommand final : public IAutomationLatentCommand
    {
    public:
        explicit FDirectJoinCommand(FAutomationTestBase* InTest) : Test(InTest) {}

        ~FDirectJoinCommand() override
        {
            RestoreSettings();
            RestoreTravelCVar();
            if (bStartedPIE && GUnrealEd != nullptr && HasAnyPIEWorld())
            { GUnrealEd->RequestEndPlayMap(); }
            HostInstance.Reset();
            GuestInstance.Reset();
        }

        bool Update() override
        {
            if (Stage == EStage::Start)
            { Start(); }
            else if (Stage == EStage::WaitInitial)
            { WaitInitial(); }
            else if (Stage == EStage::WaitHost)
            { WaitHost(); }
            else if (Stage == EStage::WaitGuest)
            { WaitGuest(); }
            else if (Stage == EStage::WaitReplication)
            { WaitReplication(); }
            else if (Stage == EStage::WaitSandbox)
            { WaitSandbox(); }
            else if (Stage == EStage::WaitReturn)
            { WaitReturn(); }
            else if (Stage == EStage::WaitRecovery)
            { WaitRecovery(); }
            else if (Stage == EStage::Teardown)
            { Teardown(); }

            if (Stage != EStage::Done && FPlatformTime::Seconds() - StageEntered > StageLimit)
            {
                Test->AddError(FString::Printf(TEXT("Timed out in LAN stage %d: host %s; guest %s"),
                    static_cast<int32>(Stage), *Describe(HostInstance.Get()), *Describe(GuestInstance.Get())));
                if (Stage == EStage::Teardown)
                { Advance(EStage::Done, 0.0); }
                else
                { BeginTeardown(); }
            }
            return Stage == EStage::Done;
        }

    private:
        enum class EStage : uint8
        {
            Start, WaitInitial, WaitHost, WaitGuest, WaitReplication,
            WaitSandbox, WaitReturn, WaitRecovery, Teardown, Done
        };

        FString Describe(UGameInstance* Instance) const
        {
            UWorld* World = WorldFor(Instance);
            APlayerController* PC = LocalController(World);
            return FString::Printf(TEXT("world=%s map=%s net=%d pc=%s pawn=%s active=%d busy=%d service=%s status=%s"),
                *GetNameSafe(World), IsValid(World) ? *World->GetOutermost()->GetName() : TEXT("none"),
                IsValid(World) ? static_cast<int32>(World->GetNetMode()) : -1,
                *GetNameSafe(PC), *GetNameSafe(IsValid(PC) ? PC->GetPawn() : nullptr),
                IsFlowSessionActive(FlowFor(Instance)) ? 1 : 0,
                IsFlowBusy(FlowFor(Instance)) ? 1 : 0,
                *CommittedService(FlowFor(Instance)).ToString(),
                *FlowStatus(FlowFor(Instance)));
        }

        void Advance(EStage Next, double Timeout)
        {
            Stage = Next;
            StageEntered = FPlatformTime::Seconds();
            StageLimit = Timeout;
        }

        void Fail(const FString& Message)
        {
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin failure in stage %d: %s"),
                static_cast<int32>(Stage), *Message);
            Test->AddError(Message);
            BeginTeardown();
        }

        void RestoreSettings()
        {
            if (!bSettingsOverridden)
            { return; }
            ULevelEditorPlaySettings* Settings = GetMutableDefault<ULevelEditorPlaySettings>();
            if (Settings != nullptr)
            {
                Settings->SetPlayNumberOfClients(SavedSettings.Clients);
                Settings->SetPlayNetMode(SavedSettings.NetMode);
                Settings->SetRunUnderOneProcess(SavedSettings.bOneProcess);
                Settings->bLaunchSeparateServer = SavedSettings.bSeparateServer;
            }
            bSettingsOverridden = false;
        }

        void RestoreTravelCVar()
        {
            if (!bTravelCVarOverridden)
            { return; }
            if (IConsoleVariable* Variable = IConsoleManager::Get().FindConsoleVariable(TEXT("net.AllowPIESeamlessTravel")))
            { Variable->Set(SavedTravelCVar, SavedTravelPriority); }
            bTravelCVarOverridden = false;
        }

        bool EnablePIESeamlessTravel()
        {
            IConsoleVariable* Variable = IConsoleManager::Get().FindConsoleVariable(TEXT("net.AllowPIESeamlessTravel"));
            if (Variable == nullptr)
            { return false; }
            SavedTravelCVar = Variable->GetInt();
            SavedTravelPriority = static_cast<EConsoleVariableFlags>(Variable->GetFlags() & ECVF_SetByMask);
            bTravelCVarOverridden = true;
            Variable->Set(1, SavedTravelPriority);
            return Variable->GetInt() == 1;
        }

        void BeginTeardown()
        {
            if (Stage == EStage::Teardown || Stage == EStage::Done)
            { return; }
            RestoreSettings();
            RestoreTravelCVar();
            if (!bStartedPIE)
            { Advance(EStage::Done, 0.0); return; }
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin requesting owned PIE teardown from stage %d"),
                static_cast<int32>(Stage));
            if (GUnrealEd != nullptr && HasAnyPIEWorld())
            { GUnrealEd->RequestEndPlayMap(); }
            Advance(EStage::Teardown, 20.0);
        }

        void Start()
        {
            if (GUnrealEd == nullptr || HasAnyPIEWorld())
            { Fail(TEXT("LAN test needs a free editor PIE session")); return; }

            ULevelEditorPlaySettings* Settings = GetMutableDefault<ULevelEditorPlaySettings>();
            if (Settings == nullptr)
            { Fail(TEXT("No LevelEditorPlaySettings")); return; }
            Settings->GetPlayNumberOfClients(SavedSettings.Clients);
            Settings->GetPlayNetMode(SavedSettings.NetMode);
            Settings->GetRunUnderOneProcess(SavedSettings.bOneProcess);
            SavedSettings.bSeparateServer = Settings->bLaunchSeparateServer;
            bSettingsOverridden = true;
            Settings->SetPlayNumberOfClients(2);
            Settings->SetPlayNetMode(EPlayNetMode::PIE_Standalone);
            Settings->SetRunUnderOneProcess(true);
            Settings->bLaunchSeparateServer = false;

            FRequestPlaySessionParams Params;
            Params.WorldType = EPlaySessionWorldType::PlayInEditor;
            Params.GlobalMapOverride = CampMapObject;
            GUnrealEd->RequestPlaySession(Params);
            bStartedPIE = true;
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin requested two offline PIE worlds"));
            Advance(EStage::WaitInitial, 35.0);
        }

        void WaitInitial()
        {
            TArray<UGameInstance*> Instances = InitialInstances();
            if (Instances.Num() != 2 || !IsValid(LocalController(WorldFor(Instances[0]))) ||
                !IsValid(LocalController(WorldFor(Instances[1]))))
            { return; }

            HostInstance = Instances[0];
            GuestInstance = Instances[1];
            UObject* HostFlow = FlowFor(HostInstance.Get());
            UObject* GuestFlow = FlowFor(GuestInstance.Get());
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin initial PIE worlds ready: host=%s guest=%s hostFlow=%s guestFlow=%s"),
                *GetNameSafe(WorldFor(HostInstance.Get())), *GetNameSafe(WorldFor(GuestInstance.Get())),
                *GetNameSafe(HostFlow), *GetNameSafe(GuestFlow));
            if (!IsValid(HostFlow) || !IsValid(GuestFlow) || !Invoke(HostFlow, TEXT("Host")))
            { Fail(TEXT("Could not invoke Host on the first offline PIE instance")); return; }
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin invoked Host; waiting for listen world"));
            Advance(EStage::WaitHost, 45.0);
        }

        void WaitHost()
        {
            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UObject* HostFlow = FlowFor(HostInstance.Get());
            if (!IsValid(HostWorld) || HostWorld->GetNetMode() != NM_ListenServer ||
                !IsFlowSessionActive(HostFlow) || !IsValid(LocalController(HostWorld)) ||
                !IsValid(LocalController(HostWorld)->GetPawn()))
            { return; }

            UNetDriver* Driver = HostWorld->GetNetDriver();
            const TSharedPtr<const FInternetAddr> Address = IsValid(Driver) ? Driver->GetLocalAddr() : nullptr;
            const int32 Port = Address.IsValid() ? Address->GetPort() : 0;
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            if (Port <= 0 || !IsValid(GuestWorld) || GuestWorld->GetNetMode() != NM_Standalone)
            { Fail(TEXT("Host did not expose a listening port while guest remained offline")); return; }

            const FString DirectAddress = FString::Printf(TEXT("127.0.0.1:%d"), Port);
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin host listening on port %d; invoking guest Join"), Port);
            if (!Invoke(FlowFor(GuestInstance.Get()), TEXT("Join"), NAME_None, &DirectAddress))
            { Fail(TEXT("Could not invoke Join(address) on the offline guest")); return; }
            Advance(EStage::WaitGuest, 45.0);
        }

        void WaitGuest()
        {
            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            APlayerController* GuestPC = LocalController(GuestWorld);
            if (!IsValid(HostWorld) || !IsValid(GuestWorld) || HostWorld->GetNetMode() != NM_ListenServer ||
                GuestWorld->GetNetMode() != NM_Client || !IsFlowSessionActive(FlowFor(GuestInstance.Get())) ||
                !IsValid(GuestPC) || !IsValid(GuestPC->GetPawn()) || !IsValid(GuestPC->GetNetConnection()) ||
                GuestPC->HasAuthority() || !HasRemoteController(HostWorld))
            { return; }

            FParty HostParty;
            FParty GuestParty;
            if (!ReadParty(HostWorld, HostParty) || !ReadParty(GuestWorld, GuestParty) ||
                HostParty.Revision != GuestParty.Revision || HostParty.ServiceId != GuestParty.ServiceId)
            { return; }
            if (!HostParty.ServiceId.IsNone() || HostParty.bDeparting)
            { Fail(TEXT("Party state was already committed before host selection")); return; }

            InitialRevision = HostParty.Revision;
            APlayerController* HostPC = LocalController(WorldFor(HostInstance.Get()));
            if (!Invoke(HostPC, TEXT("Server_CommitService"), TEXT("Sandbox")))
            { Fail(TEXT("Host service commit RPC was unavailable")); return; }
            Advance(EStage::WaitReplication, 10.0);
        }

        void WaitReplication()
        {
            FParty HostParty;
            FParty GuestParty;
            if (!ReadParty(WorldFor(HostInstance.Get()), HostParty) ||
                !ReadParty(WorldFor(GuestInstance.Get()), GuestParty))
            { return; }
            if (HostParty.Revision != InitialRevision + 1 || HostParty.ServiceId != FName(TEXT("Sandbox")) ||
                HostParty.bDeparting || GuestParty.Revision != HostParty.Revision ||
                GuestParty.ServiceId != HostParty.ServiceId || GuestParty.bDeparting)
            { return; }

            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            APlayerController* HostPC = LocalController(HostWorld);
            APlayerController* GuestPC = LocalController(GuestWorld);
            AMars_GameSession* Session = CampSession(HostWorld);
            if (!IsScriptClass(HostPC, CampControllerClassPath) ||
                !IsScriptClass(GuestPC, CampControllerClassPath) ||
                !IsScriptClass(IsValid(HostPC) ? HostPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsScriptClass(IsValid(GuestPC) ? GuestPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsValid(Session) || !Session->IsAdmissionOpen() ||
                CommittedService(FlowFor(HostInstance.Get())) != FName(TEXT("Sandbox")))
            { Fail(TEXT("Committed camp lacks chef, open admission, or persistent host selection")); return; }
            if (!EnablePIESeamlessTravel())
            { Fail(TEXT("net.AllowPIESeamlessTravel is unavailable or cannot be enabled")); return; }

            if (!Invoke(HostPC, TEXT("Server_RequestDepart")))
            { Fail(TEXT("Host departure RPC was unavailable")); return; }
            FParty Departing;
            if (!ReadParty(HostWorld, Departing) || Departing.Revision != InitialRevision + 2 ||
                Departing.ServiceId != FName(TEXT("Sandbox")) || !Departing.bDeparting ||
                Session->IsAdmissionOpen())
            { Fail(TEXT("Departure did not synchronously close Camp admission and advance party revision")); return; }

            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin host departed; waiting for both Sandbox worlds"));
            Advance(EStage::WaitSandbox, 60.0);
        }

        void WaitSandbox()
        {
            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            APlayerController* HostPC = LocalController(HostWorld);
            APlayerController* GuestPC = LocalController(GuestWorld);
            if (!IsMap(HostWorld, TEXT("Sandbox_Mars_MAP")) ||
                !IsMap(GuestWorld, TEXT("Sandbox_Mars_MAP")) ||
                HostWorld->GetNetMode() != NM_ListenServer || GuestWorld->GetNetMode() != NM_Client ||
                !IsFlowSessionActive(FlowFor(HostInstance.Get())) ||
                !IsFlowSessionActive(FlowFor(GuestInstance.Get())) ||
                !IsScriptClass(HostPC, GameplayControllerClassPath) ||
                !IsScriptClass(GuestPC, GameplayControllerClassPath) ||
                !IsScriptClass(IsValid(HostPC) ? HostPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsScriptClass(IsValid(GuestPC) ? GuestPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsValid(IsValid(GuestPC) ? GuestPC->GetNetConnection() : nullptr) ||
                !HasRemoteController(HostWorld) ||
                CommittedService(FlowFor(HostInstance.Get())) != FName(TEXT("Sandbox")))
            { return; }

            AMars_GameSession* Session = CampSession(HostWorld);
            if (!IsValid(Session) || Session->IsAdmissionOpen())
            { Fail(TEXT("Sandbox admission was not closed")); return; }
            if (!Invoke(HostPC, TEXT("Server_ReturnToCamp")))
            { Fail(TEXT("Host return-to-Camp RPC was unavailable")); return; }
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin both players reached Sandbox; waiting for Camp return"));
            Advance(EStage::WaitReturn, 60.0);
        }

        void WaitReturn()
        {
            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            APlayerController* HostPC = LocalController(HostWorld);
            APlayerController* GuestPC = LocalController(GuestWorld);
            if (!IsMap(HostWorld, TEXT("Camp_Mars_MAP")) ||
                !IsMap(GuestWorld, TEXT("Camp_Mars_MAP")) ||
                HostWorld->GetNetMode() != NM_ListenServer || GuestWorld->GetNetMode() != NM_Client ||
                !IsFlowSessionActive(FlowFor(HostInstance.Get())) ||
                !IsFlowSessionActive(FlowFor(GuestInstance.Get())) ||
                !IsScriptClass(HostPC, CampControllerClassPath) ||
                !IsScriptClass(GuestPC, CampControllerClassPath) ||
                !IsScriptClass(IsValid(HostPC) ? HostPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsScriptClass(IsValid(GuestPC) ? GuestPC->GetPawn() : nullptr, ChefClassPath) ||
                !IsValid(IsValid(GuestPC) ? GuestPC->GetNetConnection() : nullptr) ||
                !HasRemoteController(HostWorld))
            { return; }

            FParty HostParty;
            FParty GuestParty;
            if (!ReadParty(HostWorld, HostParty) || !ReadParty(GuestWorld, GuestParty) ||
                HostParty.ServiceId != FName(TEXT("Sandbox")) ||
                GuestParty.ServiceId != HostParty.ServiceId ||
                GuestParty.Revision != HostParty.Revision ||
                HostParty.bDeparting || GuestParty.bDeparting ||
                CommittedService(FlowFor(HostInstance.Get())) != FName(TEXT("Sandbox")))
            { return; }
            AMars_GameSession* Session = CampSession(HostWorld);
            if (!IsValid(Session) || !Session->IsAdmissionOpen())
            { Fail(TEXT("Returned Camp admission was not open")); return; }

            if (!Invoke(FlowFor(HostInstance.Get()), TEXT("ReturnToMenu")))
            { Fail(TEXT("Could not make host leave the LAN session")); return; }
            UE_LOG(LogMarsLanAutomation, Display, TEXT("DirectJoin both players returned to Camp; host closed session"));
            Advance(EStage::WaitRecovery, 60.0);
        }

        void WaitRecovery()
        {
            UWorld* HostWorld = WorldFor(HostInstance.Get());
            UWorld* GuestWorld = WorldFor(GuestInstance.Get());
            APlayerController* HostPC = LocalController(HostWorld);
            APlayerController* GuestPC = LocalController(GuestWorld);
            if (!IsMap(HostWorld, TEXT("Camp_Mars_MAP")) ||
                !IsMap(GuestWorld, TEXT("Camp_Mars_MAP")) ||
                HostWorld->GetNetMode() != NM_Standalone || GuestWorld->GetNetMode() != NM_Standalone ||
                IsFlowSessionActive(FlowFor(HostInstance.Get())) ||
                IsFlowSessionActive(FlowFor(GuestInstance.Get())) ||
                IsFlowBusy(FlowFor(HostInstance.Get())) ||
                IsFlowBusy(FlowFor(GuestInstance.Get())) ||
                !IsScriptClass(HostPC, CampControllerClassPath) ||
                !IsScriptClass(GuestPC, CampControllerClassPath) ||
                !IsScriptClass(IsValid(HostPC) ? HostPC->GetPawn() : nullptr, ViewerClassPath) ||
                !IsScriptClass(IsValid(GuestPC) ? GuestPC->GetPawn() : nullptr, ViewerClassPath) ||
                !CommittedService(FlowFor(HostInstance.Get())).IsNone() ||
                FlowStatus(FlowFor(GuestInstance.Get())).IsEmpty())
            { return; }

            Test->AddInfo(TEXT("Host/Join, replicated service, paired Sandbox/return travel, and guest disconnect recovery passed."));
            BeginTeardown();
        }

        void Teardown()
        {
            RestoreSettings();
            RestoreTravelCVar();
            if (bStartedPIE && HasAnyPIEWorld())
            { return; }
            HostInstance.Reset();
            GuestInstance.Reset();
            bStartedPIE = false;
            Advance(EStage::Done, 0.0);
        }

        FAutomationTestBase* Test = nullptr;
        EStage Stage = EStage::Start;
        double StageEntered = FPlatformTime::Seconds();
        double StageLimit = 30.0;
        FPlaySettingsSnapshot SavedSettings;
        bool bSettingsOverridden = false;
        bool bTravelCVarOverridden = false;
        bool bStartedPIE = false;
        int32 SavedTravelCVar = 0;
        EConsoleVariableFlags SavedTravelPriority = ECVF_SetByConstructor;
        TWeakObjectPtr<UGameInstance> HostInstance;
        TWeakObjectPtr<UGameInstance> GuestInstance;
        int32 InitialRevision = INDEX_NONE;
    };
}

// RequiresUser keeps this test out of the unattended gate (the toolbox passes -unattended) until it is green; it stays
// listed in the Session Frontend for a manual run.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FMars_Lan_DirectJoin, "Mars.LAN.DirectJoin",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter |
    EAutomationTestFlags::RequiresUser)

bool FMars_Lan_DirectJoin::RunTest(const FString& Parameters)
{
    ADD_LATENT_AUTOMATION_COMMAND(MarsLanAutomation::FDirectJoinCommand(this));
    return true;
}

#endif
