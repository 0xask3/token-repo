const Rebase = require("./build/contracts/Caesar.json");
const Provider = require("@truffle/hdwallet-provider");
require("dotenv").config();
const Web3 = require("web3");
const provider = new Provider(process.env.MNEMONIC, process.env.AVAXTESTNET);
const web3 = new Web3(provider);
const contractAdd = "0xaE85DAC1f559a8cc8d4F9db1571A6c64EfFF8D50";

const contract = new web3.eth.Contract(Rebase.abi, contractAdd);

const rebase = async () => {
  accounts = await web3.eth.getAccounts();
  epoch = Math.floor(Date.now() / 1000);
  circulatingSupply = await contract.methods.getCirculatingSupply().call();
  rewardYield = await contract.methods.rewardYield().call();
  rewardDenom = await contract.methods.rewardYieldDenominator().call();
  supplyDelta = BigInt((circulatingSupply * rewardYield) / rewardDenom);

  const tx_rebase = await contract.methods.rebase(epoch,supplyDelta).send({from: accounts[0]});
  var _rebase = epoch + 1800;
  const tx_set_nextrebase = await contract.methods.setNextRebase(_rebase).send({from: accounts[0]});

  var today = new Date();
  console.log("Status tx_rebase: " + tx_rebase.status);
  console.log("Status tx_set_nextrebase: " + tx_set_nextrebase.status);
  console.log("Epoch: " + epoch);
  console.log("Supply Delta: " + supplyDelta);
  console.log("Time called: " + today);
  console.log("\n");
};

setInterval(rebase, 6000);
