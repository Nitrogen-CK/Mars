// The saved pantry rat candidate (/Game/ArtCandidates/PantryRat/R02, imported by
// Tools/Blender/mars_monsters/pantry_rat_r02/scripts/pantry_rat_import_ue.py) reads back from disk in a fresh editor: the
// skeletal mesh with its dedicated skeleton (26 bones, slots Body/Pink/Belly/Wood/Harness/EyePatch, Carry_Mouth and
// Carry_Drag sockets on jaw), all 35 clips on that skeleton (Phase 9: + Walk, LoadedBound 12) with the manifest's 30 Hz frame counts
// (export/PantryRat_R02_Manifest.json, frames = round(length * 30)), the five slot MIs, the den, den eye plate and cheese
// meshes, and a MID on the Body slot exposing FadeAlpha at 1. Soft paths resolved at test time; nothing is placed.
struct FMars_PantryRat_ClipExpect
{
    UPROPERTY()
    FName Name;

    UPROPERTY()
    int32 Frames = 0;

    FMars_PantryRat_ClipExpect() {}

    FMars_PantryRat_ClipExpect(FName InName, int32 InFrames)
    {
        Name = InName;
        Frames = InFrames;
    }
}

class UMars_AutoTest_PantryRat_CandidateAssetsReload : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the skeletal mesh, skeleton, slots and sockets read back", n"Step_AssertMesh");
        Add_Step("35 clips read back on the skeleton with the manifest frame counts", n"Step_AssertClips");
        Add_Step("slot MIs, den, den eye plate and cheese load", n"Step_AssertMaterialsAndProps");
        Run_Steps(InHandle);
    }

    private FString Root() const { return "/Game/ArtCandidates/PantryRat/R02"; }

    private FString SkeletonPath() const { return Root() + "/Meshes/PantryRat_R02_Mars_SKEL.PantryRat_R02_Mars_SKEL"; }

    UFUNCTION()
    private void Step_AssertMesh(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Mesh = Cast<USkeletalMesh>(LoadObject(this, Root() + "/Meshes/PantryRat_R02_Mars_SK.PantryRat_R02_Mars_SK"));
        if (ck::Is_NOT_Valid(Mesh))
        {
            FinishFailure("PantryRat_R02_Mars_SK does not load");
            return;
        }

        auto Skeleton = Cast<USkeleton>(LoadObject(this, SkeletonPath()));
        Assert_True(ck::IsValid(Skeleton), "PantryRat_R02_Mars_SKEL loads");

        auto Comp = Cast<USkeletalMeshComponent>(NewObject(this, USkeletalMeshComponent));
        Comp.SetSkeletalMeshAsset(Mesh);
        Assert_True(Comp.GetNumBones() == 26, f"26 bones (read {Comp.GetNumBones()})");
        Assert_True(Comp.GetBoneName(0) == n"root", "bone 0 is root");

        auto Expected = TArray<FName>();
        Expected.Add(n"Body");
        Expected.Add(n"Pink");
        Expected.Add(n"Belly");
        Expected.Add(n"Wood");
        Expected.Add(n"Harness");
        Expected.Add(n"EyePatch");
        auto Slots = Comp.GetMaterialSlotNames();
        auto SameOrder = Slots.Num() == Expected.Num();
        for (auto Index = 0; SameOrder && Index < Expected.Num(); ++Index)
        { SameOrder = Slots[Index] == Expected[Index]; }
        Assert_True(SameOrder, f"slot order Body, Pink, Belly, Wood, Harness, EyePatch (read {Slots.Num()} slots)");

        Assert_True(Comp.DoesSocketExist(n"Carry_Mouth"), "socket Carry_Mouth");
        Assert_True(Comp.DoesSocketExist(n"Carry_Drag"), "socket Carry_Drag");
        Assert_True(Comp.GetSocketBoneName(n"Carry_Mouth") == n"jaw", "Carry_Mouth rides jaw");
        Assert_True(Comp.GetSocketBoneName(n"Carry_Drag") == n"jaw", "Carry_Drag rides jaw");

        auto Mid = Comp.CreateDynamicMaterialInstance(0);
        Assert_True(ck::IsValid(Mid), "a MID on the Body slot");
        if (ck::IsValid(Mid))
        { Assert_True(Math::IsNearlyEqual(Mid.GetScalarParameterValue(n"FadeAlpha"), 1.0, 1e-4), "the Body MID reads FadeAlpha 1"); }
    }

    UFUNCTION()
    private void Step_AssertClips(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Clips = TArray<FMars_PantryRat_ClipExpect>();
        Clips.Add(FMars_PantryRat_ClipExpect(n"IdleBreath", 60));
        Clips.Add(FMars_PantryRat_ClipExpect(n"SniffGround", 36));
        Clips.Add(FMars_PantryRat_ClipExpect(n"SniffAir", 30));
        Clips.Add(FMars_PantryRat_ClipExpect(n"StretchAttend", 30));
        Clips.Add(FMars_PantryRat_ClipExpect(n"RearUp", 8));
        Clips.Add(FMars_PantryRat_ClipExpect(n"RearObserve", 36));
        Clips.Add(FMars_PantryRat_ClipExpect(n"RearDown", 8));
        Clips.Add(FMars_PantryRat_ClipExpect(n"BoundStart", 5));
        Clips.Add(FMars_PantryRat_ClipExpect(n"BoundCycle", 12));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Walk", 15));
        Clips.Add(FMars_PantryRat_ClipExpect(n"BoundStop", 5));
        Clips.Add(FMars_PantryRat_ClipExpect(n"TurnLeft90", 9));
        Clips.Add(FMars_PantryRat_ClipExpect(n"TurnRight90", 9));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Turn180", 14));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Startle", 9));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Backstep", 11));
        Clips.Add(FMars_PantryRat_ClipExpect(n"GuardedWatch", 45));
        Clips.Add(FMars_PantryRat_ClipExpect(n"DenEmerge", 30));
        Clips.Add(FMars_PantryRat_ClipExpect(n"DenEnter", 30));
        Clips.Add(FMars_PantryRat_ClipExpect(n"InspectSlot", 12));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Rummage", 48));
        Clips.Add(FMars_PantryRat_ClipExpect(n"Snatch", 8));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedIdle", 36));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedBound", 12));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedTurnLeft", 11));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedTurnRight", 11));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedLookBack", 15));
        Clips.Add(FMars_PantryRat_ClipExpect(n"LoadedCornered", 24));
        Clips.Add(FMars_PantryRat_ClipExpect(n"HitReact", 4));
        Clips.Add(FMars_PantryRat_ClipExpect(n"MouthRelease", 6));
        Clips.Add(FMars_PantryRat_ClipExpect(n"DeathToppleLeft", 24));
        Clips.Add(FMars_PantryRat_ClipExpect(n"DeathToppleRight", 24));
        Clips.Add(FMars_PantryRat_ClipExpect(n"DeadHold", 30));
        Clips.Add(FMars_PantryRat_ClipExpect(n"EarFlick", 12));
        Clips.Add(FMars_PantryRat_ClipExpect(n"TailSettle", 24));
        Assert_True(Clips.Num() == 35, "35 clip records");

        auto Loaded = 0;
        for (const auto& Clip : Clips)
        {
            const auto Path = f"{Root()}/Animation/PantryRat_R02_{Clip.Name}_Mars_ANIM.PantryRat_R02_{Clip.Name}_Mars_ANIM";
            auto Seq = Cast<UAnimSequence>(LoadObject(this, Path));
            if (ck::Is_NOT_Valid(Seq))
            {
                Assert_True(false, f"{Clip.Name} loads");
                continue;
            }

            Loaded++;
            const auto Frames = Math::RoundToInt(Seq.GetPlayLength() * 30.0);
            Assert_True(Frames == Clip.Frames, f"{Clip.Name}: {Clip.Frames} frames at 30 Hz (read {Frames})");
#if EDITOR
            Assert_True(ck::IsValid(Seq.GetSkeleton()) && Seq.GetSkeleton().GetPathName() == SkeletonPath(),
                f"{Clip.Name} is on PantryRat_R02_Mars_SKEL");
#endif
        }

        Assert_True(Loaded == 35, f"35 clips load (loaded {Loaded})");
    }

    UFUNCTION()
    private void Step_AssertMaterialsAndProps(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slots = TArray<FString>();
        Slots.Add("Body");
        Slots.Add("Pink");
        Slots.Add("Belly");
        Slots.Add("Wood");
        Slots.Add("Harness");
        for (const auto& Slot : Slots)
        {
            auto Mi = Cast<UMaterialInstance>(LoadObject(this, f"{Root()}/Materials/PantryRat_R02_{Slot}_Mars_MI.PantryRat_R02_{Slot}_Mars_MI"));
            Assert_True(ck::IsValid(Mi), f"PantryRat_R02_{Slot}_Mars_MI loads");
        }

        auto Props = TArray<FString>();
        Props.Add("PantryRat_R02_Den_Mars_SM");
        Props.Add("PantryRat_R02_DenEyePlate_Mars_SM");
        Props.Add("PantryRat_R02_Cheese_Mars_SM");
        for (const auto& Prop : Props)
        {
            auto Sm = Cast<UStaticMesh>(LoadObject(this, f"{Root()}/Props/{Prop}.{Prop}"));
            Assert_True(ck::IsValid(Sm), f"{Prop} loads");
        }
    }
}
