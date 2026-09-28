// Event-driven: binds the attribute's OnValueChanged and evaluates the current value on enter.
// Derive and set AttributeTag + Comparison as defaults; _NegateResult (base) inverts.
//
// Negating an event-driven condition only takes effect after an evaluation; this one always
// evaluates on enter, so a negated variant is correct from its resting state.
class UMars_SmCondition_ByteAttribute : UCk_SmCondition_EventDriven
{
    protected FGameplayTag AttributeTag;
    protected FCk_Comparison_Int Comparison;
    protected ECk_MinMaxCurrent AttributeComponent = ECk_MinMaxCurrent::Current;

    private FCk_Handle_ByteAttribute CachedAttribute;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto ContextEntity = ck::Ctx(InHandle);
        if (ck::EnsureIfNot(ck::IsValid(ContextEntity), "Context entity is invalid"))
        { return; }

        CachedAttribute = utils_byte_attribute::TryGet(ContextEntity, AttributeTag);
        if (ck::EnsureIfNot(ck::IsValid(CachedAttribute),
            f"ByteAttribute [{AttributeTag.ToString()}] not found on context entity"))
        { return; }

        utils_byte_attribute::BindTo_OnValueChanged(CachedAttribute, AttributeComponent,
            FCk_Delegate_ByteAttribute_OnValueChanged(this, n"OnAttributeChanged"));

        EvaluateAndMark(int32(CachedAttribute.Get_FinalValue(AttributeComponent)));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(CachedAttribute))
        {
            utils_byte_attribute::UnbindFrom_OnValueChanged(CachedAttribute, AttributeComponent,
                FCk_Delegate_ByteAttribute_OnValueChanged(this, n"OnAttributeChanged"));
        }
        CachedAttribute = FCk_Handle_ByteAttribute();
    }

    UFUNCTION()
    private void OnAttributeChanged(FCk_Handle InAttributeOwnerEntity, FCk_Payload_ByteAttribute_OnValueChanged InPayload)
    {
        EvaluateAndMark(int32(InPayload.Get_FinalValue()));
    }

    private void EvaluateAndMark(int32 InValue)
    {
        if (UCk_Utils_IntComparison_UE::Get_IsComparisonTrue(InValue, Comparison))
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }
}
