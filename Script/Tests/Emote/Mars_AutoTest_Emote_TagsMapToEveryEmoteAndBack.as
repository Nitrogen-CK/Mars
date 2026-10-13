// Every EMars_FPEmote has a registered Mars.Emote.<name> tag, and the tag maps back to the same emote; tags that are not
// emotes map to nothing. The player config carries one glove and one body montage per emote, and the body spec's rules
// hold: the 1.5 m chef (scale, capsule, eye height, locomotion play rate), its hat and its face.
class UMars_AutoTest_Emote_TagsMapToEveryEmoteAndBack : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("map every emote to its tag and back", n"Step_RoundTrip");
        Add_Step("reject tags that are not emotes", n"Step_NotEmotes");
        Add_Step("check the configured montage tables and the body spec", n"Step_Config");
        Add_Step("check the 1.5 m chef: scale, capsule, eye height, play rate, hat and face", n"Step_BodySize");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_RoundTrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Canonical order: the emote wheel definition and both montage tables follow it.
        TArray<FString> Expected;
        Expected.Add("Wave");
        Expected.Add("ThumbsUp");
        Expected.Add("Point");
        Expected.Add("Clap");
        Expected.Add("FlipOff");
        Expected.Add("Cheer");
        Expected.Add("Laugh");
        Expected.Add("Bow");
        Expected.Add("Dance");
        Expected.Add("Shrug");
        Expected.Add("Rest");

        Assert_Equals_Int(utils_fphands::Get_EmoteCount(), Expected.Num(), "EMars_FPEmote has the 11 canonical emotes");

        for (int32 Index = 0; Index < Expected.Num(); ++Index)
        {
            const auto Emote = EMars_FPEmote(Index);
            const auto Tag = utils_fphands::Get_EmoteTag(Emote);
            Assert_True(Tag.IsValid(), f"emote {Index} has a registered tag");
            Assert_Equals_String(Tag.ToString(), f"Mars.Emote.{Expected[Index]}", f"emote {Index} is Mars.Emote.{Expected[Index]}");

            auto MappedBack = EMars_FPEmote::Wave;
            const auto Found = utils_fphands::TryGet_Emote(Tag, MappedBack);
            Assert_True(Found && MappedBack == Emote, f"Mars.Emote.{Expected[Index]} maps back to emote {Index}");
        }
    }

    UFUNCTION()
    private void Step_NotEmotes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Emote = EMars_FPEmote::Rest;
        Assert_False(utils_fphands::TryGet_Emote(FGameplayTag(), Emote), "an empty tag is no emote");
        Assert_False(utils_fphands::TryGet_Emote(GameplayTags::ResolveGameplayTag(n"Mars.Intent.EmoteWheel"), Emote),
            "a tag outside Mars.Emote is no emote");
        Assert_True(Emote == EMars_FPEmote::Rest, "a failed lookup leaves the out value alone");
    }

    UFUNCTION()
    private void Step_Config(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Count = utils_fphands::Get_EmoteCount();
        auto Config = mars::Mars_PlayerCharacter_Config;
        Assert_Equals_Int(Config.FPHands.Emotes.Montages.Num(), Count, "one glove montage per emote");
        Assert_Equals_Int(Config.TPBody.Montages.EmoteMontages.Num(), Count, "one body montage per emote");

        const auto Configured = Config.TPBody.Validate();
        Assert_True(Configured.IsValid(), f"the configured body spec is valid ({Configured.Get_Error()})");

        auto ShortTable = Config.TPBody;
        ShortTable.Montages.EmoteMontages.RemoveAt(ShortTable.Montages.EmoteMontages.Num() - 1);
        Assert_False(ShortTable.Validate().IsValid(), "a body montage table missing an emote is rejected");

        auto NoScale = Config.TPBody;
        NoScale.Scale = 0.0f;
        Assert_False(NoScale.Validate().IsValid(), "a zero body scale is rejected");

        auto ScaledOffset = Config.TPBody;
        ScaledOffset.MeshOffset.SetScale3D(FVector(2.0, 2.0, 2.0));
        Assert_False(ScaledOffset.Validate().IsValid(), "a scaled MeshOffset is rejected (Scale sizes the body)");

        Assert_False(FMars_TPBody_Spec().Validate().IsValid(), "a body spec without a mesh is rejected");
    }

    UFUNCTION()
    private void Step_BodySize(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = mars::Mars_PlayerCharacter_Config;
        const auto& Body = Config.TPBody;

        // The body others see is smaller than the 1.5 m capsule: 79.67 (the unscaled MiniChef body's top, hat excluded)
        // at Scale 1.5 is 120 cm.
        Assert_True(Math::Abs(Body.Scale - 1.5f) < 0.001f, f"the body others see tops out at 120 cm (Scale [{Body.Scale}] ~ 1.5)");
        Assert_True(Math::Abs(Config.Body.CapsuleHalfHeight - 75.0f) < 0.001f, f"the capsule stands 1.5 m (half height [{Config.Body.CapsuleHalfHeight}])");
        Assert_True(Config.Body.CrouchedHalfHeight < Config.Body.CapsuleHalfHeight, "the crouched capsule is shorter than the standing one");

        // The body stands on the capsule's base, standing and crouched (the capsule's centre drops by the half heights'
        // difference when it shrinks, and the body rises by as much relative to it).
        const auto StandingZ = Body.Get_BodyLocation(Config.Body.CapsuleHalfHeight, 0.0f).Z;
        Assert_True(Math::Abs(StandingZ + Config.Body.CapsuleHalfHeight) < 0.001, f"the standing body's feet are on the capsule's base (mesh z [{StandingZ}])");
        const auto CrouchDrop = Config.Body.CapsuleHalfHeight - Config.Body.CrouchedHalfHeight;
        const auto CrouchedZ = Body.Get_BodyLocation(Config.Body.CapsuleHalfHeight, CrouchDrop).Z;
        Assert_True(Math::Abs(CrouchedZ + Config.Body.CrouchedHalfHeight) < 0.001, f"the crouched body's feet are on the crouched capsule's base (mesh z [{CrouchedZ}])");

        // The view sits inside the body's hood: above its face centre (58.37 cm unscaled above the feet) and under its
        // top (79.67), both measured from the capsule centre like the eye height.
        const auto FaceHeight = 58.37f * Body.Scale - Config.Body.CapsuleHalfHeight;
        const auto HoodTop = 79.67f * Body.Scale - Config.Body.CapsuleHalfHeight;
        Assert_True(Config.View.EyeHeight.Height > FaceHeight && Config.View.EyeHeight.Height < HoodTop,
            f"the eye height [{Config.View.EyeHeight.Height}] is between the body's face [{FaceHeight}] and its hood's top [{HoodTop}]");

        // The MiniChef's walk clips are built for its legs at Scale 1.8828; the smaller body steps faster over the same ground.
        Assert_True(Math::Abs(Body.AuthoredScale - 1.8828f) < 0.001f, f"the locomotion clips are authored at Scale 1.8828 (AuthoredScale [{Body.AuthoredScale}])");
        Assert_True(Math::Abs(Body.Get_LocomotionPlayRate() - Body.AuthoredScale / Body.Scale) < 0.001f, f"the locomotion play rate [{Body.Get_LocomotionPlayRate()}] is AuthoredScale / Scale");

        Assert_False(Body.Head.Hat.Mesh.IsNull(), "the chef has a hat mesh");
        Assert_True(Body.Head.Hat.Socket == n"Hat", f"the hat rides the Hat socket (got [{Body.Head.Hat.Socket}])");
        Assert_True(Body.Head.Face.Bone == n"head", f"the face follows the head bone (got [{Body.Head.Face.Bone}])");
        Assert_True(Config.Eyes.Validate().IsValid(), f"the chef's eyes spec is valid ({Config.Eyes.Validate().Get_Error()})");

        auto NoHat = Body;
        NoHat.Head.Hat.Mesh = TSoftObjectPtr<UStaticMesh>();
        Assert_True(NoHat.Validate().IsValid(), "the hat is optional");

        auto HatWithoutSocket = Body;
        HatWithoutSocket.Head.Hat.Socket = NAME_None;
        Assert_False(HatWithoutSocket.Validate().IsValid(), "a hat mesh without a socket is rejected");

        Assert_True(Body.Head.Face.EyesSlot == n"M_EyePlate", f"the eyes are drawn on the M_EyePlate slot (got [{Body.Head.Face.EyesSlot}])");

        auto NoEyesSlot = Body;
        NoEyesSlot.Head.Face.EyesSlot = NAME_None;
        Assert_False(NoEyesSlot.Validate().IsValid(), "a face without an eyes slot is rejected");

        auto ScaledFace = Body;
        ScaledFace.Head.Face.Offset.SetScale3D(FVector(2.0, 2.0, 2.0));
        Assert_False(ScaledFace.Validate().IsValid(), "a scaled face offset is rejected (Scale sizes the body)");

        auto BrokenFace = Body;
        BrokenFace.Head.Face.Offset.SetTranslation(FVector(Math::Sqrt(-1.0), 0.0, 0.0));
        Assert_False(BrokenFace.Validate().IsValid(), "a non-finite face offset is rejected");

        auto NoBone = Body;
        NoBone.Head.Face.Bone = NAME_None;
        Assert_False(NoBone.Validate().IsValid(), "a face without a bone is rejected");
    }
}
