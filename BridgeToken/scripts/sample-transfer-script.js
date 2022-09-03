const BridgeBSC = artifacts.require('BridgeBsc');
const BridgeToken = artifacts.require('BridgeTokenBsc');
const privKey = '';

module.exports = async done => {
  const nonce = 4; //Need to increment this for each new transfer
  const accounts = await web3.eth.getAccounts();
  const bridgeBsc = await BridgeBSC.deployed();
  const token = await BridgeToken.deployed();
  const amount = 10000;
  const message = web3.utils.soliditySha3(
    {t: 'address', v: accounts[0]},
    {t: 'address', v: accounts[0]},
    {t: 'uint256', v: amount},
    {t: 'uint256', v: nonce},
  ).toString('hex');
  const { signature } = web3.eth.accounts.sign(
    message, 
    privKey
  ); 
  await token.approve(bridgeBsc.address,1e10);
  await bridgeBsc.deposit(accounts[0], amount, nonce, signature);
  done();
}
