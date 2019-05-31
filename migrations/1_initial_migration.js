const Oracle = artifacts.require("Oracle");

const linkToken = {
  development: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  test: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  mainnet: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
  ropsten: "0x20fE562d797A42Dcb3399062AE9546cd06f63280",
  rinkeby: "0x01BE23585060835E02B77ef475b0Cc51aA1e0709",
  kovan: "0xa36085F69e2889c224210F603D836748e7dC0088"
};

module.exports = function(deployer) {
  deployer.deploy(Oracle, linkToken[deployer.network]);
};
