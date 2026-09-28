namespace utils_mars_debugger
{
    // The one place the debugger's font scale is tuned. A size of 0 keeps the widget default.
    const float32 k_FontScale = 0.7f;

    void Text(const FString& InText, float32 InSize = 0, const FLinearColor& InColor = FLinearColor::White, bool InWrap = false, bool InBold = false)
    {
        mm::Text(InText, InSize * k_FontScale, InColor, InWrap, InBold);
    }
}
