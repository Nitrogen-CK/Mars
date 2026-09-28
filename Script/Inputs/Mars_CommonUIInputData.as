// CommonUI reads this class's CDO, so the defaults ARE the data - no companion asset.
// Register in Config/DefaultGame.ini once menus exist:
//   [/Script/CommonInput.CommonInputSettings]
//   bEnableEnhancedInputSupport=True
//   InputData=/Script/Angelscript.Mars_CommonUIInputData
class UMars_CommonUIInputData : UCommonUIInputData
{
    default EnhancedInputBackAction = mars::Mars_IA_UI_Back;
    default EnhancedInputClickAction = mars::Mars_IA_UI_Confirm;
}
