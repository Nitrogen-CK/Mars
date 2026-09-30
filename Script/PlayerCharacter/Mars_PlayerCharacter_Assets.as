class UMars_PlayerCharacter_Config : UDataAsset
{
    UPROPERTY(Category = "Movement")
    float32 WalkSpeed = 420.0f;

    UPROPERTY(Category = "Movement")
    float32 SprintSpeed = 700.0f;

    UPROPERTY(Category = "Movement")
    float32 CrouchSpeed = 220.0f;

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

    UPROPERTY(Category = "Body")
    float32 CapsuleHalfHeight = 88.0f;

    UPROPERTY(Category = "Body")
    float32 CapsuleRadius = 34.0f;

    UPROPERTY(Category = "Body")
    float32 CrouchedHalfHeight = 52.0f;

    // Above the capsule center.
    UPROPERTY(Category = "Camera")
    float32 EyeHeight = 64.0f;

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

    // Worn-backpack mount relative to the capsule root (X forward).
    UPROPERTY(Category = "Inventory")
    FTransform BackOffset = FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0), FVector::OneVector);

    UPROPERTY(Category = "Inventory")
    float32 ThrowHoldSeconds = 0.35f;

    UPROPERTY(Category = "Hands")
    FMars_FPHands_Spec FPHands;
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

        InteractionResolver = FCk_InteractionResolver_Spec(Mappings);

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

        FPHands.Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Meshes/SK_FPHands.SK_FPHands"));
        FPHands.AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/ABP_FPHands.ABP_FPHands_C"));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Wave.AM_FPHands_Emote_Wave")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_ThumbsUp.AM_FPHands_Emote_ThumbsUp")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Point.AM_FPHands_Emote_Point")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Clap.AM_FPHands_Emote_Clap")));
        FPHands.EmoteMontages.Add(TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_FlipOff.AM_FPHands_Emote_FlipOff")));
    }
}
