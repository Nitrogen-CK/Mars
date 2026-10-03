// CommonUI reads this class's CDO, so the defaults ARE the data - no companion asset. Registered as
// [/Script/CommonInput.CommonInputSettings] InputData in Config/DefaultGame.ini; renaming the class breaks that line.
class UMars_CommonUIInputData : UCommonUIInputData
{
    default EnhancedInputBackAction = mars::Mars_IA_UI_Back;
    default EnhancedInputClickAction = mars::Mars_IA_UI_Confirm;
}
