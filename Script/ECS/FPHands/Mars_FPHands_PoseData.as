// GENERATED - do not edit. Baked from /Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/A_FPHands_* by
// Content/Python/mars_fphands_bake.py. Re-bake after re-importing the grip poses.
// Local (parent-space) rotations of the 24 digit bones for each EMars_HandGripPose; runtime cannot sample anim poses.
namespace utils_fphands
{
    const int32 DigitBoneCount = 24;

    // Bone order: per side (l, r): thumb, index, middle, pinky x segments 01..03.
    FName Get_DigitBoneName(int32 InBone)
    {
        switch (InBone)
        {
            case 0: return n"thumb_01_l";
            case 1: return n"thumb_02_l";
            case 2: return n"thumb_03_l";
            case 3: return n"index_01_l";
            case 4: return n"index_02_l";
            case 5: return n"index_03_l";
            case 6: return n"middle_01_l";
            case 7: return n"middle_02_l";
            case 8: return n"middle_03_l";
            case 9: return n"pinky_01_l";
            case 10: return n"pinky_02_l";
            case 11: return n"pinky_03_l";
            case 12: return n"thumb_01_r";
            case 13: return n"thumb_02_r";
            case 14: return n"thumb_03_r";
            case 15: return n"index_01_r";
            case 16: return n"index_02_r";
            case 17: return n"index_03_r";
            case 18: return n"middle_01_r";
            case 19: return n"middle_02_r";
            case 20: return n"middle_03_r";
            case 21: return n"pinky_01_r";
            case 22: return n"pinky_02_r";
            case 23: return n"pinky_03_r";
        }
        return NAME_None;
    }

