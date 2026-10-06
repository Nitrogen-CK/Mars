// Direct-address input must be dotted-decimal IPv4 with an optional decimal port.
class UMars_AutoTest_LanFlow_DirectAddressValidation : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate LAN addresses", n"Step_ValidateAddresses");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ValidateAddresses(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Flow = Subsystem::GetGameInstanceSubsystem(UMars_LanFlow_Subsystem);
        if (ck::Is_NOT_Valid(Flow))
        {
            Assert_True(false, "the LAN flow GameInstance subsystem exists in the test world");
            return;
        }

        Assert_True(Flow.IsValidDirectAddress("192.168.1.42"), "accept four IPv4 octets");
        Assert_True(Flow.IsValidDirectAddress("192.168.1.42:7777"), "accept IPv4 with a port");
        Assert_True(Flow.IsValidDirectAddress("0.0.0.0"), "accept zero octets as valid syntax");
        Assert_True(Flow.IsValidDirectAddress("255.255.255.255:65535"), "accept maximum octets and port");
        Assert_True(Flow.IsValidDirectAddress("127.0.0.1:1"), "accept minimum port");

        Assert_False(Flow.IsValidDirectAddress(""), "reject an empty address");
        Assert_False(Flow.IsValidDirectAddress("localhost"), "reject a hostname");
        Assert_False(Flow.IsValidDirectAddress("host:abc"), "reject letters and a nonnumeric port");
        Assert_False(Flow.IsValidDirectAddress("999.999.999.999"), "reject octets above 255");
        Assert_False(Flow.IsValidDirectAddress("1.2.3"), "reject fewer than four octets");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4.5"), "reject more than four octets");
        Assert_False(Flow.IsValidDirectAddress("1..2.3"), "reject an empty octet");
        Assert_False(Flow.IsValidDirectAddress("1.2.3."), "reject a trailing dot");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4:"), "reject an empty port");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4:0"), "reject port zero");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4:65536"), "reject a port above 65535");
        Assert_False(Flow.IsValidDirectAddress(" 1.2.3.4"), "reject whitespace");
        Assert_False(Flow.IsValidDirectAddress("/Game/Mars/Maps/Camp_Mars_MAP?listen"), "reject a map path with options");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4:77:88"), "reject a second colon");
        Assert_False(Flow.IsValidDirectAddress("1.2.3.4?listen"), "reject URL options");
    }
}
