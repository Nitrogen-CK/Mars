// Two glowing eyes on a face node (+X forward): a cosmetic style, expressions that override the style's shape for a
// while, random blinking and a look offset toward whatever the node's Gaze targets. The logic state (style and the two
// expression layers) exists on every machine; the presentation (resolved cells, blink, look, the plate) only where
// cosmetic events can run. Values reach the plate (a CkUnrealComponent plate, or a primitive one of whose material slots
// uses the eye-plate look, such as the chef body's eye slot) only through custom primitive data (utils_eyes::Push_Group).

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

    // The custom-primitive-data layout the eye-plate look reads (MarsEyePlate in Mars_Eyes_Look_Assets.as). Each group's
    // floats are consecutive from its slot.
    const int32 k_Slot_Cells = 0;    // LeftCell, RightCell, PrevLeftCell, PrevRightCell
    const int32 k_Slot_Anim = 4;     // Blend, BlinkLeft, BlinkRight, Strength
    const int32 k_Slot_Look = 8;     // LookX, LookY
    const int32 k_Slot_Color = 10;   // r, g, b, (unused)
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
    // Unset keeps the style's cell for that eye (a wink sets only one).
    UPROPERTY()
    TOptional<int32> LeftCell;

    UPROPERTY()
    TOptional<int32> RightCell;

    UPROPERTY()
    bool AllowBlink = true;

    UPROPERTY()
    bool AllowLook = true;

    // Unset = until cleared.
    UPROPERTY()
    TOptional<float32> DurationSeconds;

    UPROPERTY()
    float32 BlendSeconds = 0.08f;
}

