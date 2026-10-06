namespace mars
{
    asset Mars_IA_Pause of UCk_Boolean_InputAction
    {
    }
}

// An empty replacement context suspends gameplay mappings and releases the pawn's intent matcher while the pause
// menu is up. The Menu layer's UIOnly mode already blocks new input; this releases what is already held.
class UMars_InputProfile_Pause : UMars_InputProfile
{
    UFUNCTION(BlueprintOverride)
    void Setup(UEnhancedInputComponent InInputComponent)
    {
        Super::Setup(InInputComponent);
        Context = NewObject(this, UInputMappingContext);
    }
}
