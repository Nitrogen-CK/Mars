enum EMars_Debugger_TextWeight
{
    Regular,
    Bold
}

struct FMars_Debugger_TextStyle
{
    // Unset keeps the widget's default font size.
    TOptional<float32> Size;
    FLinearColor Color = FLinearColor::White;
    EMars_Debugger_TextWeight Weight = EMars_Debugger_TextWeight::Regular;

    FMars_Debugger_TextStyle() {}

    FMars_Debugger_TextStyle(float32 InSize, FLinearColor InColor = FLinearColor::White,
                             EMars_Debugger_TextWeight InWeight = EMars_Debugger_TextWeight::Regular)
    {
        Size = InSize;
        Color = InColor;
        Weight = InWeight;
    }
}

namespace utils_mars_debugger
{
    // The one place the debugger's font scale is tuned.
    const float32 k_FontScale = 0.7f;

    void Text(const FString& InText, const FMars_Debugger_TextStyle& InStyle)
    {
        // mm::Text reads a size of 0 as the widget default.
        const float32 Size = InStyle.Size.IsSet() ? InStyle.Size.GetValue() * k_FontScale : 0.0f;
        const bool Wrap = false;
        const bool Bold = InStyle.Weight == EMars_Debugger_TextWeight::Bold;
        mm::Text(InText, Size, InStyle.Color, Wrap, Bold);
    }
}