// Each set cell in [0, constants_eyes::k_CellCount), finite non-negative durations.
mixin FMars_Validation Validate(const FMars_Eyes_ExpressionDef& Self)
{
    const auto MaxCell = constants_eyes::k_CellCount - 1;
    if (Self.LeftCell.IsSet() && (Self.LeftCell.GetValue() < 0 || Self.LeftCell.GetValue() > MaxCell))
    { return FMars_Validation(f"LeftCell [{Self.LeftCell.GetValue()}] is outside [0, {MaxCell}]"); }

    if (Self.RightCell.IsSet() && (Self.RightCell.GetValue() < 0 || Self.RightCell.GetValue() > MaxCell))
    { return FMars_Validation(f"RightCell [{Self.RightCell.GetValue()}] is outside [0, {MaxCell}]"); }

    if (Self.DurationSeconds.IsSet() && Math::IsFinite(Self.DurationSeconds.GetValue()) == false)
    { return FMars_Validation(f"DurationSeconds [{Self.DurationSeconds.GetValue()}] is not finite"); }

    if (Math::IsFinite(Self.BlendSeconds) == false)
    { return FMars_Validation(f"BlendSeconds [{Self.BlendSeconds}] is not finite"); }

    if (Self.DurationSeconds.IsSet() && Self.DurationSeconds.GetValue() < 0.0f)
    { return FMars_Validation(f"DurationSeconds [{Self.DurationSeconds.GetValue()}] is negative"); }

    if (Self.BlendSeconds < 0.0f)
    { return FMars_Validation(f"BlendSeconds [{Self.BlendSeconds}] is negative"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Random blinking: a blink closes over CloseSeconds, holds, opens over OpenSeconds; the next one is drawn from
// [IntervalMinSeconds, IntervalMaxSeconds], or a second one follows after a short gap (DoubleBlinkChance).
struct FMars_Eyes_BlinkSpec
{
    UPROPERTY()
    float32 IntervalMinSeconds = 2.5f;

    UPROPERTY()
    float32 IntervalMaxSeconds = 6.0f;

    UPROPERTY()
    float32 CloseSeconds = 0.07f;

    UPROPERTY()
    float32 HoldSeconds = 0.04f;

    UPROPERTY()
    float32 OpenSeconds = 0.12f;

    UPROPERTY()
    float32 DoubleBlinkChance = 0.15f;
}

// All-or-nothing: reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Eyes_BlinkSpec& Self)
{
    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.IntervalMinSeconds) == false)
    { return FMars_Validation(f"IntervalMinSeconds [{Self.IntervalMinSeconds}] is not finite"); }

    if (Math::IsFinite(Self.IntervalMaxSeconds) == false)
    { return FMars_Validation(f"IntervalMaxSeconds [{Self.IntervalMaxSeconds}] is not finite"); }

    if (Math::IsFinite(Self.CloseSeconds) == false)
    { return FMars_Validation(f"CloseSeconds [{Self.CloseSeconds}] is not finite"); }

    if (Math::IsFinite(Self.HoldSeconds) == false)
    { return FMars_Validation(f"HoldSeconds [{Self.HoldSeconds}] is not finite"); }

    if (Math::IsFinite(Self.OpenSeconds) == false)
    { return FMars_Validation(f"OpenSeconds [{Self.OpenSeconds}] is not finite"); }

    if (Math::IsFinite(Self.DoubleBlinkChance) == false)
    { return FMars_Validation(f"DoubleBlinkChance [{Self.DoubleBlinkChance}] is not finite"); }

    if (Self.IntervalMinSeconds < 0.0f)
    { return FMars_Validation(f"IntervalMinSeconds [{Self.IntervalMinSeconds}] is negative"); }

    if (Self.IntervalMaxSeconds < 0.0f)
    { return FMars_Validation(f"IntervalMaxSeconds [{Self.IntervalMaxSeconds}] is negative"); }

    if (Self.CloseSeconds < 0.0f)
    { return FMars_Validation(f"CloseSeconds [{Self.CloseSeconds}] is negative"); }

    if (Self.HoldSeconds < 0.0f)
    { return FMars_Validation(f"HoldSeconds [{Self.HoldSeconds}] is negative"); }

    if (Self.OpenSeconds < 0.0f)
    { return FMars_Validation(f"OpenSeconds [{Self.OpenSeconds}] is negative"); }

    if (Self.IntervalMinSeconds > Self.IntervalMaxSeconds)
    { return FMars_Validation(f"IntervalMinSeconds [{Self.IntervalMinSeconds}] exceeds IntervalMaxSeconds [{Self.IntervalMaxSeconds}]"); }

    // A zero interval would start a new blink every frame.
    if (Self.IntervalMinSeconds <= 0.0f)
    { return FMars_Validation(f"IntervalMinSeconds [{Self.IntervalMinSeconds}] must be > 0"); }

    if (Self.DoubleBlinkChance < 0.0f || Self.DoubleBlinkChance > 1.0f)
    { return FMars_Validation(f"DoubleBlinkChance [{Self.DoubleBlinkChance}] is outside [0, 1]"); }

    return FMars_Validation();
}

// The look offset: the Gaze target's yaw / pitch scaled by MaxYawDeg / MaxPitchDeg, eased at InterpSpeed.
struct FMars_Eyes_LookSpec
{
    UPROPERTY()
    float32 MaxYawDeg = 60.0f;

    UPROPERTY()
    float32 MaxPitchDeg = 40.0f;

    UPROPERTY()
    float32 InterpSpeed = 10.0f;
}

// All-or-nothing: reports the first failing rule.
mixin FMars_Validation Validate(const FMars_Eyes_LookSpec& Self)
{
    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.MaxYawDeg) == false)
    { return FMars_Validation(f"MaxYawDeg [{Self.MaxYawDeg}] is not finite"); }

    if (Math::IsFinite(Self.MaxPitchDeg) == false)
    { return FMars_Validation(f"MaxPitchDeg [{Self.MaxPitchDeg}] is not finite"); }

    if (Math::IsFinite(Self.InterpSpeed) == false)
    { return FMars_Validation(f"InterpSpeed [{Self.InterpSpeed}] is not finite"); }

    if (Self.MaxYawDeg <= 0.0f)
    { return FMars_Validation(f"MaxYawDeg [{Self.MaxYawDeg}] must be > 0"); }

    if (Self.MaxPitchDeg <= 0.0f)
    { return FMars_Validation(f"MaxPitchDeg [{Self.MaxPitchDeg}] must be > 0"); }

    if (Self.InterpSpeed <= 0.0f)
    { return FMars_Validation(f"InterpSpeed [{Self.InterpSpeed}] must be > 0"); }

    return FMars_Validation();
}

