// Optional game cues consume copied accepted native intervals. No cue advances gameplay or owns a phase clock.
struct FMars_Attack_CueObservation
{
    UPROPERTY() FCk_ProceduralAction_Stamp Stamp;
    UPROPERTY() FCk_ProceduralAction_Interval Interval;
    UPROPERTY() int64 ObservationFrame = 0;
}

struct FMars_Attack_CueBatch
{
    UPROPERTY() FGameplayTag Profile;
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FCk_ProceduralAction_Identity ActionIdentity;
    UPROPERTY() int32 AdmissionAttemptGeneration = 0;
    UPROPERTY() FMars_Attack_MotionContract Motion;
    UPROPERTY() bool Admitted = false;
    UPROPERTY() bool Interrupted = false;
    UPROPERTY() bool Completed = false;
    UPROPERTY() FMars_Attack_Result Result;
    UPROPERTY() TArray<FMars_Attack_CueObservation> Observations;
}

delegate void FMars_Delegate_Crawler_OnAttackCue(FCk_Handle_Crawler InCrawler, FMars_Attack_CueBatch InBatch);
event void FMars_Delegate_Crawler_OnAttackCue_MC(FCk_Handle_Crawler InCrawler, FMars_Attack_CueBatch InBatch);

// Tick's pre-write snapshot; this contains no callback or live object references.
struct FMars_Crawler_CueDispatchBefore
{
    FMars_Attack_Admission Admission;
    FMars_Attack_Result Result;
    bool Interrupted = false;
}

namespace utils_crawler
{
    // Called once after the entire game tick, including zero-time cancellation, has committed its public state.
    void Dispatch_AttackCues(FCk_Handle_Crawler& InSelf, const FMars_Crawler_CueDispatchBefore& InBefore,
        const TArray<FMars_Attack_CueObservation>& InObservations)
    {
        const auto Admission = InSelf.Get_AttackAdmission();
        if (Admission.Accepted == false || InSelf.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
        { return; }

        const auto Plan = InSelf.Get_AttackPlan();
        if (Plan.Entry.Definition.CueProfile.IsValid() == false)
        { return; }

        const auto Result = InSelf.Get_AttackResult();
        const auto Interrupted = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack).CueInterrupted;
        const auto NewIdentity = Admission.ActionIdentity.Get_Value() != InBefore.Admission.ActionIdentity.Get_Value();
        auto Batch = FMars_Attack_CueBatch();
        Batch.Profile = Plan.Entry.Definition.CueProfile;
        Batch.AttackId = Admission.AttackId;
        Batch.ActionIdentity = Admission.ActionIdentity;
        Batch.AdmissionAttemptGeneration = Admission.AttemptGeneration;
        Batch.Motion = Plan.Entry.Definition.Motion;
        Batch.Admitted = InBefore.Admission.Accepted == false || NewIdentity;
        Batch.Interrupted = Interrupted && (InBefore.Interrupted == false || NewIdentity);
        Batch.Completed = Result.Accepted && Result.Completed && (InBefore.Result.Completed == false ||
            Result.ActionIdentity.Get_Value() != InBefore.Result.ActionIdentity.Get_Value());
        Batch.Result = Result;
        Batch.Observations = InObservations;
        if (Batch.Admitted || Batch.Interrupted || Batch.Completed || Batch.Observations.IsEmpty() == false)
        { InSelf.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCue.Broadcast(InSelf, Batch); }
    }
}

mixin void BindTo_OnAttackCue(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackCue InDelegate)
{ Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCue.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }

mixin void UnbindFrom_OnAttackCue(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackCue InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals))
    { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCue.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
