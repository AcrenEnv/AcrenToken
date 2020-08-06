var AcrenToken = artifacts.require("AcrenToken");
const INITIAL_SUPPLY = web3.utils.toWei('1', 'ether');
const RESERVE_RATIO = 500000;
const PLATFORM_ADDRESS = 500000;
const SELL_FEE = 20;

module.exports = async (deployer) => {
  await deployer.deploy(AcrenToken, 'Gyld Token', 'GYL', INITIAL_SUPPLY, RESERVE_RATIO, PLATFORM_ADDRESS, SELL_FEE);
};
