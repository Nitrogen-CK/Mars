// What the Screaming Turnip's anim blueprint reads (/Game/ArtCandidates/ScreamingTurnip/R01/Animation/
// ScreamingTurnip_R01_Mars_ABP, parented to this class; built by Tools/LevelDesign/screaming_turnip_r01_review/
// screaming_turnip_animbp_ue.py). Its AnimGraph: Sequence Evaluator (Sequence <- Sequence, Explicit Time <- ClipTime, no
// loop) -> Local To Component -> Transform (Modify) Bone on `crown` (translation Add in component space <- CrownOffset)
// -> Component To Local -> Output Pose. Written only by UMars_ScreamingTurnipPresentationComponent, every tick: the
// component is the clip clock (it wraps, clamps, spans and scrubs); the graph decides nothing.
class UMars_ScreamingTurnip_AnimInstance : UAnimInstance
{
    // The clip on screen; null holds the bind pose.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "ScreamingTurnip")
    UAnimSequenceBase Sequence;

    // Seconds into Sequence, already wrapped or clamped by the component.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "ScreamingTurnip")
    float32 ClipTime = 0.0f;

    // The stretch's runtime crown offset, component space, cm: (-Alpha * TravelCm, 0, Alpha * LiftCm), toward the mesh's -X.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "ScreamingTurnip")
    FVector CrownOffset = FVector::ZeroVector;

    // The presentation's one write per tick. No BlueprintUpdateAnimation: the instance computes nothing.
    void Set_Pose(UAnimSequenceBase InSequence, float32 InClipTime, FVector InCrownOffset)
    {
        Sequence = InSequence;
        ClipTime = InClipTime;
        CrownOffset = InCrownOffset;
    }
}
