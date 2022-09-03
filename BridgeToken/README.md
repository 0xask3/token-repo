# BridgeToken

# Usage

** Create .env before all steps**

Step 1 : Use ``` truffle compile ``` to compile all contracts

Step 2 : ``` truffle migrate --network bsctestnet ``` and ``` truffle migrate --network matictestnet ``` for deploying contracts

(You can change some code in migrations, which sends 1000 token to bridge)

Step 3 : ``` truffle run verify [contractName] --network [networkName] ``` for each contracts

Step 4 : Replace contract addresses in bsc-matic-bridge.js with newly deployed contracts address

Step 5 : ``` node scripts\bsc-matic-bridge.js ``` to start the bridge

Step 6 (optional): ``` truffle exec scripts\sample-transfer-script.js --network matictestnet ``` to test the bridge 
