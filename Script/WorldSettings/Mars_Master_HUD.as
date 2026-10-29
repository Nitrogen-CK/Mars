// Base HUD for every Mars mode. The HUD's context is the possessed chef's entity: it is injected into the layout once the
// chef has composed its gameplay features, and again on every later possession. Native actor linkage is too early.
UCLASS(Abstract)
class AMars_Master_HUD : ACk_HUD_UE
{
    protected UCk_UI_PrimaryGameLayout_UE ConstructedLayout;

    private TWeakObjectPtr<AMars_PlayerCharacter> _AwaitedChef;
    private TWeakObjectPtr<APlayerController> _PossessionController;

    // Set_LayoutHidden's last word, and the visibility the layout had before it was hidden.
    private bool _LayoutHidden = false;
    private ESlateVisibility _LayoutShownVisibility = ESlateVisibility::SelfHitTestInvisible;

    UFUNCTION(BlueprintOverride)
    void OnLayoutReady_Event(UCk_UI_PrimaryGameLayout_UE InLayout)
    {
        ConstructedLayout = InLayout;
        _LayoutShownVisibility = InLayout.GetVisibility();
        if (_LayoutHidden)
        { InLayout.SetVisibility(ESlateVisibility::Collapsed); }

        auto PC = GetOwningPlayerController();
        if (ck::EnsureIfNot(ck::IsValid(PC), "[Mars_Master_HUD] the layout is ready but the HUD has no owning PlayerController"))
        { return; }

        UnbindPossessionController();
        _PossessionController = TWeakObjectPtr<APlayerController>(PC);
        PC.OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");
        TryAwaitChefEntity(GetOwningPawn());
    }

    UFUNCTION(BlueprintOverride)
    void EndPlay(EEndPlayReason InReason)
    {
        UnbindAwaitedChef();
        UnbindPossessionController();
    }

    // Takes the whole layout off the screen, or puts it back as it was (a devoured player sees nothing of its own). Asked
    // before the layout exists, it is applied when the layout is ready.
    void Set_LayoutHidden(bool InHidden)
    {
        if (_LayoutHidden == InHidden)
        { return; }

        _LayoutHidden = InHidden;
        if (ck::Is_NOT_Valid(ConstructedLayout))
        { return; }

        if (InHidden)
        { _LayoutShownVisibility = ConstructedLayout.GetVisibility(); }

        ConstructedLayout.SetVisibility(InHidden ? ESlateVisibility::Collapsed : _LayoutShownVisibility);
    }

    // Runs before the layout receives InEntity; a mode adds its own widgets here.
    protected void OnChefEntityReady(FCk_Handle InEntity)
    {
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        TryAwaitChefEntity(NewPawn);
    }

    // Only a chef carries the HUD's context. Any other pawn (the camp viewer, or none while unpossessed) waits for the
    // next possession.
    private void TryAwaitChefEntity(APawn InPawn)
    {
        UnbindAwaitedChef();
        auto Chef = Cast<AMars_PlayerCharacter>(InPawn);
        if (ck::Is_NOT_Valid(Chef))
        { return; }

        _AwaitedChef = TWeakObjectPtr<AMars_PlayerCharacter>(Chef);
        Chef.OnGameplayComposed.AddUFunction(this, n"OnChefGameplayComposed");
        // Bind first: layout-before-composition and layout-after-composition converge on the same complete entity.
        const auto ComposedEntity = Chef.Get_GameplayComposedEntity();
        if (ck::IsValid(ComposedEntity))
        { OnChefGameplayComposed(ComposedEntity); }
    }

    UFUNCTION()
    private void OnChefGameplayComposed(FCk_Handle InEntity)
    {
        auto Chef = _AwaitedChef.Get();
        if (ck::Is_NOT_Valid(Chef) || GetOwningPawn() != Chef || Chef.Get_GameplayComposedEntity() != InEntity ||
            ck::Is_NOT_Valid(ConstructedLayout))
        { return; }

        auto Entity = InEntity;
        const auto PromptDisplay = Entity.As_InteractPromptDisplay(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(PromptDisplay), "[Mars_Master_HUD] gameplay-composed chef has no prompt display"))
        { return; }

        UnbindAwaitedChef();

        OnChefEntityReady(InEntity);
        utils_context_receiver::TryInjectContextIntoObject(ConstructedLayout, InEntity);
    }

    private void UnbindAwaitedChef()
    {
        auto Chef = _AwaitedChef.Get();
        if (ck::IsValid(Chef))
        { Chef.OnGameplayComposed.Unbind(this, n"OnChefGameplayComposed"); }
        _AwaitedChef = nullptr;
    }

    private void UnbindPossessionController()
    {
        auto PC = _PossessionController.Get();
        if (ck::IsValid(PC))
        { PC.OnPossessedPawnChanged.Unbind(this, n"HandlePossessedPawnChanged"); }
        _PossessionController = nullptr;
    }
}
