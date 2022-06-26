const sdk = require("api")("@reservoirprotocol/v1.0#1qqrk1pl4stynuh");
const ethers = require("ethers");
const { BigNumber, Contract, Wallet, providers } = require("ethers");
const userDb = require("./db");
const URL = `https://eth-rinkeby.gateway.pokt.network/v1/lb/${process.env.RPC_GATEWAY}`;
const provider = new providers.JsonRpcProvider(URL);

const wallet = new Wallet(process.env.WALLET_PRIVATE_KEY, provider);

// The Contract interface
const abi = [
  "event ValueChanged(address indexed author, string oldValue, string newValue)",
  "constructor(string value)",
  "function getValue() view returns (string value)",
  "function setValue(string value)",
];

// Connect to the network

// The address from the above deployment example
const contractAddress = "0x2bD9aAa2953F988153c8629926D22A6a5F69b14E";

// We connect to the Contract using a Provider, so we will only
// have read-only access to the Contract
const contract = new ethers.Contract(contractAddress, abi, provider);
const contractWithSigner = contract.connect(wallet);

sdk.auth(process.env.RESEVOIR_KEY);

const executeRunner = async (contractId, bidderOptions) => {
  const response = { success: true };
  try {
    const cheapestNFTs = await sdk.getTokensV4({
      collection: contractId,
      sortBy: "floorAskPrice",
      limit: "1",
      Accept: "*/*",
    });
    const cheapestNFT = cheapestNFTs.tokens[0];
    if (cheapestNFT.floorAskPrice < bidderOptions.maxValue || true) {
      const data = await sdk.getExecuteBuyV2({
        token: cheapestNFT.contract + "%3A" + cheapestNFT.tokenId,
        taker: "0xF296178d553C8Ec21A2fBD2c5dDa8CA9ac905A00",
        onlyQuote: "false",
        referrer: "0x0000000000000000000000000000000000000000",
        referrerFeeBps: "1",
        partial: "false",
        skipBalanceCheck: "false",
        Accept: "*/*",
      });
      console.log("data");
      const order = data.steps[0];
      response.order = order;
      //contractWithSigner.snipe(order.to, order.data, order.value);
    }
  } catch (error) {
    response.error = true;
  }
  return response;
};

module.exports.executeRunner = executeRunner;
