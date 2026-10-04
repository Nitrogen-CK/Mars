// Two glowing eyes on a face node (+X forward): a cosmetic style, expressions that override the style's shape for a
// while, random blinking and a look offset toward whatever the node's Gaze targets. The logic state (style and the two
// expression layers) exists on every machine; the presentation (resolved cells, blink, look, the plate) only where
// cosmetic events can run. Values reach the plate (a CkUnrealComponent plate, or a material slot of any primitive such as
// the chef body's eye slot) only through custom primitive data (Mars_Eyes_Material.as).

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EyesHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Eyes";
    RequiredFragments.Add(FMars_Feature_Eyes);
    Description = "A face node showing two eyes: a style, emote and state expressions, blinking and a look offset pushed to a plate";
}
struct FMars_Feature_Eyes {}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_eyes
{
    // 8 x 4 atlas; valid cell indices are 0..31.
    const int32 k_CellCount = 32;

    // Crossfade used when no expression is active any more and the eyes return to the style's cells.
    const float32 k_ReturnToStyleBlendSeconds = 0.08f;

    // Gap between the two blinks of a double blink.
    const float32 k_DoubleBlinkGapSeconds = 0.18f;

    // A plate group is pushed again only when one of its values moved by more than this.
    const float32 k_PushTolerance = 0.001f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Definitions
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Eyes_StyleDef
{
    UPROPERTY()
    int32 LeftCell = 1;

    UPROPERTY()
    int32 RightCell = 1;

    UPROPERTY()
    FLinearColor Color = FLinearColor(1.0f, 0.78f, 0.45f, 1.0f);

    UPROPERTY()
    float32 EmissiveStrength = 6.0f;
}

// Both cells in [0, constants_eyes::k_CellCount); EmissiveStrength and every Color channel finite and non-negative.
mixin FMars_Validation Validate(const FMars_Eyes_StyleDef& Self)
{
    const auto MaxCell = constants_eyes::k_CellCount - 1;
    if (Self.LeftCell < 0 || Self.LeftCell > MaxCell)
    { return FMars_Validation(f"LeftCell [{Self.LeftCell}] is outside [0, {MaxCell}]"); }

    if (Self.RightCell < 0 || Self.RightCell > MaxCell)
    { return FMars_Validation(f"RightCell [{Self.RightCell}] is outside [0, {MaxCell}]"); }

    if (Math::IsFinite(Self.EmissiveStrength) == false)
    { return FMars_Validation(f"EmissiveStrength [{Self.EmissiveStrength}] is not finite"); }

    if (Self.EmissiveStrength < 0.0f)
    { return FMars_Validation(f"EmissiveStrength [{Self.EmissiveStrength}] is negative"); }

    const auto& Color = Self.Color;
    const auto ColorText = f"[{Color.R}, {Color.G}, {Color.B}, {Color.A}]";
    if ((Math::IsFinite(Color.R) && Math::IsFinite(Color.G) && Math::IsFinite(Color.B) && Math::IsFinite(Color.A)) == false)
    { return FMars_Validation(f"Color {ColorText} has a channel that is not finite"); }

    if (Color.R < 0.0f || Color.G < 0.0f || Color.B < 0.0f || Color.A < 0.0f)
    { return FMars_Validation(f"Color {ColorText} has a negative channel"); }

    return FMars_Validation();
}

struct FMars_Eyes_ExpressionDef
{
    // False keeps the style's cell for that eye (a wink overrides one).
    UPROPERTY()
    bool OverrideLeft = true;

    UPROPERTY()
    bool OverrideRight = true;

    UPROPERTY()
    int32 LeftCell = 0;

    UPROPERTY()
    int32 RightCell = 0;

    UPROPERTY()
    bool AllowBlink = true;

    UPROPERTY()
    bool AllowLook = true;

    // 0 = until cleared.
    UPROPERTY()
    float32 DurationSeconds = 0.0f;

