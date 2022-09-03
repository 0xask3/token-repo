const Rebase = require("./build/contracts/Titano.json");
const Provider = require("@truffle/hdwallet-provider");
const axios = require("axios");
require("dotenv").config();
const Web3 = require("web3");
const provider = new Provider(process.env.MNEMONIC, process.env.POLYGON);
const web3 = new Web3(provider);
const contractAdd = "0x85F11A4Eacea16705975Cffb943E6A38ca2FAeFb"; //Update here

const contract = new web3.eth.Contract(Rebase.abi, contractAdd);

const rebase = async () => {
  try {
    const gas = await axios.get("https://gasstation-mainnet.matic.network/v2");
    accounts = await web3.eth.getAccounts();
    const tx = await contract.methods
      .manualRebase()
      .send({
        from: accounts[0],
        maxPriorityFeePerGas: (gas.data.fast.maxPriorityFee * 10**9).toFixed(0)
      });

    var today = new Date();
    console.log("Status: " + tx.status);
    console.log("Time called: " + today);
    console.log("Gas used : " + (gas.data.fast.maxPriorityFee) + "gwei");
  } catch (e) {
    console.error(e);
  }
};

setInterval(rebase, 130000); // 2 minute + 10 sec
