module.exports = {
    skipFiles: ['interfaces/','libraries/'],
    client: require('ganache-cli'),
    providerOptions: {
      host: "localhost",
      port: 8545,
      fork: "wss://speedy-nodes-nyc.moralis.io/70951746a8b53f17ae051748/bsc/testnet/ws"
     }
  };