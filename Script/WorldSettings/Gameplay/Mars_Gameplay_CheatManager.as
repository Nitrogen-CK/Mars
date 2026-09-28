class UMars_Gameplay_CheatManager : UCheatManager
{
    UFUNCTION(Exec)
    void Mars_Debugger()
    {
        utils_mars_debugger::Toggle();
    }
}
