// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IStakeable.sol";

contract Stakeable is ERC20, IStakeable {
    using SafeMath for uint256;

    mapping(address => StakingSummary) private stakings;

    uint256 constant YEAR_HOURS = 365 * 24; //1 year in hours
    uint256 constant WITHDRAW_WAIT = 24 * 60 * 60; // 1 day in seconds

    modifier canWithdraw() {
        require(
            block.timestamp >=
                stakings[msg.sender].claimTimestamp + WITHDRAW_WAIT,
            "Stakeable: CAN NOT WITHDRAW YET"
        );
        _;
    }

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    function balanceOf(address account) public view override returns (uint256) {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        uint256 userStake_ = userSummary_.stakeAmount;
        uint256 totalBalance_ = super.balanceOf(account);
        require(totalBalance_ >= userStake_, "Stakeable: MATH ERROR");
        return totalBalance_ - userStake_;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(balanceOf(from) >= amount, "Stakeable: NOT ENOUGH COINS");
        super._beforeTokenTransfer(from, to, amount);
    }

    function stake(uint256 amount) public override {
        require(
            balanceOf(msg.sender) >= amount,
            "Stakeable: User does not have enough coins!"
        );
        // first add rewards for already staked amount
        StakingSummary memory userSummary_ = stakings[msg.sender];
        require(
            block.timestamp >= userSummary_.stakeTimestamp,
            "Stakeable: MATH ERROR"
        );
        // if already staked we calculate reward
        uint256 reward_ = userSummary_.stakeAmount > 0
            ? claimableReward(userSummary_)
            : 0;
        (bool success_, uint256 newStake_) = userSummary_.stakeAmount.tryAdd(
            amount
        );
        require(success_, "Stakeable: MATH ERROR");
        uint256 newReward_ = 0;
        (success_, newReward_) = userSummary_.reward.tryAdd(reward_);
        require(success_, "Stakeable: MATH ERROR");
        stakings[msg.sender].stakeAmount = newStake_;
        stakings[msg.sender].reward = newReward_;
        stakings[msg.sender].stakeTimestamp = block.timestamp;
    }

    function apy(uint256 amount) public view returns (uint256) {
        if (amount <= 100 * 10**decimals()) {
            return 15;
        } else if (amount <= 1000 * 10**decimals()) {
            return 16;
        } else if (amount <= 1500 * 10**decimals()) {
            return 17;
        } else {
            return 18;
        }
    }

    function claim() public override {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        (bool success_, uint256 reward_) = claimableReward(userSummary_).tryAdd(
            userSummary_.reward
        );
        require(success_, "Stakeable: MATH ERROR");
        require(reward_ > 0, "Stakeable: NOTHING TO CLAIM");
        stakings[msg.sender].reward = 0;
        stakings[msg.sender].stakeTimestamp = block.timestamp;
        stakings[msg.sender].claimTimestamp = block.timestamp;
        stakings[msg.sender].rewardAmount = reward_;
    }

    function claimAndWithdraw(uint256 amount) public override {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        require(
            userSummary_.stakeAmount >= amount,
            "Stakeable: USER DID NOT STAKE THIS MUCH COINS"
        );
        claim();
        (bool success_, uint256 newStake_) = userSummary_.stakeAmount.trySub(
            amount
        );
        require(success_, "Stakeable: MATH ERROR");
        stakings[msg.sender].stakeAmount = newStake_;
        stakings[msg.sender].withdrawAmount = amount;
    }

    function withdraw() public override canWithdraw {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        _mint(msg.sender, userSummary_.rewardAmount);
        stakings[msg.sender].rewardAmount = 0;
        if (userSummary_.withdrawAmount > 0) {
            stakings[msg.sender].withdrawAmount = 0;
        }
    }

    function getStakeSummary()
        public
        view
        override
        returns (StakingSummary memory)
    {
        return stakings[msg.sender];
    }

    function claimableReward(StakingSummary memory userSummary_)
        private
        view
        returns (uint256)
    {
        uint256 hoursPassed = (block.timestamp - userSummary_.stakeTimestamp) /
            3600; // time passed in hours
        uint256 apy_ = (userSummary_.stakeAmount / 100) *
            apy(userSummary_.stakeAmount);
        uint256 timeUnit = (hoursPassed * 100000000) / YEAR_HOURS;
        uint256 reward_ = (apy_ * timeUnit) / 100000000;
        return reward_;
    }

    function claimableReward() public view returns (uint256) {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        return claimableReward(userSummary_);
    }
}
