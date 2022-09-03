const fs = require("fs");
require("dotenv").config();
const Rebase = require("./build/contracts/IERC20.json");
const Provider = require("@truffle/hdwallet-provider");
const Web3 = require("web3");
const provider = new Provider(process.env.MNEMONIC, process.env.AVAXMAINNET);
const web3 = new Web3(provider);

const contractAdd = "0x42d047534eef46FD68fAD3d74726Fe51be4eeb8F";
const contract = new web3.eth.Contract(Rebase.abi, contractAdd);
let json = [];

const scrape = () => {
  fs.readFile("data.csv", "utf8", function(err, data) {
    let dataArray = data.split(/\r?\n/);
    let addresses = [];
    dataArray.map((x) => {
      let quoted = x.split(",")[0];
      addresses.push(quoted.replace(/['"]+/g, ""));
    });

    addresses.shift();

    (function myLoop(i) {
      setTimeout(function() {
        if (i != -1){
          fetchBalance(addresses[i-1]);
          i--;
          myLoop(i);
        } else{
          let jsonData = JSON.stringify(json);
          fs.writeFile("output.json", jsonData, function(err) {
            if (err) {
                console.log(err);
            }
            console.log("\n JSON created succesfully");
            process.exit();
        });
        }
      }, 150);
    })(addresses.length);
  });

};

const fetchBalance = async (address) => {
  if (address != "" && address != undefined) {
    const balance = await contract.methods.balanceOf(address).call();
    json.push({ account: address, balance: balance });
    console.log(address, balance);
  }
};

scrape();
