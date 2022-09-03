//const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const Token = artifacts.require("MetisMoon");
const Router = artifacts.require("INetswapRouter02");
const currTime = Number(Math.round(new Date().getTime() / 1000));

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Token);

  let tokenInstance = await Token.deployed();

  await addLiq(tokenInstance, accounts[0]);

};

const addLiq = async (tokenInstance, account) => {

  const routerInstance = await Router.at(
    "0x1E876cCe41B7b844FDe09E38Fa1cf00f213bFf56"
  );
  
  let supply = await tokenInstance.totalSupply();
  await tokenInstance.approve(routerInstance.address, BigInt(supply), {
    from: account,
  });

  await routerInstance.addLiquidityETH(
    tokenInstance.address,
    BigInt(supply / 2),
    0,
    0,
    routerInstance.address,
    currTime + 100,
    { value: 1e16, from: account }
  );

}
