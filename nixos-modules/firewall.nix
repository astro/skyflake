{ ... }:
{
  networking.nftables = {
    enable = true;
    flushRuleset = true;
  };
}
