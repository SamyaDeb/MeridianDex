// Entries of the pre-USDC 10143 record (abandoned 4 Nov 2026 when its keys were lost; the USDC redeploy has no
// ETH-PERP and no Perpl-funding swap market). Test data only: the readers for `markets[]` and `swapMarkets[]` stay
// covered without the live record carrying dead markets.
export const LEGACY_ETH_MARKET = {
  ClearingHouse: "0xaf250943E173454C2fCD22b4Ba0DF8A0b6E1ccb4",
  OracleAdapter: "0x8DFE2185B14b648B4E5d940F025c47AEDEC170Db",
  OrderBook: "0x77675B68d15A112c9CfC617bCf38aAFA8643BDDe",
  _label: "TESTNET MARKET: keeper-fed oracle (Pyth via Hermes, pushed by the keeper)",
  baseAsset: "0x0000000000000000000000000000000000000000",
  feedSymbol: "ETH/USD",
  keeper: "0x5D4FB8B84839e0e8445154c8C6a5ec3B285146E2",
  lotSizeWad: "1000000000000000",
  oracleKind: "keeper-fed",
  pythFeedId: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace",
  startBlock: 69227046,
  symbol: "ETH-PERP",
  tickSizeWad: "100000000000000000",
};

export const LEGACY_PERPL_SWAP = {
  FundingSwapMarket: "0x4e5A8b88e8F09FDf2DC178B4641a25676d181bde",
  PerplFundingSource: "0xC008aF47fCC651889a1d66f0734da941A55224cC",
  SwapOrderBook: "0x5D4f03B6Afa525ed580C75878A2F51A35c202334",
  _label: "TESTNET SWAP MARKET: settles on Perpl's MON-perp funding (PerplFundingSource)",
  deployed: true,
  fundingSource: "perpl",
  lotSizeWad: "1000000000000000000000",
  maturity: 1794414069,
  perplExchange: "0x1964C32f0bE608E7D29302AFF5E61268E72080cc",
  perplPerpId: 64,
  startBlock: 70443746,
  symbol: "MON-FUNDING-PERPL",
  tickSizeWad: "100000000000000",
};
