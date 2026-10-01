// The focus outline drawn on whatever the player is looking at. Mapped to Outline.Gameplay.Interaction in
// Config/DefaultCkFoundation.ini; otherwise CkFoundation's DA_Outline_Interactable, with a thinner ring.
namespace mars
{
    asset Outline_Interactable_Mars_DA of UCkUsf_OutlinePreset
    {
        _OutlineType       = ECk_Usf_OutlineType::Normal;
        _OutlineColor      = FLinearColor(0.10, 0.60, 1.00, 1.0);
        _OutlineBrightness = 1.5;
        _ThicknessScale    = 0.3;
    }
}
