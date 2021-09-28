// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

interface IStakeable {
    struct StakingSummary {
        uint256 stakeAmount; // how much is staked
        uint256 reward; // how much reward has been accumulated since stake begin
        uint256 stakeTimestamp; // when staked
        uint256 claimTimestamp; // when claimed
        uint256 withdrawAmount; // how much of staked coins will be withdrawn
        uint256 rewardAmount; // how much of rewards will be withdrawn
    }

    struct ClaimSummary {
        uint256 claimTimestamp; // when claimed
        uint256 withdrawAmount; // how much of staked coins will be withdrawn
        uint256 rewardAmount; // how much of rewards will be withdrawn
    }

    function stake(uint256 amount) external;

    function claim() external;

    function claimAndWithdraw(uint256 amount) external;

    function withdraw() external;

    function getStakeSummary() external view returns (StakingSummary memory);
}
