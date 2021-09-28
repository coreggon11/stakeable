// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IStakeable.sol";

contract Stakeable is ERC20, IStakeable {
    using SafeMath for uint256;

    mapping(address => StakingSummary) private stakings;
    mapping(address => ClaimSummary[]) private claims;

    uint256 constant YEAR_HOURS = 365 * 24; //1 year in hours
    uint256 constant WITHDRAW_WAIT = 24 * 60 * 60; // 1 day in seconds

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    function balanceOf(address account) public view override returns (uint256) {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        uint256 userStake_ = userSummary_.stakeAmount;
        uint256 totalBalance_ = super.balanceOf(account);
        require(totalBalance_ >= userStake_, "Stakeable: MATH ERROR");
        bool success_ = true;
        (success_, totalBalance_) = totalBalance_.trySub(userStake_);
        if (success_) {
            (success_, totalBalance_) = totalBalance_.trySub(
                userSummary_.withdrawAmount
            );
        }
        if (success_) {
            ClaimSummary[] memory claim_ = claims[msg.sender];
            for (uint256 i = 0; i < claim_.length; ++i) {
                (success_, totalBalance_) = totalBalance_.trySub(
                    claim_[i].withdrawAmount
                );
                if (!success_) {
                    break;
                }
            }
        }
        require(success_, "Stakeable: MATH ERROR");
        return totalBalance_;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0x0)) {
            require(balanceOf(from) >= amount, "Stakeable: NOT ENOUGH COINS");
        }
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
        if (userSummary_.rewardAmount > 0 || userSummary_.withdrawAmount > 0) {
            claims[msg.sender].push(
                ClaimSummary(
                    userSummary_.claimTimestamp,
                    userSummary_.withdrawAmount,
                    userSummary_.rewardAmount
                )
            );
        }
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

    function withdraw() public override {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        uint256 totalClaim_ = 0;
        uint256 totalWithdraw_ = 0;
        bool success_ = true;
        if (block.timestamp >= userSummary_.claimTimestamp + WITHDRAW_WAIT) {
            (success_, totalClaim_) = totalClaim_.tryAdd(
                userSummary_.rewardAmount
            );
            require(success_, "Stakeable: MATH ERROR");
            (success_, totalWithdraw_) = totalWithdraw_.tryAdd(
                userSummary_.withdrawAmount
            );
            require(success_, "Stakeable: MATH ERROR");
            stakings[msg.sender].rewardAmount = 0;
            stakings[msg.sender].withdrawAmount = 0;
        }
        ClaimSummary[] memory claimSummary_ = claims[msg.sender];
        uint256 deleted = 0;
        for (uint256 i = 0; i < claimSummary_.length; ++i) {
            if (
                block.timestamp >=
                claimSummary_[i].claimTimestamp + WITHDRAW_WAIT
            ) {
                (success_, totalClaim_) = totalClaim_.tryAdd(
                    claimSummary_[i].rewardAmount
                );
                require(success_, "Stakeable: MATH ERROR");
                (success_, totalWithdraw_) = totalClaim_.tryAdd(
                    claimSummary_[i].withdrawAmount
                );
                require(success_, "Stakeable: MATH ERROR");
                ++deleted;
            } else {
                break;
            }
        }
        require(
            totalClaim_ > 0 || totalWithdraw_ > 0,
            "Stakeable: NOTHING TO WITHDRAW"
        );
        if (deleted == claimSummary_.length) {
            delete claims[msg.sender];
        } else {
            for (uint256 i = 0; i < deleted; ++i) {
                delete claims[msg.sender][i];
            }
            for (uint256 i = deleted; i < claimSummary_.length; ++i) {
                claims[msg.sender][i - deleted] = claimSummary_[i];
            }
            for (uint256 i = 0; i < deleted; ++i) {
                claims[msg.sender].pop();
            }
        }
        _mint(msg.sender, totalClaim_);
        if (
            userSummary_.stakeAmount == 0 &&
            userSummary_.reward == 0 &&
            userSummary_.withdrawAmount == 0 &&
            userSummary_.rewardAmount == 0
        ) {
            delete stakings[msg.sender];
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
        returns (uint256 reward_)
    {
        uint256 hoursPassed = (block.timestamp - userSummary_.stakeTimestamp) /
            3600; // time passed in hours
        // how much I get for 1 year
        uint256 percent_ = apy(userSummary_.stakeAmount);
        (bool success_, uint256 full_) = userSummary_.stakeAmount.tryMul(100);
        require(success_, "Stakeable: MATH ERROR");
        uint256 helper_ = 0;
        (success_, helper_) = userSummary_.stakeAmount.tryMul((100 - percent_));
        require(success_, "Stakeable: MATH ERROR");
        (success_, helper_) = full_.trySub(helper_);
        require(success_, "Stakeable: MATH ERROR");
        uint256 yearApy_ = helper_ / 100;
        // how much I get for 1 hour
        (success_, full_) = yearApy_.tryMul(YEAR_HOURS);
        require(success_, "Stakeable: MATH ERROR");
        (success_, helper_) = yearApy_.tryMul(YEAR_HOURS - 1);
        require(success_, "Stakeable: MATH ERROR");
        uint256 hourApy_ = 0;
        (success_, hourApy_) = full_.trySub(helper_);
        require(success_, "Stakeable: MATH ERROR");
        (success_, reward_) = hoursPassed.tryMul(hourApy_);
        require(success_, "Stakeable: MATH ERROR");
        reward_ = reward_ / YEAR_HOURS;
    }

    function claimableReward() public view returns (uint256) {
        StakingSummary memory userSummary_ = stakings[msg.sender];
        return claimableReward(userSummary_);
    }
}
