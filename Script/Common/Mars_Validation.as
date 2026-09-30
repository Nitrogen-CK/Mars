// The answer a Spec's Validate() mixin gives: valid, or the first failing rule in words. Composers call Validate() once
// and ensure on it; tests may call it directly to assert a rejection without tripping the ensure.
struct FMars_Validation
{
    UPROPERTY()
    bool IsValid = true;

    // Set only when invalid.
    UPROPERTY()
    TOptional<FString> Error;

    FMars_Validation() {}

    FMars_Validation(const FString& InError)
    {
        IsValid = false;
        Error = TOptional<FString>(InError);
    }

    // Empty when valid.
    FString Get_Error() const
    {
        return Error.IsSet() ? Error.GetValue() : "";
    }
}
