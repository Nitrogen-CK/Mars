// Devoured: a devourer holds the player (the Devour feature marked it, utils_devour::TryGet_Devourer). The player keeps
// nothing: Alive's subtree is torn down, movement is taken as it is when Downed, and the view is given to the devourer's
// View node and held still. The state ends when the devourer lets go; a player downed meanwhile goes on to Downed from
// Alive.

class UMars_SmCondition_IsDevoured : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        return ck::IsValid(utils_devour::TryGet_Devourer(ck::Ctx(InHandle)));
    }
}

class UMars_SmCondition_IsNotDevoured : UMars_SmCondition_IsDevoured
{
    default _NegateResult = true;
}

class UMars_SmState_Devoured : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAlive = AddTransition(InHandle, UMars_SmState_Alive);
        AddCondition(ToAlive, UMars_SmCondition_IsNotDevoured);

        AddTask(InHandle, UMars_SmTask_Downed_Lockdown);
        AddTask(InHandle, UMars_SmTask_Devoured_View);
    }
}

// Gives the view to the devourer for as long as Devoured lasts, on the owning copy: the HUD's layout is taken off the
// screen, the look input is held (the player viewpoint's Devour hold) and, when the devourer has a View node,
// UMars_CameraLayer_Devour blends the view onto it over k_ViewBlendSeconds. The node starts at the player's own view
// (the devourer's assembly puts it there before moving it), so the blend is not seen. Exit removes the layer at once,
// releases the hold and puts the layout back: the devourer's assembly covers the cut back. No PlayerViewpoint
// (headless) = nothing to do.
class UMars_SmTask_Devoured_View : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const float32 k_ViewBlendSeconds = 0.15f;

    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FCk_Handle_Camera _Camera;
    private AMars_Master_HUD _Hud;
    private bool _HoldsView = false;
    private bool _HasLayer = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _HoldsView = false;
        _HasLayer = false;
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Player = ck::Ctx(InHandle);
        _Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Viewpoint))
        { return; }

        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::Devour));
        _HoldsView = true;

        auto Pawn = Cast<APawn>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Player));
        auto Controller = ck::IsValid(Pawn) ? Cast<APlayerController>(Pawn.GetController()) : nullptr;
        _Hud = ck::IsValid(Controller) ? Cast<AMars_Master_HUD>(Controller.GetHUD()) : nullptr;
        if (ck::IsValid(_Hud))
        { _Hud.Set_LayoutHidden(true); }

        _Camera = _Viewpoint.Get_Camera();
        if (ck::EnsureIfNot(ck::IsValid(_Camera), "[Devoured] the player's viewpoint has no camera"))
        { return; }

        // Released between the condition and this enter: nothing to look through.
        const auto Devourer = utils_devour::TryGet_Devourer(Player);
        if (ck::Is_NOT_Valid(Devourer))
        { return; }

        const auto View = Devourer.Get_View();
        if (ck::Is_NOT_Valid(View))
        { return; }

        auto Request = FCk_Request_Camera_AddLayer(UMars_CameraLayer_Devour);
        Request.Set_StackingBehavior(ECk_Camera_StackingBehavior::OneOnly);
        Request.Set_BlendInTime(FCk_Time(k_ViewBlendSeconds));
        Request.Set_CameraTarget(FCk_Camera_Target(View, ECk_Camera_TargetMode::ViewTarget));
        _Camera.Request_AddLayer(Request);
        _HasLayer = true;
    }

    // Removing a layer creates entities; when the exit is the world being torn down (PIE stopped mid-scene) the ECS world
    // refuses them, so the removal is skipped: there is no camera left to free.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (_HasLayer && ck::IsValid(_Camera) && _Camera.Get_CanCreateEntity())
        {
            auto Request = FCk_Request_Camera_RemoveLayer(UMars_CameraLayer_Devour);
            Request.Set_BlendOutTime(FCk_Time(0.0f));
            _Camera.Request_RemoveLayer(Request);
        }

        if (_HoldsView && ck::IsValid(_Viewpoint))
        { _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::Devour)); }

        if (ck::IsValid(_Hud))
        { _Hud.Set_LayoutHidden(false); }

        _HoldsView = false;
        _HasLayer = false;
        _Hud = nullptr;
        _Camera = FCk_Handle_Camera();
        _Viewpoint = FCk_Handle_PlayerViewpoint();
    }
}

// The devourer's view layer: its camera target (the devourer's View node, ViewTarget) carries the framing.
class UMars_CameraLayer_Devour : UCk_CameraLayer_EntityScript
{
}
