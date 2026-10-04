class UMars_PlayerCharacter_Config : UDataAsset
{
    UPROPERTY(Category = "Movement")
    float32 WalkSpeed = 420.0f;

    UPROPERTY(Category = "Movement")
    float32 SprintSpeed = 700.0f;

    UPROPERTY(Category = "Movement")
    float32 CrouchSpeed = 220.0f;

    // Along a ladder's climb line (the Climber's spec).
    UPROPERTY(Category = "Movement")
    float32 ClimbSpeed = 220.0f;

    UPROPERTY(Category = "Movement")
    float32 MaxAcceleration = 2400.0f;

    UPROPERTY(Category = "Movement")
    float32 BrakingDecelerationWalking = 2400.0f;

    UPROPERTY(Category = "Movement")
    float32 JumpZVelocity = 480.0f;

    UPROPERTY(Category = "Movement")
    float32 GravityScale = 1.6f;

    UPROPERTY(Category = "Movement")
    float32 AirControl = 0.35f;

    // The capsule is the chef's size: 1.5 m tall (Config.TPBody.Scale stands the 1 m SK_Chef at 1.5 m), ~78 cm across
    // (the scaled chef's torso is about +-37 cm wide). 1.5x the 1 m chef's capsule (half height 50, radius 26, crouched 35).
    UPROPERTY(Category = "Body")
    float32 CapsuleHalfHeight = 75.0f;

    UPROPERTY(Category = "Body")
    float32 CapsuleRadius = 39.0f;

    UPROPERTY(Category = "Body")
    float32 CrouchedHalfHeight = 52.5f;

    // Eye height above the capsule centre, and how fast the view eases there after a crouch or uncrouch. The config
    // asset puts it at the chef's face (see FMars_TPBody_Spec::Scale for the formula).
    UPROPERTY(Category = "Camera")
    FMars_EyeHeight_Spec EyeHeight;

    // Stride clock of the character (CkGait); the head and hand bobs read it. Tune in the Mars_PlayerCharacter_Config asset.
    UPROPERTY(Category = "Camera")
    FCk_Gait_Spec Gait;

    // PEAK-style positional camera bob on the head node (CkGait Bob). Roll/pitch stay 0: PEAK's walk has no rotational bob.
    UPROPERTY(Category = "Camera")
    FCk_Bob_Spec HeadBob;

    UPROPERTY(Category = "Interaction")
    FMars_PlayerViewpoint_Spec Viewpoint;

    UPROPERTY(Category = "Interaction")
    FCk_InteractionResolver_Spec InteractionResolver;

    UPROPERTY(Category = "Inventory")
    int32 BagSlotCount = 3;

    // Hand attach point relative to the first-person camera (X forward, Y right, Z up).
    UPROPERTY(Category = "Inventory")
    FTransform HandOffset = FTransform(FRotator::ZeroRotator, FVector(60.0, 25.0, -20.0), FVector::OneVector);

    // Damped-spring lag of the held item behind the hand (CkSway). Tune in the Mars_PlayerCharacter_Config asset.
    UPROPERTY(Category = "Inventory")
    FCk_Sway_Spec HandSway;

    // Worn-backpack mount relative to the capsule root (X forward): the 1.5 m chef's upper back, 75 cm above its feet
    // (the 1 m chef's was (-30, 0, 0)).
    UPROPERTY(Category = "Inventory")
    FTransform BackOffset = FTransform(FRotator::ZeroRotator, FVector(-45.0, 0.0, 0.0), FVector::OneVector);

    UPROPERTY(Category = "Inventory")
    float32 ThrowHoldSeconds = 0.35f;

    UPROPERTY(Category = "Hands")
    FMars_FPHands_Spec FPHands;

    // The third-person chef body other players see (the character's Mesh), its hat and where its eyes sit.
    UPROPERTY(Category = "Body")
    FMars_TPBody_Spec TPBody;

    // The chef's eyes, drawn by the body's eye slot (TPBody.Head.Face): part of the body, so its owner never sees them.
    UPROPERTY(Category = "Body")
    FMars_Eyes_Spec Eyes;

    // The wheel's entries live in its Definition asset; only the pointer feel is tuned here.
    UPROPERTY(Category = "Emotes")
    FMars_EmoteWheel_Spec EmoteWheel;
}

