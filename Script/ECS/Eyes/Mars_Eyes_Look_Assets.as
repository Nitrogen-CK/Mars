// The eye-plate look: an opaque unlit master that CkUsf generates from Shaders/Looks/EyePlate.ush into Mars content
// (console: Ck_Usf_GenerateLooks MarsEyePlate). The generator passes _Parameters to the shader positionally, so their
// order IS the .ush signature after In. The custom-primitive-data indices are the layout mars_eyes_material writes
// (Mars_Eyes_Material.as); they are spelled out here rather than read from it so a test can compare the two. With
// nothing written Strength reads 0 and the surface is pure black, which is why the same master also draws the void.

asset MarsEyePlate of UCkUsf_LookDefinition
{
    _UshIncludePath       = "/Project/Looks/EyePlate.ush";
    _UshFunctionName      = n"Mars_Look_EyePlate";
    _Domain               = ECk_Usf_Domain::SurfaceUnlit;
    _BlendMode            = ECk_Usf_BlendMode::Opaque;
    _LookName             = n"MarsEyePlate";
    _GeneratedPackageRoot = "/Game/Mars/Materials/GeneratedLooks";

    // The plate may later become a material slot on the body.
    _UsedWithSkeletalMesh = true;

    FCk_Usf_ParamDesc Atlas;
    Atlas._Name               = n"Atlas";
    Atlas._Type               = ECk_Usf_ParamType::Texture2D;
    Atlas._DefaultTexturePath = "/Game/Mars/Gameplay/PlayerCharacter/Eyes/Eyes_Atlas_Mars_T.Eyes_Atlas_Mars_T";
    _Parameters.Add(Atlas);

    FCk_Usf_ParamDesc LeftCell;
    LeftCell._Name                     = n"LeftCell";
    LeftCell._Type                     = ECk_Usf_ParamType::Scalar;
    LeftCell._DefaultScalar            = 0.0f;
    LeftCell._CustomPrimitiveData      = true;
    LeftCell._CustomPrimitiveDataIndex = 0;
    _Parameters.Add(LeftCell);

    FCk_Usf_ParamDesc RightCell;
    RightCell._Name                     = n"RightCell";
    RightCell._Type                     = ECk_Usf_ParamType::Scalar;
    RightCell._DefaultScalar            = 0.0f;
    RightCell._CustomPrimitiveData      = true;
    RightCell._CustomPrimitiveDataIndex = 1;
    _Parameters.Add(RightCell);

    FCk_Usf_ParamDesc PrevLeftCell;
    PrevLeftCell._Name                     = n"PrevLeftCell";
    PrevLeftCell._Type                     = ECk_Usf_ParamType::Scalar;
    PrevLeftCell._DefaultScalar            = 0.0f;
    PrevLeftCell._CustomPrimitiveData      = true;
    PrevLeftCell._CustomPrimitiveDataIndex = 2;
    _Parameters.Add(PrevLeftCell);

    FCk_Usf_ParamDesc PrevRightCell;
    PrevRightCell._Name                     = n"PrevRightCell";
    PrevRightCell._Type                     = ECk_Usf_ParamType::Scalar;
    PrevRightCell._DefaultScalar            = 0.0f;
    PrevRightCell._CustomPrimitiveData      = true;
    PrevRightCell._CustomPrimitiveDataIndex = 3;
    _Parameters.Add(PrevRightCell);

    FCk_Usf_ParamDesc Blend;
    Blend._Name                     = n"Blend";
    Blend._Type                     = ECk_Usf_ParamType::Scalar;
    Blend._DefaultScalar            = 1.0f;
    Blend._CustomPrimitiveData      = true;
    Blend._CustomPrimitiveDataIndex = 4;
    _Parameters.Add(Blend);

    FCk_Usf_ParamDesc BlinkLeft;
    BlinkLeft._Name                     = n"BlinkLeft";
    BlinkLeft._Type                     = ECk_Usf_ParamType::Scalar;
    BlinkLeft._DefaultScalar            = 0.0f;
    BlinkLeft._CustomPrimitiveData      = true;
    BlinkLeft._CustomPrimitiveDataIndex = 5;
    _Parameters.Add(BlinkLeft);

    FCk_Usf_ParamDesc BlinkRight;
    BlinkRight._Name                     = n"BlinkRight";
    BlinkRight._Type                     = ECk_Usf_ParamType::Scalar;
    BlinkRight._DefaultScalar            = 0.0f;
    BlinkRight._CustomPrimitiveData      = true;
    BlinkRight._CustomPrimitiveDataIndex = 6;
    _Parameters.Add(BlinkRight);

    FCk_Usf_ParamDesc Strength;
    Strength._Name                     = n"Strength";
    Strength._Type                     = ECk_Usf_ParamType::Scalar;
    Strength._DefaultScalar            = 0.0f;
    Strength._CustomPrimitiveData      = true;
    Strength._CustomPrimitiveDataIndex = 7;
    _Parameters.Add(Strength);

    FCk_Usf_ParamDesc LookX;
    LookX._Name                     = n"LookX";
    LookX._Type                     = ECk_Usf_ParamType::Scalar;
    LookX._DefaultScalar            = 0.0f;
    LookX._CustomPrimitiveData      = true;
    LookX._CustomPrimitiveDataIndex = 8;
    _Parameters.Add(LookX);

    FCk_Usf_ParamDesc LookY;
    LookY._Name                     = n"LookY";
    LookY._Type                     = ECk_Usf_ParamType::Scalar;
    LookY._DefaultScalar            = 0.0f;
    LookY._CustomPrimitiveData      = true;
    LookY._CustomPrimitiveDataIndex = 9;
    _Parameters.Add(LookY);

    // A Vector reads the whole float4 at 10..13; the look uses .rgb.
    FCk_Usf_ParamDesc EyeColor;
    EyeColor._Name                     = n"EyeColor";
    EyeColor._Type                     = ECk_Usf_ParamType::Vector;
    EyeColor._DefaultVector            = FLinearColor(1.0, 0.78, 0.45, 1.0);
    EyeColor._CustomPrimitiveData      = true;
    EyeColor._CustomPrimitiveDataIndex = 10;
    _Parameters.Add(EyeColor);

    FCk_Usf_ParamDesc AtlasCols;
    AtlasCols._Name          = n"AtlasCols";
    AtlasCols._Type          = ECk_Usf_ParamType::Scalar;
    AtlasCols._DefaultScalar = 8.0f;
    _Parameters.Add(AtlasCols);

    FCk_Usf_ParamDesc AtlasRows;
    AtlasRows._Name          = n"AtlasRows";
    AtlasRows._Type          = ECk_Usf_ParamType::Scalar;
    AtlasRows._DefaultScalar = 4.0f;
    _Parameters.Add(AtlasRows);

    FCk_Usf_ParamDesc EyeScale;
    EyeScale._Name          = n"EyeScale";
    EyeScale._Type          = ECk_Usf_ParamType::Scalar;
    EyeScale._DefaultScalar = 1.0f;
    _Parameters.Add(EyeScale);

    FCk_Usf_ParamDesc LookMaxUV;
    LookMaxUV._Name          = n"LookMaxUV";
    LookMaxUV._Type          = ECk_Usf_ParamType::Scalar;
    LookMaxUV._DefaultScalar = 0.12f;
    _Parameters.Add(LookMaxUV);

    FCk_Usf_ParamDesc MinBlinkScale;
    MinBlinkScale._Name          = n"MinBlinkScale";
    MinBlinkScale._Type          = ECk_Usf_ParamType::Scalar;
    MinBlinkScale._DefaultScalar = 0.06f;
    _Parameters.Add(MinBlinkScale);

    FCk_Usf_ParamDesc GlowStrength;
    GlowStrength._Name          = n"GlowStrength";
    GlowStrength._Type          = ECk_Usf_ParamType::Scalar;
    GlowStrength._DefaultScalar = 0.35f;
    _Parameters.Add(GlowStrength);

    FCk_Usf_ParamDesc CellPad;
    CellPad._Name          = n"CellPad";
    CellPad._Type          = ECk_Usf_ParamType::Scalar;
    CellPad._DefaultScalar = 0.02f;
    _Parameters.Add(CellPad);
}

namespace mars_eyes
{
    UCkUsf_LookDefinition Look_EyePlate()
    {
        return MarsEyePlate;
    }
}
