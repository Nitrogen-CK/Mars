// The drip clock of Shaders/Water/MarsDrip.ush, line for line, so script can say when a drop the shader draws releases
// and lands (tests, the leak's EffectiveRate / FallSeconds readouts, later drip audio). check_drip_parity.py diffs the
// constants below against the shader's #defines. Change both together.
//
// Float note: the shader runs in float32 and this mirror in float64. The strand key comes from Seed * 2^24, which is
// exact in both, so both hash the same uint; feed the float32 Seed the materials receive.
namespace utils_drip
{
    const float k_Gravity = 980.0;          // MARS_DRIP_GRAVITY
    const float k_Terminal = 750.0;         // MARS_DRIP_TERMINAL
    const float k_MaxJitter = 0.45;         // MARS_DRIP_MAX_JITTER
    const float k_SkipPerJitter = 0.25;     // MARS_DRIP_SKIP_PER_JITTER
    const int32 k_Slots = 4;                // MARS_DRIP_SLOTS
    const float k_Wrap = 3600.0;            // MARS_DRIP_WRAP
    const float k_SplashSeconds = 0.28;     // MARS_DRIP_SPLASH_S
    const float k_CrownSeconds = 0.16;      // MARS_DRIP_CROWN_S
    const float k_RingSpeed = 22.0;         // MARS_DRIP_RING_SPEED
    const float k_RingLife = 1.4;           // MARS_DRIP_RING_LIFE
    const float k_RingLambda = 2.4;         // MARS_DRIP_RING_LAMBDA
    const float k_DropRadius = 0.45;        // the materials' DropRadiusCm default

    uint32 Hash(uint32 InX)
    {
        uint32 X = InX;
        X = X ^ (X >> 16);
        X = X * uint32(0x7feb352d);
        X = X ^ (X >> 15);
        X = X * uint32(0x846ca68b);
        X = X ^ (X >> 16);
        return X;
    }

    // Quadratic drag from rest: y = vT^2 / g ln cosh(g a / vT), overflow-free; Get_AgeAt is its exact inverse.
    float Get_DistanceAt(float InAge)
    {
        const float X = k_Gravity * Math::Max(InAge, 0.0) / k_Terminal;
        return (k_Terminal * k_Terminal / k_Gravity) * (X + Math::Loge(0.5 + 0.5 * Math::Exp(-2.0 * X)));
    }

    // Math:: binds neither Tanh nor Acosh.
    float Get_SpeedAt(float InAge)
    {
        const float X = 2.0 * k_Gravity * Math::Max(InAge, 0.0) / k_Terminal;
        return k_Terminal * (1.0 - Math::Exp(-X)) / (1.0 + Math::Exp(-X));
    }

    float Get_AgeAt(float InDistance)
    {
        const float C = Math::Exp(k_Gravity * Math::Max(InDistance, 0.0) / (k_Terminal * k_Terminal));
        return (k_Terminal / k_Gravity) * Math::Loge(C + Math::Sqrt(Math::Max(C * C - 1.0, 0.0)));
    }
}

struct FMars_DripSchedule
{
    // The five sync floats (custom data 0..4) and the drop radius the material uses.
    float Length = 0.0;
    float Rate = 0.8;
    float Seed = 0.0;
    float Jitter = 0.6;
    float Mode = 0.0;
    float DropRadius = 0.45;

    // The clock, filled by Setup (MarsDrip_Clock).
    float Period = 1.0;
    int32 Count = 4;
    float StartDepth = 0.0;
    float FallSeconds = 0.0;
    uint32 Key = 0;
    bool HasImpact = true;

    // Set Length, Rate, Seed, Jitter, Mode (and DropRadius) first. The seed is rounded to the float32 the materials get.
    void Setup()
    {
        Seed = float(float32(Seed));
        HasImpact = Length > 0.0;
        const float L = Math::Abs(Length);
        Key = utils_drip::Hash(uint32(Math::Clamp(Seed, 0.0, 1.0) * 16777216.0));
        if (Mode > 0.5 && Mode < 1.5)
        { StartDepth = Math::Min(14.0 + 30.0 * Math::Frac(Seed * 7.13), 0.5 * L); }
        else
        { StartDepth = 1.6 * DropRadius; }

        FallSeconds = utils_drip::Get_AgeAt(Math::Max(L - StartDepth - DropRadius, 1.0));
        const float Busy = Get_BusySeconds();
        const float P1 = Math::Max(1.0 / Math::Max(Rate, 0.001), Busy / (float(utils_drip::k_Slots) - 2.0 * utils_drip::k_MaxJitter));
        Count = utils_drip::k_Slots * Math::Max(1, Math::FloorToInt(utils_drip::k_Wrap / (P1 * float(utils_drip::k_Slots))));
        Period = utils_drip::k_Wrap / float(Count);
    }

    float Get_BusySeconds() const
    {
        return FallSeconds + utils_drip::k_SplashSeconds;
    }

    float Get_EffectiveRate() const
    {
        return 1.0 / Period;
    }

    // [0, 1) for drop InK; K wraps with the period.
    float Get_Rand(int32 InK, uint32 InSalt) const
    {
        const int32 K = ((InK % Count) + Count) % Count;
        const uint32 Mixed = (uint32(K) * uint32(2654435761)) ^ Key ^ utils_drip::Hash(InSalt);
        return float(utils_drip::Hash(Mixed)) * (1.0 / 4294967296.0);
    }

    float Get_Release(int32 InK) const
    {
        const float J = Math::Clamp(Jitter, 0.0, 1.0);
        return (float(InK) + Seed + J * utils_drip::k_MaxJitter * (2.0 * Get_Rand(InK, 0) - 1.0)) * Period;
    }

    bool Is_Skipped(int32 InK) const
    {
        return Get_Rand(InK, 1) < utils_drip::k_SkipPerJitter * Math::Clamp(Jitter, 0.0, 1.0);
    }

    float Get_Impact(int32 InK) const
    {
        return Get_Release(InK) + FallSeconds;
    }

    // The newest drop on slot InSlot released at or before InTime (MarsDrip_SlotDrop).
    int32 Get_SlotDrop(float InTime, int32 InSlot) const
    {
        const int32 Slots = utils_drip::k_Slots;
        const int32 M = Math::FloorToInt(InTime / Period - Seed);
        const int32 K0 = M - ((((M - InSlot) % Slots) + Slots) % Slots);
        if (Get_Release(K0 + Slots) <= InTime)
        { return K0 + Slots; }

        if (Get_Release(K0) <= InTime)
        { return K0; }

        return K0 - Slots;
    }
}
