//const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const Token = artifacts.require("Caesar");
const Router = artifacts.require("IJoeRouter");
const currTime = Number(Math.round(new Date().getTime() / 1000));

module.exports = async function (deployer, network, accounts) {

  const router = "0x2d99abd9008dc933ff5c0cd271b88309593ab921";
  const autoliq = "0xDE76f17adbF21C96aeBbDc103b0cd044D4E178BF"; //partnership
  const treasury = accounts[0];
  const riskFree = "0x976e8ec117ae650139E6eb5c9BA2cC77368D9B52"; //treasury

  await deployer.deploy(Token,router,autoliq,treasury,riskFree);

  let tokenInstance = await Token.deployed();

  // await addLiq(tokenInstance, treasury);

};

const addLiq = async (tokenInstance, account) => {

  const routerInstance = await Router.at(
    "0x2D99ABD9008Dc933ff5c0CD271B88309593aB921"
  );
  
  let supply = await tokenInstance.totalSupply();
  await tokenInstance.approve(routerInstance.address, BigInt(supply), {
    from: account,
  });

  await routerInstance.addLiquidityAVAX(
    tokenInstance.address,
    BigInt(supply / 2),
    0,
    0,
    routerInstance.address,
    currTime + 100,
    { value: 1e17, from: account }
  );

}
