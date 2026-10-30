// The torch's assembly: a flame item (UMars_FlameItem_EntityScript) with a dark pitch head on its shaft's top, its flame
// on the head, brighter and more orange than the lantern's. Stowed it hides, head and all: it is snuffed on the belt.
class UMars_Torch_EntityScript : UMars_FlameItem_EntityScript
{
    private const FVector k_HeadScale = FVector(0.06, 0.06, 0.08);
    private const FLinearColor k_HeadColor = FLinearColor(0.08f, 0.06f, 0.05f, 1.0f);

    private UStaticMeshComponent _Head;

    protected float64 Get_FlameHeight() const override
    {
        return constants_torch_item::k_HeadHeight;
    }

    protected FMars_FlameLook Get_Look() const override
    {
        auto Look = FMars_FlameLook();
        Look.Color = FLinearColor(1.0f, 0.55f, 0.25f, 1.0f);
        Look.IntensityHeld = 10000.0f;
        Look.IntensityStowed = 0.0f;
        Look.IntensityWorld = 9000.0f;
        Look.ShadowsHeld = true;
        Look.ShadowsWorld = true;
        Look.FxSize = 18.0f;
        Look.FxEmberRate = 6.0f;
        Look.FxEnclosed = false;
        return Look;
    }

    protected bool Get_HidesWhileStowed() const override
    {
        return true;
    }

    // The head's top is the shaft's top, where the flame sits.
    protected void DoOnFlameComposed() override
    {
        auto Root = _Flame.H().As_Transform();
        auto Part = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, constants_torch_item::k_HeadHeight - 4.0), k_HeadScale),
            engine::load::Cube(), assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"Torch_Head");
        Part.PrimaryColor = TOptional<FLinearColor>(k_HeadColor);
        Part.Tint = EMars_MeshPart_Tint::ProtoGrid;
        Part.CastShadow = false;

        auto Head = Root.Add_MeshPart(this, Part);
        if (ck::IsValid(Head))
        { utils_unreal_component::BindTo_OnAdded(Head, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnHeadAdded")); }

        auto WorldItem = _Flame.H().As_WorldItem();
        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_Head"));
    }

    // The base hides only the item's own body while stowed; the head follows it.
    private void Refresh_Head()
    {
        if (ck::IsValid(_Head) && ck::IsValid(_Flame))
        { _Head.SetVisibility(_Flame.Get_IsStowed() == false); }
    }

    UFUNCTION()
    private void OnHeadAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Head = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::IsValid(_Head) && ck::IsValid(_Flame))
        { _Head.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Flame.H())); }

        Refresh_Head();
    }

    UFUNCTION()
    private void OnMountChanged_Head(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        Refresh_Head();
    }
}
