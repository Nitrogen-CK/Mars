// Cosmetic eye presets: styles (the resting cell per eye, color and glow) and expressions (cells that override the
// style for a while). The catalog's Styles and Expressions arrays are APPEND-ONLY: an entry's index is its future
// network id, so reordering or removing an entry changes what every sent or saved index means. Cells index the 8 x 4
// eye atlas (row * 8 + col).

class UMars_EyeStyle : UDataAsset
{
    UPROPERTY()
    FMars_Eyes_StyleDef Def;
}

class UMars_EyeExpression : UDataAsset
{
    UPROPERTY()
    FMars_Eyes_ExpressionDef Def;
}

class UMars_EyeCatalog : UDataAsset
{
    // Append-only; the index is the future network id.
    UPROPERTY()
    TArray<UMars_EyeStyle> Styles;

    // Append-only; the index is the future network id.
    UPROPERTY()
    TArray<UMars_EyeExpression> Expressions;
}

//--------------------------------------------------------------------------------------------------------------------------
// Styles
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EyeStyle_ClassicOval of UMars_EyeStyle
{
    Def.LeftCell = 1;
    Def.RightCell = 1;
}

asset Mars_EyeStyle_RoundDots of UMars_EyeStyle
{
    Def.LeftCell = 2;
    Def.RightCell = 2;
}

asset Mars_EyeStyle_SquarePixels of UMars_EyeStyle
{
    Def.LeftCell = 3;
    Def.RightCell = 3;
}

asset Mars_EyeStyle_SoftStars of UMars_EyeStyle
{
    Def.LeftCell = 4;
    Def.RightCell = 4;
}

asset Mars_EyeStyle_TinySlits of UMars_EyeStyle
{
    Def.LeftCell = 5;
    Def.RightCell = 5;
}

asset Mars_EyeStyle_HeavyLid of UMars_EyeStyle
{
    Def.LeftCell = 6;
    Def.RightCell = 6;
}

asset Mars_EyeStyle_DoubleLine of UMars_EyeStyle
{
    Def.LeftCell = 7;
    Def.RightCell = 7;
}

asset Mars_EyeStyle_Heart of UMars_EyeStyle
{
    Def.LeftCell = 8;
    Def.RightCell = 8;
}

asset Mars_EyeStyle_Spiral of UMars_EyeStyle
{
    Def.LeftCell = 9;
    Def.RightCell = 9;
}

asset Mars_EyeStyle_Candle of UMars_EyeStyle
{
    Def.LeftCell = 10;
    Def.RightCell = 10;
}

asset Mars_EyeStyle_Cracked of UMars_EyeStyle
{
    Def.LeftCell = 11;
    Def.RightCell = 11;
}

// The chef's resting eyes (2026-10-03): atlas cell 19 is a full circle, which the body's 8.5 x 6 cm eye quads draw as
// a wide 1.42:1 oval, like the concept art's big eyes.
asset Mars_EyeStyle_Wide of UMars_EyeStyle
{
    Def.LeftCell = 19;
    Def.RightCell = 19;
}

//--------------------------------------------------------------------------------------------------------------------------
// Expressions
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EyeExpression_Happy of UMars_EyeExpression
{
    Def.LeftCell = 13;
    Def.RightCell = 13;
    Def.AllowBlink = false;
    Def.AllowLook = true;
    Def.DurationSeconds = 2.0f;
}

// The left eye keeps the style's cell.
asset Mars_EyeExpression_Wink of UMars_EyeExpression
{
    Def.RightCell = 13;
    Def.AllowBlink = false;
    Def.AllowLook = true;
    Def.DurationSeconds = 1.2f;
}

asset Mars_EyeExpression_Squeeze of UMars_EyeExpression
{
    Def.LeftCell = 15;
    Def.RightCell = 15;
    Def.AllowBlink = false;
    Def.AllowLook = false;
    Def.DurationSeconds = 1.5f;
}

asset Mars_EyeExpression_Angry of UMars_EyeExpression
{
    Def.LeftCell = 16;
    Def.RightCell = 16;
    Def.AllowBlink = true;
    Def.AllowLook = true;
    Def.DurationSeconds = 2.0f;
}

asset Mars_EyeExpression_Sad of UMars_EyeExpression
{
    Def.LeftCell = 14;
    Def.RightCell = 14;
    Def.AllowBlink = true;
    Def.AllowLook = true;
    Def.DurationSeconds = 2.5f;
}

asset Mars_EyeExpression_Dizzy of UMars_EyeExpression
{
    Def.LeftCell = 9;
    Def.RightCell = 9;
    Def.AllowBlink = false;
    Def.AllowLook = false;
    Def.DurationSeconds = 3.0f;
}

asset Mars_EyeExpression_Sparkle of UMars_EyeExpression
{
    Def.LeftCell = 18;
    Def.RightCell = 18;
    Def.AllowBlink = false;
    Def.AllowLook = true;
    Def.DurationSeconds = 2.0f;
}

asset Mars_EyeExpression_HalfLid of UMars_EyeExpression
{
    Def.LeftCell = 17;
    Def.RightCell = 17;
    Def.AllowBlink = false;
    Def.AllowLook = true;
    Def.DurationSeconds = 2.5f;
}

// A state expression: stays until cleared.
asset Mars_EyeExpression_Downed of UMars_EyeExpression
{
    Def.LeftCell = 20;
    Def.RightCell = 20;
    Def.AllowBlink = false;
    Def.AllowLook = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Catalog
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EyeCatalog of UMars_EyeCatalog
{
    Styles.Add(Mars_EyeStyle_ClassicOval);
    Styles.Add(Mars_EyeStyle_RoundDots);
    Styles.Add(Mars_EyeStyle_SquarePixels);
    Styles.Add(Mars_EyeStyle_SoftStars);
    Styles.Add(Mars_EyeStyle_TinySlits);
    Styles.Add(Mars_EyeStyle_HeavyLid);
    Styles.Add(Mars_EyeStyle_DoubleLine);
    Styles.Add(Mars_EyeStyle_Heart);
    Styles.Add(Mars_EyeStyle_Spiral);
    Styles.Add(Mars_EyeStyle_Candle);
    Styles.Add(Mars_EyeStyle_Cracked);
    Styles.Add(Mars_EyeStyle_Wide);

    Expressions.Add(Mars_EyeExpression_Happy);
    Expressions.Add(Mars_EyeExpression_Wink);
    Expressions.Add(Mars_EyeExpression_Squeeze);
    Expressions.Add(Mars_EyeExpression_Angry);
    Expressions.Add(Mars_EyeExpression_Sad);
    Expressions.Add(Mars_EyeExpression_Dizzy);
    Expressions.Add(Mars_EyeExpression_Sparkle);
    Expressions.Add(Mars_EyeExpression_HalfLid);
    Expressions.Add(Mars_EyeExpression_Downed);
}

// Script asset globals are file-local: other files reach them through these accessors.
namespace utils_eyes
{
    UMars_EyeCatalog Catalog() { return Mars_EyeCatalog; }
    UMars_EyeExpression Expression_Happy() { return Mars_EyeExpression_Happy; }
    UMars_EyeExpression Expression_Wink() { return Mars_EyeExpression_Wink; }
    UMars_EyeExpression Expression_Downed() { return Mars_EyeExpression_Downed; }

    // The chef's resting style (AMars_PlayerCharacter's config); assets resolve across files through a namespace.
    UMars_EyeStyle Style_Wide() { return Mars_EyeStyle_Wide; }
}
