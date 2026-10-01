// The MarsEyePlate master has been generated and resolves through utils_usf::Get_LookMasterMaterial, and the texture
// the look's Atlas parameter names loads as a linear (sRGB off) Texture2D - the distance field is data, not colour -
// and is the generated master's Atlas texture (read in the editor only). Fails until the editor step has imported the
// atlas and run Ck_Usf_GenerateLooks MarsEyePlate. Reads assets only; nothing is placed. Isolated Z band: -70000.
class UMars_AutoTest_Eyes_LookMasterResolves : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the generated master resolves", n"Step_AssertMasterResolves");
        Add_Step("the look's atlas loads with sRGB off and is the master's Atlas texture", n"Step_AssertAtlasIsLinear");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertMasterResolves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Master = utils_usf::Get_LookMasterMaterial(mars_eyes::Look_EyePlate());
        Assert_True(ck::IsValid(Master),
            "Get_LookMasterMaterial(MarsEyePlate) - the master is not generated; run Ck_Usf_GenerateLooks MarsEyePlate in the editor");
    }

    UFUNCTION()
    private void Step_AssertAtlasIsLinear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto AtlasPath = FString();
        for (const auto& Parameter : mars_eyes::Look_EyePlate()._Parameters)
        {
            if (Parameter._Name == n"Atlas")
            { AtlasPath = Parameter._DefaultTexturePath; }
        }

        if (AtlasPath.IsEmpty())
        {
            FinishFailure("MarsEyePlate has no Atlas parameter with a default texture path");
            return;
        }

        auto Atlas = Cast<UTexture2D>(LoadObject(this, AtlasPath));
        if (ck::Is_NOT_Valid(Atlas))
        {
            FinishFailure(f"the atlas [{AtlasPath}] does not load as a Texture2D - import it with Tools/EyesAtlas/import_eye_atlas.py");
            return;
        }

        Assert_False(Atlas.SRGB, f"the atlas [{AtlasPath}] has sRGB off");

#if EDITOR
        auto Master = utils_usf::Get_LookMasterMaterial(mars_eyes::Look_EyePlate());
        if (ck::Is_NOT_Valid(Master))
        {
            FinishFailure("Get_LookMasterMaterial(MarsEyePlate) - the master is not generated; run Ck_Usf_GenerateLooks MarsEyePlate in the editor");
            return;
        }

        auto MasterAtlas = MaterialEditing::GetMaterialDefaultTextureParameterValue(Master.GetBaseMaterial(), n"Atlas");
        auto MasterAtlasPath = FString();
        if (ck::IsValid(MasterAtlas))
        { MasterAtlasPath = MasterAtlas.GetPathName(); }

        Assert_Equals_String(MasterAtlasPath, Atlas.GetPathName(), "the generated master's Atlas texture parameter");
#endif
    }
}
