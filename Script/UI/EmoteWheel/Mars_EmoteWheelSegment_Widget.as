// One sector of the emote wheel: the entry's icon and name, both centred on the segment. The wheel places the segment
// on its sector's centre line, pushes the label out along that line (Set_LabelOffset) and pushes the hovered state in.
// The Icon image's brush must be the tint-decoding icon material (EmoteIcon_Mars_M): the icon texture is set on it per
// entry, and its red-encoded cloth takes PlayerTint.
UCLASS(Abstract)
class UMars_EmoteWheelSegment_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UImage Icon;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Label;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    float32 HoveredScale = 1.12f;

    // A disabled entry keeps its sector; its icon drops the player tint and fades to this.
    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Style")
    float32 DisabledOpacity = 0.48f;

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName IconTextureParameter = n"Icon";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName PlayerTintParameter = n"PlayerTint";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName TintAmountParameter = n"TintAmount";

    UPROPERTY(EditDefaultsOnly, Category = "EmoteWheel|Material")
    FName StateOpacityParameter = n"StateOpacity";

    private UMaterialInstanceDynamic _IconDMI;

    void Setup(const FMars_EmoteWheel_Entry& InEntry, FLinearColor InPlayerTint)
    {
        if (ck::IsValid(Label))
        {
            Label.SetText(InEntry.DisplayName);
            Label.SetRenderOpacity(InEntry.IsEnabled ? 1.0f : DisabledOpacity);
        }

        UTexture2D IconTexture = nullptr;
        if (InEntry.Icon.IsNull() == false)
        { IconTexture = System::LoadAsset_Blocking(InEntry.Icon); }

        _IconDMI = Icon.GetDynamicMaterial();
        if (ck::Is_NOT_Valid(_IconDMI))
        {
            // Without the icon material the red-encoded art shows as is - visible, but untinted.
            ck::Warning("[Mars_EmoteWheelSegment] the Icon brush is not a material; set it to EmoteIcon_Mars_M in the widget blueprint");
            if (ck::IsValid(IconTexture))
            { Icon.SetBrushFromTexture(IconTexture); }
            return;
        }

        if (ck::IsValid(IconTexture))
        { _IconDMI.SetTextureParameterValue(IconTextureParameter, IconTexture); }

        _IconDMI.SetVectorParameterValue(PlayerTintParameter, InPlayerTint);
        _IconDMI.SetScalarParameterValue(TintAmountParameter, InEntry.IsEnabled ? 1.0f : 0.0f);
        _IconDMI.SetScalarParameterValue(StateOpacityParameter, InEntry.IsEnabled ? 1.0f : DisabledOpacity);
    }

    // From the segment's centre; a render translation, so the label never changes the segment's size or placement.
    void Set_LabelOffset(FVector2D InOffset)
    {
        if (ck::IsValid(Label))
        { Label.SetRenderTranslation(InOffset); }
    }

    // Only the icon grows: the label stays put on its ring.
    void Set_Hovered(bool InIsHovered)
    {
        const auto Scale = InIsHovered ? HoveredScale : 1.0f;
        Icon.SetRenderScale(FVector2D(Scale, Scale));
    }
}
