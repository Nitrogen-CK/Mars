// The eye-swarm looks: MarsEyeball (Shaders/Looks/EyeSwarmEyeball.ush) and MarsEyelid (Shaders/Looks/EyeSwarmEyelid.ush),
// shared maths in Shaders/Looks/EyeSwarmCommon.ush. CkUsf generates each into Mars content
// (console: Ck_Usf_GenerateLooks MarsEyeball, Ck_Usf_GenerateLooks MarsEyelid). The generator passes _Parameters to the
// shader positionally, so the order below IS each .ush signature after In.
//
// ==== DATA CONTRACT (what the meshes, the ISM writer and the script side must provide) ===============================
//
// Meshes. Both are spheres centred on the pivot; forward = local +X, up = local +Z. Eyeball radius 5 cm, lid shell radius
//   5.5 cm. Vertex colour RGB = local unit normal * 0.5 + 0.5, stored as raw bytes (no sRGB curve: the +Z pole reads
//   128,128,255); the shader decodes normalize(VertexColor * 2 - 1). UV0 may exist but is never read.
//   The eyeball goes on an ISM (or a plain static-mesh component) with MarsEyeball; its lid shell on a second ISM with the
//   SAME instance transforms and the SAME per-instance data, with MarsEyelid.
//
// Per-instance custom data (identical layout on the eyeball ISM and the lid ISM; NumCustomDataFloats >= 2):
//   slot 0  Phase    0..1  per-eye phase (the seed's per-instance half)
//   slot 1  Variant  0..1  per-eye variation: iris hue (IrisHueJitter) and size (+-6%), lid brightness (+-8%)
//   Writers query Get_PerInstanceSlotOf(n"Phase") / (n"Variant") rather than hard-coding 0 / 1.
//   A non-instanced mesh reads the defaults (Phase 0, Variant 0.5).
//
// Custom primitive data (per component; for single eyes and cluster overrides; same in both looks):
//   index 0     PhaseCpd             Scalar  added to Phase: seed = frac(Phase + PhaseCpd)
//   index 4..7  FocusOverride        Vector  xyz = world cm target (index 7 is read but unused)
//   index 8     FocusOverrideWeight  Scalar  0..1; blends the override in over the roster aim (1 = fully replaces it),
//                                            and the eye's focus weight becomes lerp(roster weight, 1, this)
//   Unwritten CPD reads 0, i.e. no override.
//
// Player roster: material parameter collection /Game/Mars/Gameplay/Monsters/EyeSwarm/Materials/EyeSwarm_Mars_MPC,
//   Vector parameters Player0..Player3, xyz = that player's head in world cm. An absent player is parked at
//   (0, 0, -1e7) so its weight is 0. Each eye focuses the NEAREST roster entry; weight = 1 at <= FocusNearCm, 0 at
//   >= FocusFarCm (smoothstep between), measured from the eye's centre.
//
// Uniforms set by name on a MID (the shared ones exist on both looks with identical defaults; set them on both, or the
//   lid and the eyeball blink at different times):
//   MarsEyeball only: ScleraColor, IrisColor, PupilColor, EmissiveStrength (0 = cartoon; horror ~8 with a red iris and a
//     dark-red sclera), ScleraGlow, ShaderLid (0/1: the eyeball paints its own lid; 0 = the lid mesh is the lid),
//     BlinkSquash (0..1: lidless blink as a vertical iris squash + emissive dip; ignored while ShaderLid is 1),
//     IrisAngleDeg, PupilAngleDeg, PupilFocusScale (pupil constriction at full focus), LimbalWidthDeg, LimbalDarken,
//     IrisHueJitter, ScleraRoughness, IrisRoughness, MaxLookDeg, WanderAmpDeg, SaccadeMinS, SaccadeMaxS, SaccadeS,
//     MicroJitterDeg.
//     Stylisation (MarsEyeball only, appended last): ScleraRimColor, ScleraRimPower, ScleraRimStrength (sclera darkens
//     from the forward pole to the rim), UpperShadeStrength, UpperShadeStartDeg, UpperShadeSoftDeg (shade band under the
//     upper lid edge, over sclera and iris), IrisInnerColor, IrisInnerWidth (bright ring round the pupil),
//     IrisFibreStrength, IrisFibreCount (radial streaks), GlintStrength, GlintSize, GlintColor (painted highlights riding
//     the iris), PupilSlit (0 round .. 1 vertical slit), PupilHaloColor, PupilHaloAngleDeg, PupilHaloStrength (radial
//     glow round the pupil over the sclera, also emissive; 0 = off), ViewCentreBoost (view-facing sclera brightening), EmissiveFacingPower (view-space sphere mask on the glow; 0 = flat).
//     Iris-less mode: IrisAngleDeg <= PupilAngleDeg (or <= 0) draws no iris at all, the pupil straight on the sclera. A preset that recolours IrisColor / ScleraColor should recolour
//     IrisInnerColor / ScleraRimColor with them (utils_eye_swarm::Apply_Preset does).
//   Both: LidColor, LidRoughness, LidRimDarken, LidRimWidthDeg, FocusNearCm, FocusFarCm, BlinkIntervalMinS,
//     BlinkIntervalMaxS, BlinkCloseS, BlinkHoldS, BlinkOpenS, DoubleBlinkChance, FocusBlinkSuppress, LidOpenFraction,
//     FocusWidenAperture, LidOpenUpperDeg, LidOpenLowerDeg, LidMeetDeg, LidBackCoverX, ShellRadiusCm (5 on the eyeball,
//     5.5 on the lid: the radius the eye centre is recovered from; scale it with the instance scale for big eyes), then
//     GradientTopTint, GradientBottomTint, GradientStrength (the whole-eye up/down multiplicative tint on the sclera, the
//     painted lid and the lid shell, never the iris; keep them equal on both looks or ball and lid shade differently),
//     then ViewRimDarken, ViewRimPower (view-dependent silhouette darkening on everything but the glints; equal on both).
//   Parameter order: each look's list below IS its .ush signature after In. MarsEyeball: sources, colour, iris, gaze,
//     blink, lid shape, then the stylisation block (ScleraRim*, Gradient*, UpperShade*, IrisInner*, IrisFibre*, Glint*,
//     PupilSlit, PupilHalo*, ViewRimDarken, ViewRimPower, ViewCentreBoost, EmissiveFacingPower). MarsEyelid: sources, flesh, focus distance,
//     blink, lid shape, Gradient*, ViewRimDarken, ViewRimPower. New parameters go at the END.
//
// Behaviour (stateless; a function of the material time, the seed and the inputs above):
//   Blink: one blink per cell of mean(BlinkIntervalMinS, BlinkIntervalMaxS) at a hashed offset (starts are between the
//     min and the max apart), DoubleBlinkChance of them doubled; close BlinkCloseS, hold BlinkHoldS, open BlinkOpenS.
//     Keep BlinkIntervalMinS >= ~0.8 s. Focus weight -> 1 suppresses blinking by FocusBlinkSuppress and opens the lids
//     by FocusWidenAperture.
//   Wander: a saccade every SaccadeMinS..SaccadeMaxS to a hashed target within WanderAmpDeg, reached in SaccadeS and
//     held, plus MicroJitterDeg tremor. Final gaze = lerp(wander, aim at nearest player, weight), then the override by
//     its weight, clamped to MaxLookDeg off forward.
//   Lids: the upper lid edge sits at lerp(LidMeetDeg, LidOpenUpperDeg, openness) above the forward axis, the lower at
//     lerp(LidMeetDeg, -LidOpenLowerDeg, openness); openness = (LidOpenFraction + FocusWidenAperture * weight) * (1 -
//     blink). The aperture is the lens between them, pinched at the eye's +-Y sides; local normal.x < LidBackCoverX is
//     always flesh.
//   Stylisation is in the eye's local frame (view-independent, like paint) except ViewRim* / ViewCentreBoost: the up/down gradient follows local +Z,
//     the rim gradient local +X, the upper shade hangs off the upper lid edge (so it descends with a blink), and the
//     iris fibres and glints ride the gaze. The iris takes the upper shade but neither gradient, so it stays a flat disc
//     on top.
//
// Instance frame: the eyeball aims through GetWorldToInstanceDF, which in a pixel shader is per-INSTANCE only when the
//   material graph has a pixel-stage World -> Instance transform node; MarsEyeball sets _PixelInstanceFrame so the CkUsf
//   generator wires one in. Non-instanced permutations of the same master read the primitive's transform, which is right
//   for a single eye on its own component.
// ======================================================================================================================

