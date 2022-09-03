const TokenMatic = artifacts.require('BridgeTokenMatic');
const TokenBsc = artifacts.require('BridgeTokenBsc');
const BridgeMatic = artifacts.require('BridgeMatic');
const BridgeBsc = artifacts.require('BridgeBsc');

module.exports = async function (deployer, network, accounts) {
  if(network === 'matictestnet') {
    await deployer.deploy(TokenMatic);
    const tokenMatic = await TokenMatic.deployed();
    await deployer.deploy(BridgeMatic, tokenMatic.address);
    const bridge = await BridgeMatic.deployed();
    await tokenMatic.transfer(bridge.address,1e12);
    await tokenMatic.excludeFromFee(bridge.address);
  }
  if(network === 'bsctestnet') {
    await deployer.deploy(TokenBsc);
    const tokenBsc = await TokenBsc.deployed();
    await deployer.deploy(BridgeBsc, tokenBsc.address);
    const bridge = await BridgeBsc.deployed();
    await tokenBsc.transfer(bridge.address,1e12);
    await tokenBsc.excludeFromFee(bridge.address);
  }
};
