const Web3 = require('web3');
const BridgeMatic = require('../build/contracts/BridgeMatic.json');
const BridgeBsc = require('../build/contracts/BridgeBsc.json');

const web3Matic = new Web3('wss://speedy-nodes-nyc.moralis.io/70951746a8b53f17ae051748/polygon/mumbai/ws');
const web3Bsc = new Web3('wss://speedy-nodes-nyc.moralis.io/70951746a8b53f17ae051748/bsc/testnet/ws');
const adminPrivKey = '';
const { address: admin } = web3Bsc.eth.accounts.wallet.add(adminPrivKey);


let optionsBsc = {
  filter: {
      value: [],
  },
  fromBlock: 15927099
};

let optionsMatic = {
  filter: {
      value: [],
  },
  fromBlock: 23960787
};

const bridgeMatic = new web3Matic.eth.Contract(
  BridgeMatic.abi,
  '0x206c0407b6419a21dc598A92dDf939852F5C9FFB'
);

const bridgeBsc = new web3Bsc.eth.Contract(
  BridgeBsc.abi,
  '0x2F6B81Ed034f77F5f03c5cDfab772ca6C0cAfc8d'
);

console.log("Listening for events...");

bridgeMatic.events.Transfer(
  optionsMatic
)
.on('data', async event => {

  const { from, to, amount, date, nonce, signature } = event.returnValues;
  console.log("Incoming transaction on matic bridge from " + from + "nonce: " + nonce);


  const tx = bridgeBsc.methods.process(from, to, amount, nonce, signature);
  const [gasPrice, gasCost] = await Promise.all([
    web3Bsc.eth.getGasPrice(),
    tx.estimateGas({from: admin}),
  ]);
  const data = tx.encodeABI();
  const txData = {
    from: admin,
    to: bridgeBsc.options.address,
    data,
    gas: gasCost,
    gasPrice
  };
  const receipt = await web3Bsc.eth.sendTransaction(txData);
  console.log(`Transaction hash: ${receipt.transactionHash}`);
  console.log(`
    Processed transfer:
    - BSC TO MATIC
    - from ${from} 
    - to ${to} 
    - amount ${amount} tokens
    - date ${date}
    - nonce ${nonce}
  `);
});

bridgeBsc.events.Transfer(
  optionsBsc
)
.on('data', async event => {
  const { from, to, amount, date, nonce, signature } = event.returnValues;

  const tx = bridgeMatic.methods.process(from, to, amount, nonce, signature);
  const [gasPrice, gasCost] = await Promise.all([
    web3Bsc.eth.getGasPrice(),
    tx.estimateGas({from: admin}),
  ]);
  const data = tx.encodeABI();
  const txData = {
    from: admin,
    to: bridgeMatic.options.address,
    data,
    gas: gasCost,
    gasPrice
  };
  const receipt = await web3Matic.eth.sendTransaction(txData);
  console.log(`Transaction hash: ${receipt.transactionHash}`);
  console.log(`
    Processed transfer:
    - MATIC TO BSC
    - from ${from} 
    - to ${to} 
    - amount ${amount} tokens
    - date ${date}
    - nonce ${nonce}
  `);
});