asset MarsEyeball of UCkUsf_LookDefinition
{
    _UshIncludePath       = "/Project/Looks/EyeSwarmEyeball.ush";
    _UshFunctionName      = n"Mars_Look_EyeSwarmEyeball";
    _Domain               = ECk_Usf_Domain::SurfaceLit;
    _BlendMode            = ECk_Usf_BlendMode::Opaque;
    _ShadingModel         = ECk_Usf_ShadingModel::DefaultLit;
    _LookName             = n"MarsEyeball";
    _GeneratedPackageRoot = "/Game/Mars/Materials/GeneratedLooks";

    _UsedWithInstancedStaticMeshes = true;

    // The eyeball aims through GetWorldToInstanceDF(Parameters) (see the .ush header); the generator wires a pixel-stage
    // World -> Instance transform probe so that reads each INSTANCE's frame on an ISM, not the component's.
    _PixelInstanceFrame = true;

    // ---- Sources: per-instance, custom primitive data, MPC roster (same layout as MarsEyelid) ----
    _Parameters.Add(utils_eyeswarm::LookParam_PerInstance(n"Phase", 0.0, 0));
    _Parameters.Add(utils_eyeswarm::LookParam_PerInstance(n"Variant", 0.5, 1));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdScalar(n"PhaseCpd", 0));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdVector(n"FocusOverride", 4));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdScalar(n"FocusOverrideWeight", 8));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player0"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player1"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player2"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player3"));

    // ---- Colour ----
    _Parameters.Add(CkUsf::Usf_VectorIn(n"ScleraColor", FLinearColor(0.95, 0.93, 0.88, 1.0), n"Colour"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"IrisColor", FLinearColor(0.85, 0.55, 0.15, 1.0), n"Colour"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"PupilColor", FLinearColor(0.02, 0.02, 0.02, 1.0), n"Colour"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"LidColor", FLinearColor(0.55, 0.32, 0.26, 1.0), n"Colour"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"EmissiveStrength", 0.0, n"Colour"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ScleraGlow", 0.15, n"Colour"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ShaderLid", 0.0, n"Colour"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkSquash", 1.0, n"Colour"));

    // ---- Iris ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisAngleDeg", 32.0, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"PupilAngleDeg", 13.0, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"PupilFocusScale", 0.6, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LimbalWidthDeg", 5.0, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LimbalDarken", 0.55, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisHueJitter", 0.06, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ScleraRoughness", 0.22, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisRoughness", 0.12, n"Iris"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRoughness", 0.6, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRimDarken", 0.35, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRimWidthDeg", 5.0, n"Lid"));

    // ---- Gaze ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"MaxLookDeg", 35.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusNearCm", 300.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusFarCm", 900.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"WanderAmpDeg", 22.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"SaccadeMinS", 0.8, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"SaccadeMaxS", 3.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"SaccadeS", 0.07, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"MicroJitterDeg", 0.3, n"Gaze"));

    // ---- Blink (identical defaults on MarsEyelid) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkIntervalMinS", 2.0, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkIntervalMaxS", 6.0, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkCloseS", 0.07, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkHoldS", 0.05, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkOpenS", 0.16, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"DoubleBlinkChance", 0.2, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusBlinkSuppress", 0.9, n"Blink"));

    // ---- Lid shape (identical defaults on MarsEyelid) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenFraction", 0.9, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusWidenAperture", 0.12, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenUpperDeg", 58.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenLowerDeg", 48.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidMeetDeg", -8.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidBackCoverX", -0.2, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ShellRadiusCm", 5.0, n"Lid"));

    // ---- Stylisation (appended after the original list so existing call sites and MIDs keep their meaning) ----
    // Sclera sphere gradient: forward pole -> rim, lerping ScleraColor toward ScleraRimColor.
    _Parameters.Add(CkUsf::Usf_VectorIn(n"ScleraRimColor", FLinearColor(0.60, 0.58, 0.60, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ScleraRimPower", 1.6, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ScleraRimStrength", 0.6, n"Stylise"));
    // ---- Stylisation: whole-eye up/down gradient (identical defaults on MarsEyelid; multiplicative tints) ----
    _Parameters.Add(CkUsf::Usf_VectorIn(n"GradientTopTint", FLinearColor(0.75, 0.75, 0.75, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"GradientBottomTint", FLinearColor(1.0, 1.0, 1.0, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"GradientStrength", 1.0, n"Stylise"));
    // Upper lid shade band: full from the upper lid edge down to UpperShadeStartDeg below it, fading over UpperShadeSoftDeg.
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"UpperShadeStrength", 0.35, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"UpperShadeStartDeg", 22.0, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"UpperShadeSoftDeg", 12.0, n"Stylise"));
    // Iris radial gradient: inner ring colour (absolute, hue-jittered like IrisColor) and its width as a share of the iris
    // angle; radial fibre streaks.
    _Parameters.Add(CkUsf::Usf_VectorIn(n"IrisInnerColor", FLinearColor(1.0, 0.80, 0.30, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisInnerWidth", 0.45, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisFibreStrength", 0.25, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"IrisFibreCount", 24.0, n"Stylise"));
    // Painted glints: GlintSize is the big ellipse's radius in degrees (the dot is ~a third of it).
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"GlintStrength", 1.0, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"GlintSize", 7.0, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"GlintColor", FLinearColor(1.0, 0.98, 0.95, 1.0), n"Stylise"));
    // Pupil shape: 0 = round, 1 = vertical slit.
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"PupilSlit", 0.0, n"Stylise"));
    // Pupil halo: a radial glow round the pupil over the sclera, gone PupilHaloAngleDeg from the pupil centre; also emissive.
    _Parameters.Add(CkUsf::Usf_VectorIn(n"PupilHaloColor", FLinearColor(1.0, 0.45, 0.15, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"PupilHaloAngleDeg", 30.0, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"PupilHaloStrength", 0.0, n"Stylise"));
    // ---- View-dependent sphere shading: silhouette darkening (identical defaults on both looks) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ViewRimDarken", 0.25, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ViewRimPower", 2.0, n"Stylise"));
    // Soft brightening of the sclera where it faces the camera (lit from within); 0 = off.
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ViewCentreBoost", 0.0, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"EmissiveFacingPower", 0.0, n"Stylise"));
}

