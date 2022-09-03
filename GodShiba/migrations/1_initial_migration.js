const Shiba = artifacts.require("JEWEL");
const Lottery = artifacts.require("LotteryTracker")

module.exports = function (deployer) {
  deployer.deploy(Lottery);
};
