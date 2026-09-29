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

    UPROPERTY(Category = "Inventory")
    float32 ThrowHoldSeconds = 0.35f;
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
    }
}