    UPROPERTY()
    float32 BlendSeconds = 0.08f;
}

// Both cells in [0, constants_eyes::k_CellCount) whether or not they override, finite non-negative durations.
mixin FMars_Validation Validate(const FMars_Eyes_ExpressionDef& Self)
{
    const auto MaxCell = constants_eyes::k_CellCount - 1;
    if (Self.LeftCell < 0 || Self.LeftCell > MaxCell)
    { return FMars_Validation(f"LeftCell [{Self.LeftCell}] is outside [0, {MaxCell}]"); }

    if (Self.RightCell < 0 || Self.RightCell > MaxCell)
    { return FMars_Validation(f"RightCell [{Self.RightCell}] is outside [0, {MaxCell}]"); }

    if (Math::IsFinite(Self.DurationSeconds) == false)
    { return FMars_Validation(f"DurationSeconds [{Self.DurationSeconds}] is not finite"); }

    if (Math::IsFinite(Self.BlendSeconds) == false)
    { return FMars_Validation(f"BlendSeconds [{Self.BlendSeconds}] is not finite"); }

    if (Self.DurationSeconds < 0.0f)
    { return FMars_Validation(f"DurationSeconds [{Self.DurationSeconds}] is negative"); }

    if (Self.BlendSeconds < 0.0f)
    { return FMars_Validation(f"BlendSeconds [{Self.BlendSeconds}] is negative"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Eyes_Spec
{
    UPROPERTY()
    FMars_Eyes_StyleDef Style;

    UPROPERTY()
    bool BlinkEnabled = true;

    UPROPERTY()
    float32 BlinkIntervalMinSeconds = 2.5f;

    UPROPERTY()
    float32 BlinkIntervalMaxSeconds = 6.0f;

    UPROPERTY()
    float32 BlinkCloseSeconds = 0.07f;

    UPROPERTY()
    float32 BlinkHoldSeconds = 0.04f;

    UPROPERTY()
    float32 BlinkOpenSeconds = 0.12f;

    UPROPERTY()
    float32 DoubleBlinkChance = 0.15f;

    UPROPERTY()
    bool LookEnabled = true;

    UPROPERTY()
    float32 LookMaxYawDeg = 60.0f;

    UPROPERTY()
    float32 LookMaxPitchDeg = 40.0f;

    UPROPERTY()
    float32 LookInterpSpeed = 10.0f;
}

// All-or-nothing: reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Eyes_Spec& Self)
{
    const auto StyleValidation = Self.Style.Validate();
    if (StyleValidation.IsValid == false)
    { return FMars_Validation(f"Style: {StyleValidation.Get_Error()}"); }

    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.BlinkIntervalMinSeconds) == false)
    { return FMars_Validation(f"BlinkIntervalMinSeconds [{Self.BlinkIntervalMinSeconds}] is not finite"); }

    if (Math::IsFinite(Self.BlinkIntervalMaxSeconds) == false)
    { return FMars_Validation(f"BlinkIntervalMaxSeconds [{Self.BlinkIntervalMaxSeconds}] is not finite"); }

    if (Math::IsFinite(Self.BlinkCloseSeconds) == false)
    { return FMars_Validation(f"BlinkCloseSeconds [{Self.BlinkCloseSeconds}] is not finite"); }

    if (Math::IsFinite(Self.BlinkHoldSeconds) == false)
    { return FMars_Validation(f"BlinkHoldSeconds [{Self.BlinkHoldSeconds}] is not finite"); }

    if (Math::IsFinite(Self.BlinkOpenSeconds) == false)
    { return FMars_Validation(f"BlinkOpenSeconds [{Self.BlinkOpenSeconds}] is not finite"); }

    if (Math::IsFinite(Self.DoubleBlinkChance) == false)
    { return FMars_Validation(f"DoubleBlinkChance [{Self.DoubleBlinkChance}] is not finite"); }

    if (Math::IsFinite(Self.LookMaxYawDeg) == false)
    { return FMars_Validation(f"LookMaxYawDeg [{Self.LookMaxYawDeg}] is not finite"); }

    if (Math::IsFinite(Self.LookMaxPitchDeg) == false)
    { return FMars_Validation(f"LookMaxPitchDeg [{Self.LookMaxPitchDeg}] is not finite"); }

    if (Math::IsFinite(Self.LookInterpSpeed) == false)
    { return FMars_Validation(f"LookInterpSpeed [{Self.LookInterpSpeed}] is not finite"); }

    if (Self.BlinkIntervalMinSeconds < 0.0f)
    { return FMars_Validation(f"BlinkIntervalMinSeconds [{Self.BlinkIntervalMinSeconds}] is negative"); }

    if (Self.BlinkIntervalMaxSeconds < 0.0f)
    { return FMars_Validation(f"BlinkIntervalMaxSeconds [{Self.BlinkIntervalMaxSeconds}] is negative"); }

    if (Self.BlinkCloseSeconds < 0.0f)
    { return FMars_Validation(f"BlinkCloseSeconds [{Self.BlinkCloseSeconds}] is negative"); }

    if (Self.BlinkHoldSeconds < 0.0f)
    { return FMars_Validation(f"BlinkHoldSeconds [{Self.BlinkHoldSeconds}] is negative"); }

    if (Self.BlinkOpenSeconds < 0.0f)
    { return FMars_Validation(f"BlinkOpenSeconds [{Self.BlinkOpenSeconds}] is negative"); }

    if (Self.BlinkIntervalMinSeconds > Self.BlinkIntervalMaxSeconds)
    { return FMars_Validation(f"BlinkIntervalMinSeconds [{Self.BlinkIntervalMinSeconds}] exceeds BlinkIntervalMaxSeconds [{Self.BlinkIntervalMaxSeconds}]"); }

    // A zero interval would start a new blink every frame.
    if (Self.BlinkEnabled && Self.BlinkIntervalMinSeconds <= 0.0f)
    { return FMars_Validation(f"BlinkIntervalMinSeconds [{Self.BlinkIntervalMinSeconds}] must be > 0 while BlinkEnabled"); }

    if (Self.DoubleBlinkChance < 0.0f || Self.DoubleBlinkChance > 1.0f)
    { return FMars_Validation(f"DoubleBlinkChance [{Self.DoubleBlinkChance}] is outside [0, 1]"); }

    if (Self.LookMaxYawDeg <= 0.0f)
    { return FMars_Validation(f"LookMaxYawDeg [{Self.LookMaxYawDeg}] must be > 0"); }

    if (Self.LookMaxPitchDeg <= 0.0f)
    { return FMars_Validation(f"LookMaxPitchDeg [{Self.LookMaxPitchDeg}] must be > 0"); }

    if (Self.LookInterpSpeed <= 0.0f)
    { return FMars_Validation(f"LookInterpSpeed [{Self.LookInterpSpeed}] must be > 0"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// An Emote is played on top of the State layer; when it expires or is cleared the State expression shows again.
enum EMars_Eyes_Layer
{
    Emote,
    State
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec's blink and look fields, which the presentation passes read every frame. The spec's Style is not kept here:
// it seeds FMars_Fragment_Eyes.Style, its one home.
struct FMars_Eyes_Tuning
{
    UPROPERTY()
    bool BlinkEnabled = true;

    UPROPERTY()
    float32 BlinkIntervalMinSeconds = 2.5f;

    UPROPERTY()
    float32 BlinkIntervalMaxSeconds = 6.0f;

    UPROPERTY()
    float32 BlinkCloseSeconds = 0.07f;

    UPROPERTY()
    float32 BlinkHoldSeconds = 0.04f;

    UPROPERTY()
    float32 BlinkOpenSeconds = 0.12f;

    UPROPERTY()
    float32 DoubleBlinkChance = 0.15f;

    UPROPERTY()
    bool LookEnabled = true;

    UPROPERTY()
    float32 LookMaxYawDeg = 60.0f;

    UPROPERTY()
    float32 LookMaxPitchDeg = 40.0f;

    UPROPERTY()
    float32 LookInterpSpeed = 10.0f;
}

struct FMars_Fragment_Eyes_Params
{
    UPROPERTY()
    FMars_Eyes_Tuning Tuning;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Logic: every machine. Written only by UMars_Processor_Eyes_Requests and (emote expiry)
// UMars_Processor_Eyes_Resolve.
struct FMars_Fragment_Eyes
{
    UPROPERTY()
    FMars_Eyes_StyleDef Style;

    UPROPERTY()
    bool HasState = false;

    UPROPERTY()
    FMars_Eyes_ExpressionDef StateExpression;

    UPROPERTY()
    bool HasEmote = false;

    UPROPERTY()
    FMars_Eyes_ExpressionDef EmoteExpression;

    UPROPERTY()
    float32 EmoteRemainingSeconds = 0.0f;
}

// Presentation: only where cosmetics can run (utils_net::Get_CanExecuteCosmeticEvents at Add).
struct FMars_Fragment_Eyes_Presentation
{
    UPROPERTY()
    int32 LeftCell = 0;

    UPROPERTY()
    int32 RightCell = 0;

    UPROPERTY()
    int32 PrevLeftCell = 0;

    UPROPERTY()
    int32 PrevRightCell = 0;

    UPROPERTY()
    float32 Blend = 1.0f;

    UPROPERTY()
    float32 BlendSeconds = 0.08f;

    UPROPERTY()
    bool AllowBlink = true;

    UPROPERTY()
    bool AllowLook = true;

    // 0 open .. 1 closed.
    UPROPERTY()
    float32 Blink = 0.0f;

    // < 0 = not blinking.
    UPROPERTY()
    float32 BlinkPhaseSeconds = -1.0f;

    UPROPERTY()
    float32 SecondsToNextBlink = 0.0f;

    UPROPERTY()
    bool DoubleBlinkPending = false;

    // True while blinking is disabled or forbidden by an active expression; the next blink is drawn afresh when it
    // starts.
    UPROPERTY()
    bool BlinkSuppressed = false;

    UPROPERTY()
    int32 BlinkCount = 0;

    // Each axis -1..1.
    UPROPERTY()
    FVector2D LookOffset;

    // What the look is drawn on: either a CkUnrealComponent plate (Set_Plate) or a primitive one of whose material slots
    // reads the custom primitive data (Set_PlateComponent; the chef body's eye slot). Setting one clears the other. The
    // primitive belongs to its actor, so it is held weakly; once it is gone nothing is pushed.
    UPROPERTY()
    FCk_Handle_UnrealComponent Plate;

    UPROPERTY()
    TWeakObjectPtr<UPrimitiveComponent> PlateComponent;

    // False until a push reaches the current plate; a new plate (or one that went away) pushes every group again.
    UPROPERTY()
    bool HasPushed = false;

    UPROPERTY()
    FMars_Eyes_MaterialValues LastPushed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Eyes_SetStyle
{
    UPROPERTY()
    FMars_Eyes_StyleDef Style;

    FMars_Request_Eyes_SetStyle() {}

    FMars_Request_Eyes_SetStyle(const FMars_Eyes_StyleDef& InStyle)
    {
        Style = InStyle;
    }
}

// Plays on the Emote layer; DurationSeconds 0 keeps it until cleared.
struct FMars_Request_Eyes_PlayExpression
{
    UPROPERTY()
    FMars_Eyes_ExpressionDef Expression;

    FMars_Request_Eyes_PlayExpression() {}

    FMars_Request_Eyes_PlayExpression(const FMars_Eyes_ExpressionDef& InExpression)
    {
        Expression = InExpression;
    }
}

// Sets the State layer; it shows whenever no emote is playing. The expression's DurationSeconds is not counted here.
struct FMars_Request_Eyes_SetStateExpression
{
    UPROPERTY()
    FMars_Eyes_ExpressionDef Expression;

    FMars_Request_Eyes_SetStateExpression() {}

    FMars_Request_Eyes_SetStateExpression(const FMars_Eyes_ExpressionDef& InExpression)
    {
        Expression = InExpression;
    }
}

// Clearing an empty layer is fine.
struct FMars_Request_Eyes_ClearExpression
{
    UPROPERTY()
    EMars_Eyes_Layer Layer = EMars_Eyes_Layer::Emote;

    FMars_Request_Eyes_ClearExpression() {}

    FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer InLayer)
    {
        Layer = InLayer;
    }
}

// Drain order SetStyle -> ClearExpression -> SetStateExpression -> PlayExpression (see
// UMars_Processor_Eyes_Requests).
struct FMars_Fragment_Eyes_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Eyes_SetStyle> SetStyleRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_ClearExpression> ClearExpressionRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_SetStateExpression> SetStateExpressionRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_PlayExpression> PlayExpressionRequests;
}
