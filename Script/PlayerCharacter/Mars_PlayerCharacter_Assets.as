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

    // How far (cm) the server lets the owner's reported position stray from its own before it corrects the owner
    // (UMars_CharacterMovementComponent::ClientAuthMaxError). Co-op, not competitive: within it the owner's position is
    // taken as truth, so latency never rubber-bands the owner. 0 = stock server-authoritative correction.
    UPROPERTY()
    float32 ClientAuthMaxError = 750.0f;
}

// The capsule is the player's size: 1.5 m tall, ~78 cm across. The body others see is smaller (Config.TPBody.Scale: it
// tops out at 120 cm and is 73 cm across, so it stands inside the capsule). 1.5x the 1 m chef's capsule (half height
// 50, radius 26, crouched 35).
struct FMars_PlayerCharacter_Body
{
    UPROPERTY()
    float32 CapsuleHalfHeight = 75.0f;

    UPROPERTY()
    float32 CapsuleRadius = 39.0f;

    UPROPERTY()
    float32 CrouchedHalfHeight = 52.5f;

    // Crouched while wearing a backpack: the pack rides above the head, 140 cm, over a 130 cm crawl gap, so a worn pack
    // never passes one (UMars_SmTask_PackSetsCrouchHeight).
    UPROPERTY()
    float32 CrouchedHalfHeightWithPack = 70.0f;
}

// The player as a local damage receiver: Health, a body HitZone and a hurtbox capsule that follows the movement capsule.
// Composed only on the local host's own pawn (utils_local_session); this is not a networked combat model.
struct FMars_PlayerCharacter_Combat
{
    UPROPERTY()
    ECk_EnableDisable Enabled = ECk_EnableDisable::Enable;

    UPROPERTY()
    float32 MaxHealth = 100.0f;

    // Shakes the player's camera when a hit lands on them; null shakes nothing.
    UPROPERTY()
    TSoftClassPtr<UCameraShakeBase> HurtShake;
}

struct FMars_PlayerCharacter_View
{
    // Eye height above the capsule centre, and how fast the view eases there after a crouch or uncrouch. The config
    // asset puts it at the chef's face (see FMars_TPBody_Spec::Scale for the formula).
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

    // Worn-backpack mount relative to the capsule root (its centre, X forward): the surface of the chef's back, 25 cm
    // behind the centre and 30 cm above its feet (capsule half height 75), where a worn pack's base sits. For the body
    // at TPBody.Scale 1.5; the pack brings its own depth (its CarryOffset).
    UPROPERTY()
    FTransform BackOffset = FTransform(FRotator::ZeroRotator, FVector(-25.0, 0.0, -45.0), FVector::OneVector);

    // Belt mount relative to the capsule root: the right hip, a little ahead of the body, where a carried lantern's bail
    // hangs (AttachPoint.Mars.Belt).
    UPROPERTY()
    FTransform BeltOffset = FTransform(FRotator::ZeroRotator, FVector(12.0, 30.0, 5.0), FVector::OneVector);

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

    UPROPERTY(Category = "Body")
    FMars_PlayerCharacter_Combat Combat;

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
        PrimaryChannels.Add(GameplayTags::InteractionChannel_Mars_Primary_UsableItem);
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Primary, PrimaryChannels));

        // A station's grip: opened and closed only by the Operating state (UMars_SmTask_Operating_Grip), never by a key.
        TArray<FGameplayTag> OperateChannels;
        OperateChannels.Add(GameplayTags::InteractionChannel_Mars_Operate);
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Operate, OperateChannels));

        InteractionResolver = FCk_InteractionResolver_Spec(Mappings);

        Combat.HurtShake = assets::Impact_Medium_CameraShake_Mars_BP_Class();

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

        // The movement component is supplied by the pawn at composition; only tunables live here. The 1.5 m chef's legs
        // are 1.5x the 1 m chef's, so at the walk speed it takes 1 / 1.5 the steps: 1.6 / 1.5 = 1.07 strides per second.
        // (That matched the LowPoly body's locomotion play rate; the MiniChef body steps at its clips' own rate,
        // FMars_TPBody_Spec::AuthoredScale, and the first-person cadence was left as it was.)
        View.Gait = FCk_Gait_Spec();
        auto GaitStride = View.Gait.Get_Stride();
        GaitStride.Set_ReferenceSpeed(420.0f);
        GaitStride.Set_StridesPerSecond(1.07f);
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
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Cheer, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Cheer.AM_FPHands_Emote_Cheer")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Laugh, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Laugh.AM_FPHands_Emote_Laugh")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Bow, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Bow.AM_FPHands_Emote_Bow")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Dance, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Dance.AM_FPHands_Emote_Dance")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Shrug, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Shrug.AM_FPHands_Emote_Shrug")));
        FPHands.Emotes.Montages.Add(EMars_FPEmote::Rest, TSoftObjectPtr<UAnimMontage>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/Emotes/AM_FPHands_Emote_Rest.AM_FPHands_Emote_Rest")));

        // The hands' bob keeps the landing dip but adds no airborne lift: CkSway on the parent Hand node already lags
        // the hands while the body rises and falls (HandSway LocationFromLinearVelocity.Z). One owner per effect.
        auto HandBobAir = FPHands.Bob.Get_Air();
        HandBobAir.Set_LiftCmPerFallSpeed(0.0f);
        HandBobAir.Set_MaxLiftCm(0.0f);
        FPHands.Bob.Set_Air(HandBobAir);

        // The view 110 cm above the feet, less Body.CapsuleHalfHeight 75. It is the player's, not the body's: the
        // body others see was shrunk under it (FMars_TPBody_Spec::Scale) and the view sits inside its hood.
        View.EyeHeight.Height = 35.0f;

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
        TPBody.Head.Hat.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCharacter/Chef/Meshes/SM_Chef_Hat.SM_Chef_Hat"));

        // Big wide eyes, as the concept art: the Wide style on the body's 8.5 x 6 cm eye quads (Mars_Eyes_Assets.as).
        Eyes.Style = utils_eyes::Style_Wide().Def;

        EmoteWheel.Definition = TSoftObjectPtr<UMars_EmoteWheel_Definition>(FSoftObjectPath("/Game/Mars/Gameplay/Emotes/EmoteWheel_Mars_DA.EmoteWheel_Mars_DA"));
    }
}