asset MarsEyelid of UCkUsf_LookDefinition
{
    _UshIncludePath       = "/Project/Looks/EyeSwarmEyelid.ush";
    _UshFunctionName      = n"Mars_Look_EyeSwarmEyelid";
    _Domain               = ECk_Usf_Domain::SurfaceLit;
    _BlendMode            = ECk_Usf_BlendMode::Masked;
    _ShadingModel         = ECk_Usf_ShadingModel::DefaultLit;
    _TwoSided             = true;
    _LookName             = n"MarsEyelid";
    _GeneratedPackageRoot = "/Game/Mars/Materials/GeneratedLooks";

    _UsedWithInstancedStaticMeshes = true;

    // ---- Sources (same layout as MarsEyeball) ----
    _Parameters.Add(utils_eyeswarm::LookParam_PerInstance(n"Phase", 0.0, 0));
    _Parameters.Add(utils_eyeswarm::LookParam_PerInstance(n"Variant", 0.5, 1));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdScalar(n"PhaseCpd", 0));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdVector(n"FocusOverride", 4));
    _Parameters.Add(utils_eyeswarm::LookParam_CpdScalar(n"FocusOverrideWeight", 8));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player0"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player1"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player2"));
    _Parameters.Add(utils_eyeswarm::LookParam_Roster(n"Player3"));

    // ---- Flesh ----
    _Parameters.Add(CkUsf::Usf_VectorIn(n"LidColor", FLinearColor(0.55, 0.32, 0.26, 1.0), n"Colour"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRoughness", 0.6, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRimDarken", 0.35, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidRimWidthDeg", 5.0, n"Lid"));

    // ---- Focus distance (identical defaults on MarsEyeball) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusNearCm", 300.0, n"Gaze"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusFarCm", 900.0, n"Gaze"));

    // ---- Blink (identical defaults on MarsEyeball) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkIntervalMinS", 2.0, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkIntervalMaxS", 6.0, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkCloseS", 0.07, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkHoldS", 0.05, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"BlinkOpenS", 0.16, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"DoubleBlinkChance", 0.2, n"Blink"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusBlinkSuppress", 0.9, n"Blink"));

    // ---- Lid shape (identical defaults on MarsEyeball) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenFraction", 0.9, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"FocusWidenAperture", 0.12, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenUpperDeg", 58.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidOpenLowerDeg", 48.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidMeetDeg", -8.0, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"LidBackCoverX", -0.2, n"Lid"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ShellRadiusCm", 5.5, n"Lid"));

    // ---- Stylisation: whole-eye up/down gradient (identical defaults on MarsEyelid; multiplicative tints) ----
    _Parameters.Add(CkUsf::Usf_VectorIn(n"GradientTopTint", FLinearColor(0.75, 0.75, 0.75, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_VectorIn(n"GradientBottomTint", FLinearColor(1.0, 1.0, 1.0, 1.0), n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"GradientStrength", 1.0, n"Stylise"));
    // ---- View-dependent sphere shading: silhouette darkening (identical defaults on both looks) ----
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ViewRimDarken", 0.25, n"Stylise"));
    _Parameters.Add(CkUsf::Usf_ScalarIn(n"ViewRimPower", 2.0, n"Stylise"));
}

namespace utils_eyeswarm
{
    // Script asset globals are file-local: other files reach the looks through these.
    UCkUsf_LookDefinition Look_EyeSwarmEyeball() { return MarsEyeball; }
    UCkUsf_LookDefinition Look_EyeSwarmEyelid() { return MarsEyelid; }

    FCk_Usf_ParamDesc LookParam_PerInstance(FName InName, float InDefault, int InSlot)
    {
        FCk_Usf_ParamDesc Param = CkUsf::Usf_ScalarIn(InName, InDefault, n"Source");
        Param._PerInstance = true;
        Param._PerInstanceSlot = InSlot;
        return Param;
    }

    FCk_Usf_ParamDesc LookParam_CpdScalar(FName InName, int InIndex)
    {
        FCk_Usf_ParamDesc Param = CkUsf::Usf_ScalarIn(InName, 0.0, n"Source");
        Param._CustomPrimitiveData = true;
        Param._CustomPrimitiveDataIndex = InIndex;
        return Param;
    }

    // A Vector reads the whole float4 at InIndex..InIndex+3; the look uses .rgb.
    FCk_Usf_ParamDesc LookParam_CpdVector(FName InName, int InIndex)
    {
        FCk_Usf_ParamDesc Param = CkUsf::Usf_VectorIn(InName, FLinearColor(0.0, 0.0, 0.0, 0.0), n"Source");
        Param._CustomPrimitiveData = true;
        Param._CustomPrimitiveDataIndex = InIndex;
        return Param;
    }

    // One roster entry from EyeSwarm_Mars_MPC; the material parameter takes the collection parameter's name.
    FCk_Usf_ParamDesc LookParam_Roster(FName InCollectionParameterName)
    {
        FCk_Usf_ParamDesc Param = CkUsf::Usf_VectorIn(
            InCollectionParameterName, FLinearColor(0.0, 0.0, -1.0e7, 0.0), n"Source");
        Param._FromCollection = true;
        Param._Collection = TSoftObjectPtr<UMaterialParameterCollection>(
            FSoftObjectPath("/Game/Mars/Gameplay/Monsters/EyeSwarm/Materials/EyeSwarm_Mars_MPC.EyeSwarm_Mars_MPC"));
        Param._CollectionParameterName = InCollectionParameterName;
        return Param;
    }
}
