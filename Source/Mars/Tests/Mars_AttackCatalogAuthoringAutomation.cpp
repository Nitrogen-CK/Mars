#include "Misc/AutomationTest.h"

#if WITH_EDITOR && WITH_DEV_AUTOMATION_TESTS

#include "Editor.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "HAL/FileManager.h"
#include "HAL/IConsoleManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

namespace MarsAttackCatalogAuthoringAutomation
{
    constexpr TCHAR SeedCommand[] = TEXT("Mars.Attack.SeedReferenceLoadouts");

    struct FFileSnapshot
    {
        FString Path;
        TArray<uint8> Bytes;
        FDateTime Modified;
    };

    FString ContentFile(const FString& Folder, const FString& Name, const TCHAR* Extension = TEXT(".uasset"))
    {
        return FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectContentDir(),
            TEXT("Mars/Gameplay/Monsters/Crawler"), Folder, Name + Extension));
    }

    TArray<FString> ProtectedFiles()
    {
        TArray<FString> Files;
        for (const TCHAR* Stem : {TEXT("Crawler_Jab_Mars_DA"), TEXT("Crawler_Pincer_Mars_DA"),
            TEXT("Spider_Jab_Mars_DA"), TEXT("Spider_Pincer_Mars_DA"), TEXT("Crawler_Jab_Mars_Preview_DA"),
            TEXT("Crawler_Pincer_Mars_Preview_DA"), TEXT("Spider_Jab_Mars_Preview_DA"), TEXT("Spider_Pincer_Mars_Preview_DA")})
        {
            Files.Add(ContentFile(TEXT("Actions"), Stem));
            Files.Add(ContentFile(TEXT("Actions"), Stem, TEXT(".ckexport")));
        }
        return Files;
    }

    TArray<FString> ApprovedNewFiles()
    {
        TArray<FString> Files;
        for (const TCHAR* Preset : {TEXT("Crawler4"), TEXT("Crawler6"), TEXT("Spider6")})
        {
            for (const bool Endpoint : {false, true})
            {
                const TCHAR* Variant = Endpoint ? TEXT("EndpointDemo") : TEXT("Parity");
                Files.Add(ContentFile(TEXT("AttackCatalog"), FString::Printf(TEXT("%s_%sLoadout_Mars_DA"), Preset, Variant)));
                for (const TCHAR* Id : {TEXT("Pincer"), TEXT("Jab"), TEXT("SwipeRight"), TEXT("SwipeLeft")})
                {
                    if (!Endpoint && (FCString::Strcmp(Id, TEXT("SwipeRight")) == 0 || FCString::Strcmp(Id, TEXT("SwipeLeft")) == 0))
                    { continue; }
                    Files.Add(ContentFile(TEXT("AttackCatalog"), FString::Printf(TEXT("%s_%s_%s_Mars_DA"), Preset, Variant, Id)));
                }
            }
            for (const TCHAR* Clip : {TEXT("EndpointPincer"), TEXT("SwipeRight"), TEXT("SwipeLeft")})
            { Files.Add(ContentFile(TEXT("Actions"), FString::Printf(TEXT("%s_%s_Mars_DA"), Preset, Clip))); }
        }
        return Files;
    }

    bool CaptureFiles(FAutomationTestBase& Test, const TArray<FString>& Paths, bool RequireAll,
        TArray<FFileSnapshot>& OutSnapshots)
    {
        OutSnapshots.Reset();
        bool Valid = true;
        for (const FString& Path : Paths)
        {
            if (!IFileManager::Get().FileExists(*Path))
            {
                if (RequireAll) { Test.AddError(FString::Printf(TEXT("Required persisted file is missing: %s"), *Path)); Valid = false; }
                continue;
            }
            FFileSnapshot Snapshot;
            Snapshot.Path = Path;
            if (!FFileHelper::LoadFileToArray(Snapshot.Bytes, *Path) || Snapshot.Bytes.IsEmpty())
            { Test.AddError(FString::Printf(TEXT("Cannot read nonempty persisted file: %s"), *Path)); Valid = false; continue; }
            Snapshot.Modified = IFileManager::Get().GetTimeStamp(*Path);
            OutSnapshots.Add(MoveTemp(Snapshot));
        }
        return Valid;
    }

    bool VerifyUnchanged(FAutomationTestBase& Test, const TArray<FFileSnapshot>& Before, const TCHAR* Stage)
    {
        bool Valid = true;
        for (const FFileSnapshot& Snapshot : Before)
        {
            TArray<uint8> Current;
            const bool Read = FFileHelper::LoadFileToArray(Current, *Snapshot.Path);
            Valid &= Test.TestTrue(FString::Printf(TEXT("%s preserves exact bytes: %s"), Stage, *Snapshot.Path), Read && Current == Snapshot.Bytes);
            Valid &= Test.TestTrue(FString::Printf(TEXT("%s preserves mtime: %s"), Stage, *Snapshot.Path),
                IFileManager::Get().GetTimeStamp(*Snapshot.Path) == Snapshot.Modified);
        }
        return Valid;
    }
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FMars_AttackCatalog_EditorSeedReferenceGraphs,
    "Ck.Mars.AttackCatalog.EditorSeedReferenceGraphs", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FMars_AttackCatalog_EditorSeedReferenceGraphs::RunTest(const FString& Parameters)
{
    using namespace MarsAttackCatalogAuthoringAutomation;
    if (GEditor == nullptr || GEngine == nullptr || GEditor->PlayWorld != nullptr || GIsPlayInEditorWorld)
    { AddError(TEXT("Reference graph persistence requires editor context outside PIE; no seed command dispatched")); return false; }
    UWorld* World = GEditor->GetEditorWorldContext().World();
    if (!IsValid(World) || World->WorldType != EWorldType::Editor)
    { AddError(TEXT("No valid editor world; no seed command dispatched")); return false; }
    for (const FWorldContext& Context : GEngine->GetWorldContexts())
    {
        if (Context.WorldType == EWorldType::PIE && IsValid(Context.World()))
        { AddError(TEXT("A PIE world is active; no seed command dispatched")); return false; }
    }
    if (IConsoleManager::Get().FindConsoleObject(SeedCommand) == nullptr)
    { AddError(TEXT("Existing AS reference seeder console command is not registered")); return false; }

    const TArray<FString> Legacy = ProtectedFiles();
    const TArray<FString> Approved = ApprovedNewFiles();
    if (!TestEqual(TEXT("Protected source/preview file inventory"), Legacy.Num(), 16) ||
        !TestEqual(TEXT("Approved new package inventory"), Approved.Num(), 33))
    { return false; }
    TArray<FFileSnapshot> LegacyBefore;
    TArray<FFileSnapshot> ExistingNewBefore;
    if (!CaptureFiles(*this, Legacy, true, LegacyBefore) || !CaptureFiles(*this, Approved, false, ExistingNewBefore))
    { return false; }

    // Exec's boolean proves command dispatch only. Persistence is proved by actual nonempty files, and the main gate
    // must also read the AS seeder's completed/created/skipped/saveCalls report from this run's editor log.
    if (!TestTrue(TEXT("Existing AS seed command dispatches outside PIE"), GEngine->Exec(World, SeedCommand)))
    { return false; }
    bool Valid = VerifyUnchanged(*this, LegacyBefore, TEXT("First seed"));
    Valid &= VerifyUnchanged(*this, ExistingNewBefore, TEXT("First seed skips existing new packages"));
    TArray<FFileSnapshot> NewAfterFirst;
    Valid &= CaptureFiles(*this, Approved, true, NewAfterFirst);
    Valid &= TestEqual(TEXT("All approved new assets persisted"), NewAfterFirst.Num(), 33);
    if (!Valid) { return false; }

    TArray<FString> AllFiles = Legacy;
    AllFiles.Append(Approved);
    TestEqual(TEXT("Second seed preserves every declared source and reference file"), AllFiles.Num(), 49);
    TArray<FFileSnapshot> AllBeforeRepeat;
    if (!CaptureFiles(*this, AllFiles, true, AllBeforeRepeat)) { return false; }
    if (!TestTrue(TEXT("Same AS seed command dispatches again outside PIE"), GEngine->Exec(World, SeedCommand)))
    { return false; }
    Valid &= VerifyUnchanged(*this, AllBeforeRepeat, TEXT("Second seed"));
    if (Valid)
    { AddInfo(TEXT("Validated persisted 33 reference assets and exact bytes/mtime of all 49 declared files after repeat. Read this run's AS seed report for completed=true and second-call zero creations/saveCalls; dispatch alone is not that result.")); }
    return Valid;
}

#endif
