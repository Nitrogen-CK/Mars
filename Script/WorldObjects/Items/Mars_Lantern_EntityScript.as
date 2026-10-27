// The lantern's assembly: a flame item (UMars_FlameItem_EntityScript) whose glass glows with its flame (the mesh's Glow
// slot) and whose body stays visible on the belt, where a lit lantern keeps burning at a smaller, dimmer pool.
class UMars_Lantern_EntityScript : UMars_FlameItem_EntityScript
{
    // CampLantern_Mars_SM's glass slot (Glow_Mars_MI: Emissive "Color" x "Strength").
    private const int32 k_GlassSlot = 1;
    private const FName k_GlassStrengthParameter = n"Strength";
    private const float32 k_GlassStrength = 8.0f;

    // The flame's height over the lantern's pivot (its base), at the item's MeshScale.
    private const float64 k_FlameHeight = 14.0;

    private UMaterialInstanceDynamic _Glass;

    protected float64 Get_FlameHeight() const override
    {
        return k_FlameHeight;
    }

    // Mars_TestLamp's colour and intensity in hand and in the world, which the sandbox has been lit by; dimmer and
    // unshadowed on the belt.
    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.67f, 0.35f, 1.0f);
        Look.IntensityHeld = 8000.0f;
        Look.IntensityStowed = 3000.0f;
        Look.IntensityWorld = 8000.0f;
        Look.ShadowsStowed = false;
        return Look;
    }

    protected bool Get_HidesWhileStowed() const override
    {
        return false;
    }

    protected void DoOnFlameComposed() override
    {
        _Dressing.BindTo_OnBrightness(FMars_Delegate_FlameDressing_OnBrightness(this, n"OnFlameBrightness"));
    }

    // The glass glows only while the lantern is lit.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        Super::DoOnVisualMeshAdded(InMesh);
        if (InMesh.GetNumMaterials() > k_GlassSlot)
        { _Glass = InMesh.CreateDynamicMaterialInstance(k_GlassSlot); }

        if (ck::IsValid(_Dressing))
        { _Dressing.Refresh(); }
    }

    UFUNCTION()
    private void OnFlameBrightness(float32 InBrightness)
    {
        if (ck::IsValid(_Glass))
        { _Glass.SetScalarParameterValue(k_GlassStrengthParameter, k_GlassStrength * InBrightness); }
    }
}
