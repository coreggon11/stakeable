const { expect } = require("chai");
const { ethers } = require("hardhat");

const COIN = "000000000000000000"

describe("Steakoin", function () {

  let Steakoin;
  let steakoin;
  let acc0;
  let acc1;

  beforeEach(async function () {
    [acc0, acc1] = await ethers.getSigners()
    Steakoin = await ethers.getContractFactory("Steakoin")
    steakoin = await Steakoin.deploy()
    await steakoin.deployed()
  });

  it("Should mint 2000 coins to deployer", async function () {
    expect(await steakoin.balanceOf(acc0.address)).to.equal("2000" + COIN)
  });

  it("Renounce owner ship by acc1", async function () {
    await expect(steakoin.connect(acc1).renounceOwnership()).to.be.reverted
  });

  // stake enough
  it("Should stake 100 coins", async function () {
    await steakoin.stake("100" + COIN)

    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)
  });

  it("Stake 100 and send 2000", async function () {
    await steakoin.stake("100" + COIN)

    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await expect(steakoin.transfer(acc1.address, "2000" + COIN)).to.be.reverted
  });

  // stake more than i have
  it("Staking more than my balance should fail", async function () {
    await expect(steakoin.stake("2001" + COIN)).to.be.reverted
  });

  // stake again -> should add interest 15%
  it("Staking again should raise my reward", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1800" + COIN)

    summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("200" + COIN)
    expect(summary.reward.toString()).to.equal("15" + COIN)
  });

  // stake 100 -> 115 after 1 year
  it("Should have 15 coins claimable after 1 year", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])
    await ethers.provider.send("evm_mine")

    let claimable = await steakoin.claimableReward()
    expect(claimable.toString()).to.equal("15" + COIN)
  });

  // stake 1000 -> 1160 after 1 year
  it("Should have 160 coins claimable after 1 year", async function () {
    await steakoin.stake("1000" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1000" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("1000" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])
    await ethers.provider.send("evm_mine")

    let claimable = await steakoin.claimableReward()
    expect(claimable.toString()).to.equal("160" + COIN)
  });

  // stake 1500 -> 1755 after 1 year
  it("Should have 255 coins claimable after 1 year", async function () {
    await steakoin.stake("1500" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("500" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("1500" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])
    await ethers.provider.send("evm_mine")

    let claimable = await steakoin.claimableReward()
    expect(claimable.toString()).to.equal("255" + COIN)
  });

  // stake 2000 -> 2360 after 1 year
  it("Should have 360 coins claimable after 1 year", async function () {
    await steakoin.stake("2000" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("0")

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("2000" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])
    await ethers.provider.send("evm_mine")

    let claimable = await steakoin.claimableReward()
    expect(claimable.toString()).to.equal("360" + COIN)
  });

  // claim without staking
  it("Claim without staking should fail", async function () {
    await expect(steakoin.claim()).to.be.reverted
  });

  // claim -> claimable
  it("Should have 15 coins ready to withdraw", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claim()
    summary = await steakoin.getStakeSummary()
    expect(summary.rewardAmount.toString()).to.equal("15" + COIN)
  });

  // stake -> stake -> claim -> 0 reward and claimable
  it("Staking again and claiming should set reward to 0", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1800" + COIN)

    await steakoin.claim()
    summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("200" + COIN)
    expect(summary.reward.toString()).to.equal("0")
    expect(summary.rewardAmount.toString()).to.equal("15" + COIN)
  });

  // claim and withdraw -> claimable and stake
  it("Claim and withdraw 50 should set withdraw to 50 and reward to 15", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claimAndWithdraw("50" + COIN)
    summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("50" + COIN)
    expect(summary.withdrawAmount.toString()).to.equal("50" + COIN)
    expect(summary.rewardAmount.toString()).to.equal("15" + COIN)
  });

  // claim -> withdraw < 1 day
  it("Withdrawing 1 hour after claiming should fail", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claim()
    await ethers.provider.send('evm_increaseTime', [60 * 60]) // + 1 hour
    await expect(steakoin.withdraw()).to.be.reverted
  });

  // claim -> withdraw >= 1 day
  it("Withdrawing 1 day after claiming should put tokens in balance", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claim()
    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24]) // + 1 day
    await steakoin.withdraw()

    expect(await steakoin.balanceOf(acc0.address)).to.equal("1915" + COIN)
  });

  // claim and withdraw -> withdraw < 1 day
  it("Claim and withdraw 1 hour after claiming should fail", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claimAndWithdraw("50" + COIN)
    await ethers.provider.send('evm_increaseTime', [60 * 60]) // + 1 hour
    await expect(steakoin.withdraw()).to.be.reverted
  });

  // claim and withdraw -> withdraw >= 1 day
  it("Claim and withdraw 1 day after claiming should put tokens in balance", async function () {
    await steakoin.stake("100" + COIN)
    expect(await steakoin.balanceOf(acc0.address)).to.equal("1900" + COIN)

    let summary = await steakoin.getStakeSummary()
    expect(summary.stakeAmount.toString()).to.equal("100" + COIN)

    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 365])

    await steakoin.claimAndWithdraw("50" + COIN)
    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24]) // + 1 day
    await steakoin.withdraw()

    expect(await steakoin.balanceOf(acc0.address)).to.equal("1965" + COIN)
  });
});