namespace mars
{
    asset Mars_PlayerCharacter_Config of UMars_PlayerCharacter_Config
    {
        TArray<FGameplayTag> UseChannels;
        UseChannels.Add(GameplayTags::InteractionChannel_Mars_Use);

        TArray<FCk_InteractionResolver_IntentChannelMapping> Mappings;
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, UseChannels));

        TArray<FGameplayTag> PrimaryChannels;
        PrimaryChannels.Add(GameplayTags::ResolveGameplayTag(n"InteractionChannel.Mars.Primary.UsableItem"));
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(
            GameplayTags::ResolveGameplayTag(n"InteractionIntent.Mars.Primary"), PrimaryChannels));

        // A station's grip: opened and closed only by the Operating state (UMars_SmTask_Operating_Grip), never by a key.
        TArray<FGameplayTag> OperateChannels;
        OperateChannels.Add(GameplayTags::ResolveGameplayTag(n"InteractionChannel.Mars.Operate"));
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(
            GameplayTags::ResolveGameplayTag(n"InteractionIntent.Mars.Operate"), OperateChannels));

        InteractionResolver = FCk_InteractionResolver_Spec(Mappings);

        // The view trace reaches 150 uu; the gloves reach anything it hits (FPHands MaxReachCm 0 = uncapped).
        Viewpoint.InteractionTraceDistance = 150.0f;

        HandSway = FCk_Sway_Spec();
        HandSway.Set_Location(FCk_Sway_Response(FVector(12.0, 16.0, 12.0), 3.5f, 0.7f));
        HandSway.Set_Rotation(FCk_Sway_Response(FVector(8.0, 10.0, 12.0), 4.5f, 0.75f));
        HandSway.Set_RotationFromAngularVelocity(FVector(0.008, 0.020, 0.024));
        HandSway.Set_LocationFromLinearVelocity(FVector(0.012, 0.012, 0.016));
        HandSway.Set_LateralCmFromYawRate(0.040f);
        HandSway.Set_VerticalCmFromPitchRate(0.030f);
        HandSway.Set_RollDegFromLateralVelocity(0.012f);
        HandSway.Set_PitchDegFromForwardVelocity(0.0f);
        HandSway.Set_TeleportDistanceCm(300.0f);
        HandSway.Set_TeleportAngleDeg(90.0f);

        Gait = FCk_Gait_Spec();   // the movement component is supplied by the pawn at Add; only tunables live here
        // The 1.5 m chef's legs are 1.5x the 1 m chef's, so at WalkSpeed it takes 1 / 1.5 the steps: 1.6 / 1.5 = 1.07 strides
        // per second, matching the body's locomotion play rate (FMars_TPBody_Spec::AuthoredScale).
        auto GaitStride = Gait.Get_Stride();
        GaitStride.Set_ReferenceSpeed(420.0f);
        GaitStride.Set_StridesPerSecond(1.07f);
        Gait.Set_Stride(GaitStride);

        // The gait is supplied by the pawn at composition (Set_Gait); only tunables live here.
        auto HeadBobStride = FCk_Bob_StrideParams();
        HeadBobStride.Set_VerticalCm(6.0f);
        HeadBobStride.Set_LateralCm(3.0f);
        HeadBobStride.Set_ForwardCm(0.0f);
        HeadBobStride.Set_RollDeg(0.0f);
        HeadBobStride.Set_PitchDeg(0.0f);

        auto HeadBobAir = FCk_Bob_AirParams();
        HeadBobAir.Set_LiftCmPerFallSpeed(0.004f);
        HeadBobAir.Set_MaxLiftCm(3.0f);
        HeadBobAir.Set_LandKickPerImpactSpeed(0.05f);
        HeadBobAir.Set_MaxLandKick(40.0f);
        HeadBobAir.Set_Spring(FCk_Bob_SpringResponse(4.0f, 0.6f));

        HeadBob = FCk_Bob_Spec();
        HeadBob.Set_Stride(HeadBobStride);
        HeadBob.Set_Air(HeadBobAir);
        HeadBob.Set_LagRate(14.0f);
        HeadBob.Set_BreathCm(0.25f);
        HeadBob.Set_MaxOffsetCm(10.0f);

        FPHands.Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Meshes/SK_FPHands.SK_FPHands"));
        FPHands.AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/ABP_FPHands.ABP_FPHands_C"));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Wave.AM_FPHands_Emote_Wave")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_ThumbsUp.AM_FPHands_Emote_ThumbsUp")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Point.AM_FPHands_Emote_Point")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Clap.AM_FPHands_Emote_Clap")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_FlipOff.AM_FPHands_Emote_FlipOff")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Cheer.AM_FPHands_Emote_Cheer")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Laugh.AM_FPHands_Emote_Laugh")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Bow.AM_FPHands_Emote_Bow")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Dance.AM_FPHands_Emote_Dance")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Shrug.AM_FPHands_Emote_Shrug")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Rest.AM_FPHands_Emote_Rest")));

        // The hands' bob keeps the landing dip but adds no airborne lift: CkSway on the parent Hand node already lags
        // the hands while the body rises and falls (HandSway LocationFromLinearVelocity.Z). One owner per effect.
        auto HandBobAir = FPHands.Bob.Get_Air();
        HandBobAir.Set_LiftCmPerFallSpeed(0.0f);
        HandBobAir.Set_MaxLiftCm(0.0f);
        FPHands.Bob.Set_Air(HandBobAir);

        // The view at the chef's face: 71.1 cm (unscaled) * TPBody.Scale 1.6453 = 117.0 cm above the feet, less
        // CapsuleHalfHeight 75 (FMars_TPBody_Spec::Scale). The 1 m chef's was 28.
        EyeHeight.Height = 42.0f;

        TPBody.Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Meshes/SK_Chef.SK_Chef"));
        TPBody.AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/ABP_Chef.ABP_Chef_C"));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Wave.AM_Chef_Emote_Wave")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_ThumbsUp.AM_Chef_Emote_ThumbsUp")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Point.AM_Chef_Emote_Point")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Clap.AM_Chef_Emote_Clap")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_FlipOff.AM_Chef_Emote_FlipOff")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Cheer.AM_Chef_Emote_Cheer")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Laugh.AM_Chef_Emote_Laugh")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Bow.AM_Chef_Emote_Bow")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Dance.AM_Chef_Emote_Dance")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Shrug.AM_Chef_Emote_Shrug")));
        TPBody.Montages.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/Emotes/AM_Chef_Emote_Rest.AM_Chef_Emote_Rest")));
        TPBody.Montages.StrikeMontage = TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Anims/AM_Chef_Strike.AM_Chef_Strike"));
        TPBody.Head.Hat.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Meshes/SM_Chef_Hat.SM_Chef_Hat"));

        EmoteWheel.Definition = TSoftObjectPtr<UMars_EmoteWheel_Definition>(FSoftObjectPath("/Game/Mars/Gameplay/Emotes/EmoteWheel_Mars_DA.EmoteWheel_Mars_DA"));
    }
}
