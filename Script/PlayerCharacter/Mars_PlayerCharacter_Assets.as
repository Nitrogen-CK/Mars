struct FMars_PlayerCharacter_Speeds
{
    UPROPERTY()
    float32 Walk = 420.0f;

    UPROPERTY()
    float32 Sprint = 700.0f;

    UPROPERTY()
    float32 Crouch = 220.0f;

    // Along a ladder's climb line (the Climber's spec).
    UPROPERTY()
    float32 Climb = 220.0f;
}

struct FMars_PlayerCharacter_Movement
{
    UPROPERTY()
    FMars_PlayerCharacter_Speeds Speeds;

    UPROPERTY()
    float32 MaxAcceleration = 2400.0f;

    UPROPERTY()
    float32 BrakingDecelerationWalking = 2400.0f;

    UPROPERTY()
    float32 JumpZVelocity = 480.0f;

    UPROPERTY()
    float32 GravityScale = 1.6f;

    UPROPERTY()
    float32 AirControl = 0.35f;
}

struct FMars_PlayerCharacter_Body
{
    UPROPERTY()
    float32 CapsuleHalfHeight = 88.0f;

    UPROPERTY()
    float32 CapsuleRadius = 34.0f;

    UPROPERTY()
    float32 CrouchedHalfHeight = 52.0f;
}

struct FMars_PlayerCharacter_View
{
    // Eye height above the capsule centre, and how fast the view eases there after a crouch or uncrouch.
    UPROPERTY()
    FMars_EyeHeight_Spec EyeHeight;

    // Stride clock of the character (CkGait); the head and hand bobs read it.
    UPROPERTY()
    FCk_Gait_Spec Gait;

    // Positional camera bob on the head node (CkGait Bob).
    UPROPERTY()
    FCk_Bob_Spec HeadBob;

    UPROPERTY()
    FMars_PlayerViewpoint_Spec Viewpoint;
}

struct FMars_PlayerCharacter_Inventory
{
    UPROPERTY()
    int32 BagSlotCount = 3;

    // Worn-backpack mount relative to the capsule root (X forward).
    UPROPERTY()
    FTransform BackOffset = FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0), FVector::OneVector);

    // Drop held past this arms a throw.
    UPROPERTY()
    float32 ThrowHoldSeconds = 0.35f;
}

class UMars_PlayerCharacter_Config : UDataAsset
{
    UPROPERTY(Category = "Movement")
    FMars_PlayerCharacter_Movement Movement;

    UPROPERTY(Category = "Body")
    FMars_PlayerCharacter_Body Body;

    UPROPERTY(Category = "View")
    FMars_PlayerCharacter_View View;

    UPROPERTY(Category = "Interaction")
    FCk_InteractionResolver_Spec InteractionResolver;

    UPROPERTY(Category = "Inventory")
    FMars_PlayerCharacter_Inventory Inventory;

    // Damped-spring lag of the Hand node (and everything on it) behind the view (CkSway).
    UPROPERTY(Category = "Hands")
    FCk_Sway_Spec HandSway;

    // The gloves; HandNode is supplied by the pawn at composition.
    UPROPERTY(Category = "Hands")
    FMars_FPHands_Spec FPHands;

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
        PrimaryChannels.Add(GameplayTags::InteractionChannel_Mars_Primary_UsableItem);
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Primary, PrimaryChannels));

        // A station's grip: opened and closed only by the Operating state (UMars_SmTask_Operating_Grip), never by a key.
        TArray<FGameplayTag> OperateChannels;
        OperateChannels.Add(GameplayTags::InteractionChannel_Mars_Operate);
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Operate, OperateChannels));

        InteractionResolver = FCk_InteractionResolver_Spec(Mappings);

        // The view trace reaches 250 uu; the gloves reach anything it hits (FPHands MaxReachCm unset = uncapped).
        View.Viewpoint.InteractionTraceDistance = 250.0f;

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

        // The movement component is supplied by the pawn at composition; only tunables live here.
        View.Gait = FCk_Gait_Spec();
        auto GaitStride = View.Gait.Get_Stride();
        GaitStride.Set_ReferenceSpeed(420.0f);
        View.Gait.Set_Stride(GaitStride);

        // The gait is supplied by the pawn at composition (Set_Gait); only tunables live here. No rotational bob.
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

        View.HeadBob = FCk_Bob_Spec();
        View.HeadBob.Set_Stride(HeadBobStride);
        View.HeadBob.Set_Air(HeadBobAir);
        View.HeadBob.Set_LagRate(14.0f);
        View.HeadBob.Set_BreathCm(0.25f);
        View.HeadBob.Set_MaxOffsetCm(10.0f);

        FPHands.Visual.Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Meshes/SK_FPHands.SK_FPHands"));
        FPHands.Visual.AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/ABP_FPHands.ABP_FPHands_C"));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Wave, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Wave.AM_FPHands_Emote_Wave")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::ThumbsUp, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_ThumbsUp.AM_FPHands_Emote_ThumbsUp")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Point, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Point.AM_FPHands_Emote_Point")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Clap, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Clap.AM_FPHands_Emote_Clap")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::FlipOff, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_FlipOff.AM_FPHands_Emote_FlipOff")));

        // The hands' bob keeps the landing dip but adds no airborne lift: CkSway on the parent Hand node already lags
        // the hands while the body rises and falls (HandSway LocationFromLinearVelocity.Z). One owner per effect.
        auto HandBobAir = FPHands.Bob.Get_Air();
        HandBobAir.Set_LiftCmPerFallSpeed(0.0f);
        HandBobAir.Set_MaxLiftCm(0.0f);
        FPHands.Bob.Set_Air(HandBobAir);

        EmoteWheel.Definition = TSoftObjectPtr<UMars_EmoteWheel_Definition>(FSoftObjectPath("/Game/Mars/Gameplay/Emotes/EmoteWheel_Mars_DA.EmoteWheel_Mars_DA"));
    }
}
