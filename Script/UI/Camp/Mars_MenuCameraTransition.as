// Own the interpolation, rather than predicting completion of an opaque native camera blend.
// The existing viewer pawn supplies the moving camera; placed station cameras remain endpoints.
class UMars_MenuCameraTransition : UObject
{
    private APlayerController _Controller;
    private AMars_Camp_ViewerPawn _Viewer;
    private AMars_CampStationCamera _Target;
    private FVector _StartLocation;
    private FQuat _StartRotation;
    private float _Elapsed = 0.0;
    private float _Duration = 0.0;
    private bool _ReducedMotion = false;
    private bool _Moving = false;

    bool IsMoving() const
    { return _Moving; }

    bool Start(APlayerController InController, AMars_CampStationCamera InTarget,
        float InDuration, bool InReducedMotion)
    {
        auto Viewer = Cast<AMars_Camp_ViewerPawn>(InController.GetControlledPawn());
        if (ck::Is_NOT_Valid(Viewer) || ck::Is_NOT_Valid(InTarget) || InTarget.GetWorld() != Viewer.GetWorld())
        { return false; }
        _Controller = InController;
        _Viewer = Viewer;
        _Target = InTarget;
        _StartLocation = InController.PlayerCameraManager.GetCameraLocation();
        _StartRotation = InController.PlayerCameraManager.GetCameraRotation().Quaternion();
        _Elapsed = 0.0;
        _Duration = InReducedMotion ? 0.12 : InDuration;
        _ReducedMotion = InReducedMotion;
        _Moving = _Duration > 0.0;
        _Controller.PlayerCameraManager.StopCameraFade();
        if (!_Moving)
        {
            _Controller.SetViewTargetWithBlend(InTarget, 0.0f);
            return true;
        }
        _Viewer.SetActorLocationAndRotation(_StartLocation, _StartRotation.Rotator());
        _Controller.SetViewTargetWithBlend(_Viewer, 0.0f);
        return true;
    }

    void Tick(float InDeltaSeconds)
    {
        if (!_Moving)
        { return; }
        if (ck::Is_NOT_Valid(_Controller) || ck::Is_NOT_Valid(_Viewer) || ck::Is_NOT_Valid(_Target) ||
            _Controller.GetControlledPawn() != _Viewer)
        { Cancel(); return; }
        _Elapsed = Math::Min(_Duration, _Elapsed + Math::Max(0.0, InDeltaSeconds));
        const float Alpha = _Elapsed / _Duration;
        const auto EndLocation = _Target.CameraComponent.GetWorldLocation();
        const auto EndRotation = _Target.CameraComponent.GetWorldRotation();
        if (_ReducedMotion)
        {
            // Fade alpha and the cut are owned by this animation, not an unrelated readiness timer.
            const float Opacity = Alpha < 0.5 ? Alpha * 2.0 : (1.0 - Alpha) * 2.0;
            _Controller.PlayerCameraManager.SetManualCameraFade(float32(Opacity), FLinearColor(0,0,0,1), false);
            if (Alpha >= 0.5)
            { _Viewer.SetActorLocationAndRotation(EndLocation, EndRotation); }
        }
        else
        {
            const float Ease = Alpha < 0.5 ? 2.0 * Alpha * Alpha : 1.0 - Math::Square(-2.0 * Alpha + 2.0) / 2.0;
            _Viewer.SetActorLocationAndRotation(Math::Lerp(_StartLocation, EndLocation, Ease),
                FQuat::Slerp(_StartRotation, EndRotation.Quaternion(), Ease).Rotator());
        }
        if (_Elapsed >= _Duration)
        {
            _Controller.SetViewTargetWithBlend(_Target, 0.0f);
            _Controller.PlayerCameraManager.StopCameraFade();
            _Moving = false;
        }
    }

    void Cancel()
    {
        if (ck::IsValid(_Controller) && ck::IsValid(_Controller.PlayerCameraManager))
        { _Controller.PlayerCameraManager.StopCameraFade(); }
        _Moving = false;
        _Controller = nullptr;
        _Viewer = nullptr;
        _Target = nullptr;
    }
}

