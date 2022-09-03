const { expectRevert, time } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { assert } = require("chai");
const Unity = artifacts.require("UnitySwap");
const Router = artifacts.require("IUniswapV2Router02");
const Pair = artifacts.require("IERC20");

contract("UnityTest", (accounts) => {
  before(async () => {
    this.token = await Unity.deployed();
    this.router = await Router.at("0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");

    const currTime = await time.latest();
    const supply = await this.token.totalSupply();

    await this.token.approve(this.router.address, BigInt(supply), {
      from: accounts[0],
    });

    await this.router.addLiquidityETH(
      this.token.address,
      BigInt(supply / 2),
      0,
      0,
      this.router.address,
      currTime + 100,
      { value: 1e17, from: accounts[0] }
    );
  });

  describe("Metadata", () => {
    it("should return the correct name", async () => {
      const name = await this.token.name();
      assert.equal(name, "UnitySwap");
    });

    it("should return the correct sumbol", async () => {
      const symbol = await this.token.symbol();
      assert.equal(symbol, "UNITY");
    });

    it("should return the amount of decimals", async () => {
      const decimals = await this.token.decimals();
      assert.equal(decimals, 9);
    });

    it("should return the fixed total supply", async () => {
      const supply = await this.token.totalSupply();
      assert.equal(supply, 1 * 10 ** 9 * 10 ** 9);
    });
  });
  describe("Standard Functions", () => {
    it("should approve tokens succesfully", async () => {
      await this.token.approve(accounts[1], 1e12);
      let allowance = await this.token.allowance(accounts[0], accounts[1]);
      assert.equal(allowance, 1e12);
    });

    it("should transfer tokens normally without fee", async () => {
      const prevBalance = await this.token.balanceOf(accounts[0]);
      await this.token.transfer(accounts[1], BigInt(1e16));
      assert.equal(
        await this.token.balanceOf(accounts[0]),
        BigInt(prevBalance) - BigInt(1e16)
      );
      assert.equal(await this.token.balanceOf(accounts[1]), BigInt(1e16));
    });

    it("should transfer from another wallet with allowance without fee", async () => {
      await this.token.transferFrom(accounts[0], accounts[2], 1e11, {
        from: accounts[1],
      });
      assert.equal(await this.token.balanceOf(accounts[2]), 1e11);
      assert.equal(
        await this.token.allowance(accounts[0], accounts[1]),
        1e12 - 1e11
      );
    });
  });
  describe("Tax Functions", () => {
    it("should return status of exclusion from fee of a wallet", async () => {
      const status = await this.token.isExcludedFromFee(accounts[0]);
      assert.isOk(status);
    });

    it("should not allow transaction above max Tx amount", async () => {
      await expectRevert(
        this.token.transfer(accounts[2], 2e15, { from: accounts[1] }),
        "Transfer amount exceeds the maxTxAmount."
      );
    });

    it("should transfer tokens with tax", async () => {
      await this.token.transfer(accounts[3], 1e5, { from: accounts[1] });
      assert.equal(await this.token.balanceOf(accounts[3]), 1e5 - 3500); //3.5% fee
    });

    it("should distribute the reflection fee", async () => {
      const prev = await this.token.balanceOf(accounts[1]);
      await this.token.transfer(accounts[3], 1e10, { from: accounts[2] });
      const curr = await this.token.balanceOf(accounts[1]);

      assert.isAbove(Number(curr), Number(prev));
    });

    it("should calculate the total reflection fee distributed", async () => {
      const fee = await this.token.totalFees();
      assert.equal(Number(fee), 125e6 + 1250);
    });

    it("should deliver reflection without transfer", async () => {
      const prev = await this.token.balanceOf(accounts[1]);
      await this.token.deliver(1e10, { from: accounts[2] });
      const curr = await this.token.balanceOf(accounts[1]);

      assert.isAbove(Number(curr), Number(prev));
    });

    it("should give fees to charity and foundation wallet", async () => {
      [charity, foundation] = [
        await this.token._charityWallet(),
        await this.token._foundationWallet(),
      ];
      const prevCharity = Number(await this.token.balanceOf(charity));
      const prevFoundation = Number(await this.token.balanceOf(foundation));

      await this.token.transfer(accounts[3], 1e10, { from: accounts[2] });

      assert.equal(
        Number(await this.token.balanceOf(charity)),
        prevCharity + 25e6
      ); //0.25%
      assert.equal(
        Number(await this.token.balanceOf(foundation)),
        prevFoundation + 100e6
      ); //1%
    });
  });
  describe("Reflection Transfer", () => {
    it("should exclude a wallet from receiving reflections", async () => {
      await this.token.excludeFromReward(accounts[1]);
      const status = await this.token.isExcludedFromReward(accounts[1]);
      assert.isOk(status);
    });

    it("should transfer token from an excluded wallet", async () => {
      const prevBal = Number(await this.token.balanceOf(accounts[1]));
      await this.token.transfer(accounts[4], 1e10, { from: accounts[1] });
      assert.equal(
        Number(await this.token.balanceOf(accounts[1])),
        prevBal - 1e10
      ); //No reflection received
    });

    it("should transfer token to an excluded wallet", async () => {
      const prevBal = Number(await this.token.balanceOf(accounts[1]));
      await this.token.transfer(accounts[1], 1e8, { from: accounts[4] });
      assert.equal(
        Number(await this.token.balanceOf(accounts[1])),
        prevBal + (1e8 - 1e8 * 0.035)
      ); //No reflection
    });

    it("should transfer between two excluded wallets", async () => {
      await this.token.excludeFromReward(accounts[2]);
      const prevBal1 = Number(await this.token.balanceOf(accounts[1]));
      const prevBal2 = Number(await this.token.balanceOf(accounts[2]));
      await this.token.transfer(accounts[2], 1e10, { from: accounts[1] });

      assert.equal(
        Number(await this.token.balanceOf(accounts[1])),
        prevBal1 - 1e10
      );
      assert.equal(
        Number(await this.token.balanceOf(accounts[2])),
        prevBal2 + (1e10 - 1e10 * 0.035)
      );
    });

    it("should calculate reflection with and without deducting fee", async () => {
      const withoutFee = await this.token.reflectionFromToken(1e5, false);
      const withFee = await this.token.reflectionFromToken(1e5, true);

      assert.isAbove(Number(withoutFee), Number(withFee));
    });

    it("should include a wallet to receive refelctions", async () => {
      await this.token.includeInReward(accounts[1]);
      const status = await this.token.isExcludedFromReward(accounts[1]);
      assert.isNotOk(status);
    });
  });

  describe("Token trading", () => {
    it("should buy token from AMM", async () => {
      var path = [await this.router.WETH(), this.token.address];
      const output = await this.router.getAmountsOut(1e12, path);

      const expected = Number(output[1]);
      await this.router.swapExactETHForTokensSupportingFeeOnTransferTokens(
        0,
        path,
        accounts[5],
        (await time.latest()) + 100,
        { from: accounts[5], value: 1e12 }
      );

      assert.isAtMost(
        expected - expected * 0.035,
        Number(await this.token.balanceOf(accounts[5]))
      );
    });

    it("should sell token to AMM", async () => {
      var path = [this.token.address, await this.router.WETH()];
      const output = await this.router.getAmountsOut(1e12, path);

      const expected = Number(output[1]);
      const prevBal = await web3.eth.getBalance(accounts[6]);
      await this.token.approve(this.router.address, 1e14, {
        from: accounts[5],
      });
      await this.router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        1e12,
        0,
        path,
        accounts[6],
        (await time.latest()) + 100,
        { from: accounts[5] }
      );

      assert.isAtMost(
        expected - expected * 0.035,
        Number(await web3.eth.getBalance(accounts[6])) - Number(prevBal)
      );
    });

    it("should trigger auto liquidity addition", async () => {
      await this.token.transfer(this.token.address, BigInt(1e15), {
        from: accounts[0],
      });
      const pair = await Pair.at(await this.token.uniswapV2Pair());
      const lpBalance = Number(await pair.balanceOf(accounts[0]));
      await this.token.transfer(accounts[2], 1e10, { from: accounts[1] });
      assert.isBelow(lpBalance, Number(await pair.balanceOf(accounts[0])));
    });
  });

  describe("Owner Privilage", async () => {
    it("should exclude an address from fee", async () => {
      try {
        await this.token.excludeFromFee(accounts[1]);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should include an address in fee", async () => {
      try {
        await this.token.includeInFee(accounts[1]);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set reflection fee percent", async () => {
      try {
        await this.token.setTaxFeePercent(10);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set liquidity fee percent", async () => {
      try {
        await this.token.setLiquidityFeePercent(10);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set foundation fee percent", async () => {
      try {
        await this.token.setFoundationFeePercent(10);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set charity fee percent", async () => {
      try {
        await this.token.setCharityFeePercent(10);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set amount of token to sell for auto liquidity", async () => {
      try {
        await this.token.setNumTokensSellToAddToLiquidity(1e12);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set foundation and charity wallet", async () => {
      try {
        await this.token.setWallets(accounts[5], accounts[6]);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set maximum transferrable amount", async () => {
      try {
        await this.token.setMaxTxAmount(1e13);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should set new router address", async () => {
      try {
        await this.token.updateRouter(
          "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
        );
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should enable/disable swap and liquify", async () => {
      try {
        await this.token.setSwapAndLiquifyEnabled(false);
      } catch (err) {
        assert.equal(err, null);
      }
    });

    it("should claim any stuck tokens/bnb", async () => {
      try {
        await this.token.claimStuckTokens(
          "0x0000000000000000000000000000000000000000"
        );
        await this.token.claimStuckTokens(
          "0x77c21c770Db1156e271a3516F89380BA53D594FA"
        );
      } catch (err) {
        assert.equal(err, null);
      }
    });
  });
});