struct FMars_Eyes_Spec
{
    UPROPERTY()
    FMars_Eyes_StyleDef Style;

    // Unset = the eyes never blink.
    UPROPERTY()
    TOptional<FMars_Eyes_BlinkSpec> Blink;

    // Unset = the eyes always look straight ahead.
    UPROPERTY()
    TOptional<FMars_Eyes_LookSpec> Look;

    // The component the look is drawn on; an invalid handle draws nothing until Request_SetPlate names one.
    UPROPERTY()
    FCk_Handle_UnrealComponent Plate;
}

// All-or-nothing: reports the first failing rule, prefixed with its group.
mixin FMars_Validation Validate(const FMars_Eyes_Spec& Self)
{
    const auto StyleValidation = Self.Style.Validate();
    if (StyleValidation.IsValid() == false)
    { return FMars_Validation(f"Style: {StyleValidation.Get_Error()}"); }

    if (Self.Blink.IsSet())
    {
        const auto BlinkValidation = Self.Blink.GetValue().Validate();
        if (BlinkValidation.IsValid() == false)
        { return FMars_Validation(f"Blink: {BlinkValidation.Get_Error()}"); }
    }

    if (Self.Look.IsSet())
    {
        const auto LookValidation = Self.Look.GetValue().Validate();
        if (LookValidation.IsValid() == false)
        { return FMars_Validation(f"Look: {LookValidation.Get_Error()}"); }
    }

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

// The groups of the plate's custom primitive data, each pushed as one request.
enum EMars_Eyes_PlateGroup
{
    Cells,
    Anim,
    Look,
    Color
}

enum EMars_Eyes_BlinkStage
{
    // Open, counting down to the next blink.
    Waiting,
    // Open, counting down the short gap before the second blink of a double blink.
    WaitingForSecond,
    Blinking,
    // The second blink of a double blink; it never chains into a third.
    BlinkingSecond,
    // Held open: an active expression forbids blinking. The next blink was drawn afresh when this began.
    Suppressed
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec's Style is not kept here: it seeds FMars_Fragment_Eyes.Style, its one home. Neither is its Plate, which the
// presentation holds.
struct FMars_Fragment_Eyes_Params
{
    UPROPERTY()
    TOptional<FMars_Eyes_BlinkSpec> Blink;

    UPROPERTY()
    TOptional<FMars_Eyes_LookSpec> Look;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Eyes_PlayingEmote
{
    UPROPERTY()
    FMars_Eyes_ExpressionDef Expression;

    // Unset while the emote plays until cleared.
    UPROPERTY()
    TOptional<float32> RemainingSeconds;
}

// Logic: every machine. Written only by UMars_Processor_Eyes_Requests and (emote expiry) UMars_Processor_Eyes_Resolve.
struct FMars_Fragment_Eyes
{
    UPROPERTY()
    FMars_Eyes_StyleDef Style;

    // Unset while no state expression is set.
    UPROPERTY()
    TOptional<FMars_Eyes_ExpressionDef> StateExpression;

    // Unset while no emote plays.
    UPROPERTY()
    TOptional<FMars_Eyes_PlayingEmote> Emote;
}

// The resolved cells and the crossfade from the cells shown before them.
struct FMars_Eyes_CellFade
{
    UPROPERTY()
    int32 LeftCell = 0;

    UPROPERTY()
    int32 RightCell = 0;

    UPROPERTY()
    int32 PrevLeftCell = 0;

    UPROPERTY()
    int32 PrevRightCell = 0;

    // 0 right after the cells changed, 1 once the crossfade from the previous cells is done.
    UPROPERTY()
    float32 Blend = 1.0f;

    UPROPERTY()
    float32 BlendSeconds = 0.08f;
}

struct FMars_Eyes_BlinkState
{
    UPROPERTY()
    EMars_Eyes_BlinkStage Stage = EMars_Eyes_BlinkStage::Waiting;

    // Seconds into the blink in progress; advances only while blinking.
    UPROPERTY()
    float32 PhaseSeconds = 0.0f;

    UPROPERTY()
    float32 SecondsToNextBlink = 0.0f;

    // 0 open .. 1 closed.
    UPROPERTY()
    float32 Closure = 0.0f;

    // Completed blinks since Add.
    UPROPERTY()
    int32 Count = 0;
}

// What the look is drawn on: a CkUnrealComponent plate (Component), or a primitive one of whose material slots uses the
// eye-plate look (Primitive; held weakly, so once its actor destroys it the pointer reads null and nothing is pushed). A
// set primitive wins; Request_SetPlate and Request_SetPlatePrimitive replace one with the other.
struct FMars_Eyes_Plate
{
    UPROPERTY()
    FCk_Handle_UnrealComponent Component;

    UPROPERTY()
    TWeakObjectPtr<UPrimitiveComponent> Primitive;

    // Unset until the first push to the current plate, which therefore sends every group.
    UPROPERTY()
    TOptional<FMars_Eyes_MaterialValues> LastPushed;
}

// Presentation: only where cosmetics can run (utils_net::Get_CanExecuteCosmeticEvents at Add).
struct FMars_Fragment_Eyes_Presentation
{
    UPROPERTY()
    FMars_Eyes_CellFade Cells;

    // Whether every active expression layer allows blinking / looking.
    UPROPERTY()
    bool AllowBlink = true;

    UPROPERTY()
    bool AllowLook = true;

    UPROPERTY()
    FMars_Eyes_BlinkState Blink;

    // Each axis -1..1.
    UPROPERTY()
    FVector2D LookOffset;

    UPROPERTY()
    FMars_Eyes_Plate Plate;
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

// Plays on the Emote layer; an unset DurationSeconds keeps it until cleared.
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

// Every group is pushed to the new plate on the next apply pass. Ignored where there is no presentation.
struct FMars_Request_Eyes_SetPlate
{
    UPROPERTY()
    FCk_Handle_UnrealComponent Plate;

    FMars_Request_Eyes_SetPlate() {}

    FMars_Request_Eyes_SetPlate(const FCk_Handle_UnrealComponent& InPlate)
    {
        Plate = InPlate;
    }
}

// Draws the look on Primitive's material slot MaterialSlot (which must use the eye-plate look; the caller assigns it):
// the values go straight into the primitive's custom primitive data, which every slot on it sees and only the eye-plate
// slot reads. Replaces a CkUnrealComponent plate. A slot the primitive lacks is rejected after an ensure; a primitive
// gone by the drain is no plate.
struct FMars_Request_Eyes_SetPlatePrimitive
{
    UPROPERTY()
    TWeakObjectPtr<UPrimitiveComponent> Primitive;

    UPROPERTY()
    int32 MaterialSlot = 0;

    FMars_Request_Eyes_SetPlatePrimitive() {}

    FMars_Request_Eyes_SetPlatePrimitive(UPrimitiveComponent InPrimitive, int32 InMaterialSlot)
    {
        Primitive = InPrimitive;
        MaterialSlot = InMaterialSlot;
    }
}

// Drain order SetPlate -> SetPlatePrimitive -> SetStyle -> ClearExpression -> SetStateExpression -> PlayExpression (see
// UMars_Processor_Eyes_Requests).
struct FMars_Fragment_Eyes_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Eyes_SetPlate> SetPlateRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_SetPlatePrimitive> SetPlatePrimitiveRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_SetStyle> SetStyleRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_ClearExpression> ClearExpressionRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_SetStateExpression> SetStateExpressionRequests;

    UPROPERTY()
    TArray<FMars_Request_Eyes_PlayExpression> PlayExpressionRequests;
}