    FQuat Get_DigitBoneRotation(EMars_HandGripPose InPose, int32 InBone)
    {
        switch (int32(InPose) * DigitBoneCount + InBone)
        {
            case 0: return FQuat(-0.666261, -0.189562, -0.494865, 0.524663); // Relaxed thumb_01_l
            case 1: return FQuat(-0.075434, -0.257267, 0.133362, 0.954117); // Relaxed thumb_02_l
            case 2: return FQuat(-0.015869, -0.100872, 0.065602, 0.992607); // Relaxed thumb_03_l
            case 3: return FQuat(-0.009003, -0.310346, 0.076245, 0.947518); // Relaxed index_01_l
            case 4: return FQuat(0.007163, -0.272910, 0.021550, 0.961771); // Relaxed index_02_l
            case 5: return FQuat(0.000000, -0.069758, 0.000000, 0.997564); // Relaxed index_03_l
            case 6: return FQuat(-0.012994, -0.315283, 0.101989, 0.943412); // Relaxed middle_01_l
            case 7: return FQuat(0.000000, -0.295185, -0.000000, 0.955440); // Relaxed middle_02_l
            case 8: return FQuat(0.008979, -0.086994, 0.018784, 0.995991); // Relaxed middle_03_l
            case 9: return FQuat(-0.014810, -0.326215, 0.136659, 0.935248); // Relaxed pinky_01_l
            case 10: return FQuat(0.006694, -0.329080, 0.020667, 0.944052); // Relaxed pinky_02_l
            case 11: return FQuat(0.000425, -0.111485, 0.000889, 0.993766); // Relaxed pinky_03_l
            case 12: return FQuat(0.666261, -0.189562, 0.494865, 0.524663); // Relaxed thumb_01_r
            case 13: return FQuat(0.075434, -0.257267, -0.133362, 0.954117); // Relaxed thumb_02_r
            case 14: return FQuat(0.015869, -0.100872, -0.065602, 0.992607); // Relaxed thumb_03_r
            case 15: return FQuat(0.009003, -0.310346, -0.076245, 0.947518); // Relaxed index_01_r
            case 16: return FQuat(-0.007163, -0.272910, -0.021550, 0.961771); // Relaxed index_02_r
            case 17: return FQuat(-0.000000, -0.069758, -0.000000, 0.997564); // Relaxed index_03_r
            case 18: return FQuat(0.012994, -0.315283, -0.101989, 0.943412); // Relaxed middle_01_r
            case 19: return FQuat(-0.000000, -0.295185, 0.000000, 0.955440); // Relaxed middle_02_r
            case 20: return FQuat(-0.008979, -0.086994, -0.018784, 0.995991); // Relaxed middle_03_r
            case 21: return FQuat(0.014810, -0.326215, -0.136659, 0.935248); // Relaxed pinky_01_r
            case 22: return FQuat(-0.006694, -0.329080, -0.020667, 0.944052); // Relaxed pinky_02_r
            case 23: return FQuat(-0.000425, -0.111485, -0.000889, 0.993766); // Relaxed pinky_03_r
            case 24: return FQuat(-0.639909, -0.200083, -0.684447, 0.286384); // Grip_Power thumb_01_l
            case 25: return FQuat(-0.226069, -0.421934, 0.139344, 0.866861); // Grip_Power thumb_02_l
            case 26: return FQuat(0.004001, -0.386675, 0.067375, 0.919743); // Grip_Power thumb_03_l
            case 27: return FQuat(0.010887, -0.535888, 0.084762, 0.839953); // Grip_Power index_01_l
            case 28: return FQuat(0.016332, -0.687439, 0.015779, 0.725887); // Grip_Power index_02_l
            case 29: return FQuat(-0.000000, -0.348573, -0.000000, 0.937282); // Grip_Power index_03_l
            case 30: return FQuat(0.013846, -0.548713, 0.101877, 0.829665); // Grip_Power middle_01_l
            case 31: return FQuat(0.000000, -0.715310, -0.000000, 0.698807); // Grip_Power middle_02_l
            case 32: return FQuat(0.013970, -0.367912, 0.015436, 0.929628); // Grip_Power middle_03_l
            case 33: return FQuat(0.018708, -0.552092, 0.127445, 0.823773); // Grip_Power pinky_01_l
            case 34: return FQuat(-0.015977, 0.750138, -0.014719, -0.660924); // Grip_Power pinky_02_l
            case 35: return FQuat(0.000681, -0.413119, 0.000715, 0.910677); // Grip_Power pinky_03_l
            case 36: return FQuat(0.639909, -0.200083, 0.684447, 0.286384); // Grip_Power thumb_01_r
            case 37: return FQuat(0.226069, -0.421934, -0.139344, 0.866861); // Grip_Power thumb_02_r
            case 38: return FQuat(-0.004001, -0.386675, -0.067375, 0.919743); // Grip_Power thumb_03_r
            case 39: return FQuat(-0.010887, -0.535888, -0.084762, 0.839953); // Grip_Power index_01_r
            case 40: return FQuat(-0.016332, -0.687439, -0.015779, 0.725887); // Grip_Power index_02_r
            case 41: return FQuat(0.000000, -0.348573, 0.000000, 0.937282); // Grip_Power index_03_r
            case 42: return FQuat(-0.013846, -0.548713, -0.101877, 0.829665); // Grip_Power middle_01_r
            case 43: return FQuat(-0.000000, -0.715310, 0.000000, 0.698807); // Grip_Power middle_02_r
            case 44: return FQuat(-0.013970, -0.367912, -0.015436, 0.929628); // Grip_Power middle_03_r
            case 45: return FQuat(-0.018708, -0.552092, -0.127445, 0.823773); // Grip_Power pinky_01_r
            case 46: return FQuat(0.015977, 0.750138, 0.014719, -0.660924); // Grip_Power pinky_02_r
            case 47: return FQuat(-0.000681, -0.413119, -0.000715, 0.910677); // Grip_Power pinky_03_r
            case 48: return FQuat(-0.719559, -0.171423, -0.452732, 0.497878); // Grip_Pinch thumb_01_l
            case 49: return FQuat(-0.167548, -0.288011, 0.119366, 0.935269); // Grip_Pinch thumb_02_l
            case 50: return FQuat(-0.016216, -0.095674, 0.065517, 0.993122); // Grip_Pinch thumb_03_l
            case 51: return FQuat(-0.006999, -0.317116, 0.067727, 0.945939); // Grip_Pinch index_01_l
            case 52: return FQuat(0.007163, -0.272910, 0.021550, 0.961771); // Grip_Pinch index_02_l
            case 53: return FQuat(0.000000, -0.062791, 0.000000, 0.998027); // Grip_Pinch index_03_l
            case 54: return FQuat(0.000250, -0.434164, 0.102813, 0.894947); // Grip_Pinch middle_01_l
            case 55: return FQuat(0.000000, -0.420539, -0.000000, 0.907275); // Grip_Pinch middle_02_l
            case 56: return FQuat(0.010707, -0.180339, 0.017856, 0.983384); // Grip_Pinch middle_03_l
            case 57: return FQuat(0.000995, -0.431548, 0.137455, 0.891556); // Grip_Pinch pinky_01_l
            case 58: return FQuat(0.009299, -0.447929, 0.019633, 0.893805); // Grip_Pinch pinky_02_l
            case 59: return FQuat(0.000504, -0.201093, 0.000847, 0.979572); // Grip_Pinch pinky_03_l
            case 60: return FQuat(0.719559, -0.171423, 0.452732, 0.497878); // Grip_Pinch thumb_01_r
            case 61: return FQuat(0.167548, -0.288011, -0.119366, 0.935269); // Grip_Pinch thumb_02_r
            case 62: return FQuat(0.016216, -0.095674, -0.065517, 0.993122); // Grip_Pinch thumb_03_r
            case 63: return FQuat(0.006999, -0.317116, -0.067727, 0.945939); // Grip_Pinch index_01_r
            case 64: return FQuat(-0.007163, -0.272910, -0.021550, 0.961771); // Grip_Pinch index_02_r
            case 65: return FQuat(-0.000000, -0.062791, -0.000000, 0.998027); // Grip_Pinch index_03_r
            case 66: return FQuat(-0.000250, -0.434164, -0.102813, 0.894947); // Grip_Pinch middle_01_r
            case 67: return FQuat(-0.000000, -0.420539, 0.000000, 0.907275); // Grip_Pinch middle_02_r
            case 68: return FQuat(-0.010707, -0.180339, -0.017856, 0.983384); // Grip_Pinch middle_03_r
            case 69: return FQuat(-0.000995, -0.431548, -0.137455, 0.891556); // Grip_Pinch pinky_01_r
            case 70: return FQuat(-0.009299, -0.447929, -0.019633, 0.893805); // Grip_Pinch pinky_02_r
            case 71: return FQuat(-0.000504, -0.201093, -0.000847, 0.979572); // Grip_Pinch pinky_03_r
            case 72: return FQuat(-0.640930, -0.254582, -0.558336, 0.461148); // Grip_Cradle thumb_01_l
            case 73: return FQuat(-0.074267, -0.265583, 0.134015, 0.951835); // Grip_Cradle thumb_02_l
            case 74: return FQuat(-0.017014, -0.083534, 0.065314, 0.994217); // Grip_Cradle thumb_03_l
            case 75: return FQuat(0.000013, -0.392291, 0.050718, 0.918442); // Grip_Cradle index_01_l
            case 76: return FQuat(0.009014, -0.355696, 0.020844, 0.934326); // Grip_Cradle index_02_l
            case 77: return FQuat(-0.000000, -0.104529, 0.000000, 0.994522); // Grip_Cradle index_03_l
            case 78: return FQuat(-0.004055, -0.396307, 0.102734, 0.912343); // Grip_Cradle middle_01_l
            case 79: return FQuat(0.000000, -0.369238, -0.000000, 0.929335); // Grip_Cradle middle_02_l
            case 80: return FQuat(0.009629, -0.121701, 0.018459, 0.992348); // Grip_Cradle middle_03_l
            case 81: return FQuat(-0.005611, -0.389617, 0.154621, 0.907887); // Grip_Cradle pinky_01_l
            case 82: return FQuat(0.008119, -0.394132, 0.020149, 0.918797); // Grip_Cradle pinky_02_l
            case 83: return FQuat(0.000456, -0.146099, 0.000874, 0.989270); // Grip_Cradle pinky_03_l
            case 84: return FQuat(0.640930, -0.254582, 0.558336, 0.461148); // Grip_Cradle thumb_01_r
            case 85: return FQuat(0.074267, -0.265583, -0.134015, 0.951835); // Grip_Cradle thumb_02_r
            case 86: return FQuat(0.017014, -0.083534, -0.065314, 0.994217); // Grip_Cradle thumb_03_r
            case 87: return FQuat(-0.000013, -0.392291, -0.050718, 0.918442); // Grip_Cradle index_01_r
            case 88: return FQuat(-0.009014, -0.355696, -0.020844, 0.934326); // Grip_Cradle index_02_r
            case 89: return FQuat(0.000000, -0.104529, -0.000000, 0.994522); // Grip_Cradle index_03_r
            case 90: return FQuat(0.004055, -0.396307, -0.102734, 0.912343); // Grip_Cradle middle_01_r
            case 91: return FQuat(-0.000000, -0.369238, 0.000000, 0.929335); // Grip_Cradle middle_02_r
            case 92: return FQuat(-0.009629, -0.121701, -0.018459, 0.992348); // Grip_Cradle middle_03_r
            case 93: return FQuat(0.005611, -0.389617, -0.154621, 0.907887); // Grip_Cradle pinky_01_r
            case 94: return FQuat(-0.008119, -0.394132, -0.020149, 0.918797); // Grip_Cradle pinky_02_r
            case 95: return FQuat(-0.000456, -0.146099, -0.000874, 0.989270); // Grip_Cradle pinky_03_r
            case 96: return FQuat(-0.678638, -0.248254, -0.497730, 0.479671); // Grip_Hook thumb_01_l
            case 97: return FQuat(-0.071917, -0.282154, 0.135290, 0.947055); // Grip_Hook thumb_02_l
            case 98: return FQuat(-0.014723, -0.118181, 0.065868, 0.990696); // Grip_Hook thumb_03_l
            case 99: return FQuat(-0.010028, -0.342529, 0.102323, 0.933865); // Grip_Hook index_01_l
            case 100: return FQuat(0.017745, -0.752700, 0.014172, 0.657972); // Grip_Hook index_02_l
            case 101: return FQuat(-0.000001, -0.484810, -0.000000, 0.874619); // Grip_Hook index_03_l
            case 102: return FQuat(-0.009426, -0.348016, 0.102381, 0.931834); // Grip_Hook middle_01_l
            case 103: return FQuat(0.000000, -0.773493, -0.000000, 0.633805); // Grip_Hook middle_02_l
            case 104: return FQuat(0.016075, -0.499768, 0.013229, 0.865909); // Grip_Hook middle_03_l
            case 105: return FQuat(-0.009866, -0.344012, 0.102339, 0.933319); // Grip_Hook pinky_01_l
            case 106: return FQuat(-0.016870, 0.790158, -0.013687, -0.612519); // Grip_Hook pinky_02_l
            case 107: return FQuat(0.000764, -0.521023, 0.000628, 0.853542); // Grip_Hook pinky_03_l
            case 108: return FQuat(0.678638, -0.248254, 0.497730, 0.479671); // Grip_Hook thumb_01_r
            case 109: return FQuat(0.071917, -0.282154, -0.135290, 0.947055); // Grip_Hook thumb_02_r
            case 110: return FQuat(0.014723, -0.118181, -0.065868, 0.990696); // Grip_Hook thumb_03_r
            case 111: return FQuat(0.010028, -0.342529, -0.102323, 0.933865); // Grip_Hook index_01_r
            case 112: return FQuat(-0.017745, -0.752700, -0.014172, 0.657972); // Grip_Hook index_02_r
            case 113: return FQuat(0.000001, -0.484810, 0.000000, 0.874619); // Grip_Hook index_03_r
            case 114: return FQuat(0.009426, -0.348016, -0.102381, 0.931834); // Grip_Hook middle_01_r
            case 115: return FQuat(-0.000000, -0.773493, 0.000000, 0.633805); // Grip_Hook middle_02_r
            case 116: return FQuat(-0.016075, -0.499768, -0.013229, 0.865909); // Grip_Hook middle_03_r
            case 117: return FQuat(0.009866, -0.344012, -0.102339, 0.933319); // Grip_Hook pinky_01_r
            case 118: return FQuat(0.016870, 0.790158, 0.013687, -0.612519); // Grip_Hook pinky_02_r
            case 119: return FQuat(-0.000764, -0.521023, -0.000628, 0.853542); // Grip_Hook pinky_03_r
            case 120: return FQuat(-0.718129, -0.195014, -0.624484, 0.237232); // Fist thumb_01_l
            case 121: return FQuat(-0.019381, -0.397651, 0.144055, 0.905951); // Fist thumb_02_l
            case 122: return FQuat(0.002297, -0.363278, 0.067455, 0.929233); // Fist thumb_03_l
            case 123: return FQuat(0.010573, -0.521835, 0.102268, 0.846828); // Fist index_01_l
            case 124: return FQuat(0.016979, -0.717233, 0.015081, 0.696463); // Fist index_02_l
            case 125: return FQuat(-0.000000, -0.418661, -0.000000, 0.908143); // Fist index_03_l
            case 126: return FQuat(0.010282, -0.519424, 0.102298, 0.848309); // Fist middle_01_l
            case 127: return FQuat(0.000000, -0.726198, -0.000000, 0.687485); // Fist middle_02_l
            case 128: return FQuat(0.014912, -0.425558, 0.014528, 0.904692); // Fist middle_03_l
            case 129: return FQuat(0.008949, -0.508336, 0.102423, 0.855000); // Fist pinky_01_l
            case 130: return FQuat(-0.015822, 0.743176, -0.014886, -0.668744); // Fist pinky_02_l
            case 131: return FQuat(0.000707, -0.446212, 0.000690, 0.894927); // Fist pinky_03_l
            case 132: return FQuat(0.718129, -0.195014, 0.624484, 0.237232); // Fist thumb_01_r
            case 133: return FQuat(0.019381, -0.397651, -0.144055, 0.905951); // Fist thumb_02_r
            case 134: return FQuat(-0.002297, -0.363278, -0.067455, 0.929233); // Fist thumb_03_r
            case 135: return FQuat(-0.010573, -0.521835, -0.102268, 0.846828); // Fist index_01_r
            case 136: return FQuat(-0.016979, -0.717233, -0.015081, 0.696463); // Fist index_02_r
            case 137: return FQuat(0.000000, -0.418661, 0.000000, 0.908143); // Fist index_03_r
            case 138: return FQuat(-0.010282, -0.519424, -0.102298, 0.848309); // Fist middle_01_r
            case 139: return FQuat(-0.000000, -0.726198, 0.000000, 0.687485); // Fist middle_02_r
            case 140: return FQuat(-0.014912, -0.425558, -0.014528, 0.904692); // Fist middle_03_r
            case 141: return FQuat(-0.008949, -0.508336, -0.102423, 0.855000); // Fist pinky_01_r
            case 142: return FQuat(0.015822, 0.743176, 0.014886, -0.668744); // Fist pinky_02_r
            case 143: return FQuat(-0.000707, -0.446212, -0.000690, 0.894927); // Fist pinky_03_r
            case 144: return FQuat(-0.564856, -0.283926, -0.651546, 0.419298); // Open thumb_01_l
            case 145: return FQuat(-0.092195, -0.130528, 0.122375, 0.979534); // Open thumb_02_l
            case 146: return FQuat(-0.025938, 0.055648, 0.062311, 0.996167); // Open thumb_03_l
            case 147: return FQuat(-0.001395, -0.123923, 0.016216, 0.992158); // Open index_01_l
            case 148: return FQuat(0.003313, -0.101754, 0.022467, 0.994550); // Open index_02_l
            case 149: return FQuat(-0.000000, 0.034898, 0.000000, 0.999391); // Open index_03_l
            case 150: return FQuat(-0.033914, -0.112247, 0.097059, 0.988347); // Open middle_01_l
            case 151: return FQuat(0.000004, -0.098775, 0.000000, 0.995110); // Open middle_02_l
            case 152: return FQuat(0.006620, 0.035035, 0.019738, 0.999169); // Open middle_03_l
            case 153: return FQuat(-0.061325, -0.106422, 0.178885, 0.976173); // Open pinky_01_l
            case 154: return FQuat(0.001871, -0.108280, 0.021643, 0.993883); // Open pinky_02_l
            case 155: return FQuat(0.000298, 0.027906, 0.000940, 0.999610); // Open pinky_03_l
            case 156: return FQuat(0.564856, -0.283926, 0.651546, 0.419298); // Open thumb_01_r
            case 157: return FQuat(0.092195, -0.130528, -0.122375, 0.979534); // Open thumb_02_r
            case 158: return FQuat(0.025938, 0.055648, -0.062311, 0.996167); // Open thumb_03_r
            case 159: return FQuat(0.001395, -0.123923, -0.016216, 0.992158); // Open index_01_r
            case 160: return FQuat(-0.003313, -0.101754, -0.022467, 0.994550); // Open index_02_r
            case 161: return FQuat(0.000000, 0.034898, -0.000000, 0.999391); // Open index_03_r
            case 162: return FQuat(0.033914, -0.112247, -0.097059, 0.988347); // Open middle_01_r
            case 163: return FQuat(-0.000004, -0.098775, -0.000000, 0.995110); // Open middle_02_r
            case 164: return FQuat(-0.006620, 0.035035, -0.019738, 0.999169); // Open middle_03_r
            case 165: return FQuat(0.061325, -0.106422, -0.178885, 0.976173); // Open pinky_01_r
            case 166: return FQuat(-0.001871, -0.108280, -0.021643, 0.993883); // Open pinky_02_r
            case 167: return FQuat(-0.000298, 0.027906, -0.000940, 0.999610); // Open pinky_03_r
        }
        return FQuat::Identity;
    }
}
