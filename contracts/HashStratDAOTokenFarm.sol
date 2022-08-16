// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
pragma abicoder v2;

import "./StakingPool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


/**
 * A Farm contract to distribute HashStrat DAO tokens among LP token stakers proportionally to the amount and duration of the their stakes.
 * Users are free to add and remove tokens to their stake at any time.
 * Users can also claim their pending HashStrat DAO tokens at any time.
 *
 * The contract implements an efficient O(1) algo to distribute the rewards based on this paper:
 * https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf
 */

contract HashStratDAOTokenFarm is StakingPool  {

    event RewardPaid(address indexed user, uint256 reward);

    struct RewardPeriod {
        uint id;
        uint reward;
        uint from;
        uint to;
        uint lastUpdated; // when the totalStakedWeight was last updated (after last stake was ended)
        uint totalStaked; // T: sum of all active stake deposits
        uint rewardPerTokenStaked; // S: SUM(reward/T) - sum of all rewards distributed divided all active stakes
        uint totalRewardsPaid; 
    }

    struct UserInfo {
        uint userRewardPerTokenStaked;
        uint pendingRewards;
        uint rewardsPaid;
    }

    struct RewardsStats {
        // user stats
        uint claimableRewards;
        uint rewardsPaid;
        // general stats
        uint rewardRate;
        uint totalRewardsPaid;
    }

    // The DAO token give out to LP stakers
    IERC20Metadata immutable public hstToken;

    // Predetermined amout of reward periods
    uint public immutable rewardPeriodsCount = 10;
    RewardPeriod[] public rewardPeriods;

    mapping(address => UserInfo) userInfos;

    uint constant rewardPrecision = 1e9;


   
    constructor(address hstTokenAddress) StakingPool() {
        hstToken = IERC20Metadata(hstTokenAddress);
    }


    //// Public View Functions ////

    function getRewardPeriods() public view returns(RewardPeriod[] memory) {
        return rewardPeriods;
    }


    function hstTokenBalance() public view returns (uint) {
        return hstToken.balanceOf(address(this));
    }


    function getCurrentRewardPeriodId() public view returns (uint) {
        if (rewardPeriodsCount == 0) return 0;
        for (uint i=rewardPeriods.length; i>0; i--) {
            RewardPeriod memory period = rewardPeriods[i-1];
            if (period.from <= block.timestamp && period.to >= block.timestamp) {
                return period.id;
            }
        }
        return 0;
    }


    function getRewardsStats(address account) public view returns (RewardsStats memory) {
        UserInfo memory userInfo = userInfos[msg.sender];

        RewardsStats memory stats = RewardsStats(0, 0, 0, 0);
        // user stats
        stats.claimableRewards = claimableReward(account);
        stats.rewardsPaid = userInfo.rewardsPaid;

        // reward period stats
        uint periodId = getCurrentRewardPeriodId();
        if (periodId > 0) {
            RewardPeriod memory period = rewardPeriods[periodId-1];
            stats.rewardRate = rewardRate(period);
            stats.totalRewardsPaid = period.totalRewardsPaid;
        }

        return stats;
    }

    
    function getStakedLP(address account) public view returns (uint) {
        uint staked = 0;
        for (uint i=0; i<lpTokensArray.length; i++){
            address lpTokenAddress = lpTokensArray[i];
            if (lpTokens[lpTokenAddress]) {
                staked += stakes[account][lpTokenAddress];
            }
        }
        return staked;
    }



    //// Public Functions ////

    function startStake(address lpToken, uint amount) public override {
        uint periodId = getCurrentRewardPeriodId();
        require(periodId > 0, "No active reward period found");
        update();

        super.startStake(lpToken, amount);

        // update total tokens staked
        RewardPeriod storage period = rewardPeriods[periodId-1];
        period.totalStaked += amount;
    }


    function endStake(address lpToken, uint amount) public override {
        update();
        super.endStake(lpToken, amount);

        // update total tokens staked
        uint periodId = getCurrentRewardPeriodId();
        RewardPeriod storage period = rewardPeriods[periodId-1];
        period.totalStaked -= amount;
        
        claim();
    }


    function claimableReward(address account) public view returns (uint) {
        uint periodId = getCurrentRewardPeriodId();
        if (periodId == 0) return 0;

        RewardPeriod memory period = rewardPeriods[periodId-1];
        uint newRewardDistribution = calculateRewardDistribution(period);
        uint reward = calculateReward(account, newRewardDistribution);

        UserInfo memory userInfo = userInfos[account];
        uint pending = userInfo.pendingRewards;

        return pending + reward;
    }

 
    function claimReward() public {
        update();
        claim();
    }


    function addRewardPeriods() public  {

        require(rewardPeriods.length == 0, "Reward periods already set");
        require(hstToken.balanceOf(address(this))  > 0, "Missing DAO tokens");
        require(hstToken.balanceOf(address(this))  == hstToken.totalSupply(), "Should own the whole supply");

        // firt year reward is 500k tokens halving every following year
        uint initialRewardAmount = hstToken.balanceOf(address(this)) / 2;
        
        uint secondsInYear = 365 * 24 * 60 * 60;

        uint rewardAmount = initialRewardAmount;
        uint from = block.timestamp;
        uint to = from + secondsInYear - 1;

        // create all reward periods
        for (uint i=0; i<rewardPeriodsCount; i++) {
            addRewardPeriod(rewardAmount, from, to);
            from = (to + 1);
            to = (from + secondsInYear - 1);
            rewardAmount /= 2;
        }
    }



    //// INTERNAL FUNCTIONS ////

    function claim() internal {
        UserInfo storage userInfo = userInfos[msg.sender];
        uint rewards = userInfo.pendingRewards;
        if (rewards != 0) {
            userInfo.pendingRewards = 0;

            uint periodId = getCurrentRewardPeriodId();
            RewardPeriod storage period = rewardPeriods[periodId-1];
            period.totalRewardsPaid += rewards;

            payReward(msg.sender, rewards);
        }
    }


    function payReward(address account, uint reward) internal {
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.rewardsPaid += reward;
        hstToken.transfer(account, reward);

        emit RewardPaid(account, reward);
    }


    function addRewardPeriod(uint reward, uint from, uint to) internal {
        require(reward > 0, "Invalid reward period amount");
        require(to > from && to > block.timestamp, "Invalid reward period interval");
        require(rewardPeriods.length == 0 || from > rewardPeriods[rewardPeriods.length-1].to, "Invalid period start time");

        rewardPeriods.push(RewardPeriod(rewardPeriods.length+1, reward, from, to, block.timestamp, 0, 0, 0));
    }



    /// Reward calcualtion logic

    function rewardRate(RewardPeriod memory period) internal pure returns (uint) {
        uint duration = period.to - period.from;
        return period.reward / duration;
    }


    function update() internal {
        uint periodId = getCurrentRewardPeriodId();
        require(periodId > 0, "No active reward period found");

        RewardPeriod storage period = rewardPeriods[periodId-1];
        uint rewardDistribuedPerToken = calculateRewardDistribution(period);

        // update pending rewards reward since rewardPerTokenStaked was updated
        uint reward = calculateReward(msg.sender, rewardDistribuedPerToken);
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.pendingRewards += reward;
        userInfo.userRewardPerTokenStaked = rewardDistribuedPerToken;

        require(rewardDistribuedPerToken >= period.rewardPerTokenStaked, "Reward distribution should be monotonic increasing");

        period.rewardPerTokenStaked = rewardDistribuedPerToken;
        period.lastUpdated = block.timestamp;
    }


    function calculateRewardDistribution(RewardPeriod memory period) internal view returns (uint) {

        // calculate total reward to be distributed since period.lastUpdated
        uint rate = rewardRate(period);
        uint deltaTime = block.timestamp - period.lastUpdated;
        uint reward = deltaTime * rate;

        // S = S + r / T
        uint newRewardPerTokenStaked = (period.totalStaked == 0)?  
                                        period.rewardPerTokenStaked :
                                        period.rewardPerTokenStaked + ( rewardPrecision * reward / period.totalStaked ); 

        return newRewardPerTokenStaked;
    }


    function calculateReward(address account, uint rewardDistribution) internal view returns (uint) {
        if (rewardDistribution == 0) return 0;

        uint staked = getStakedLP(account);
        UserInfo memory userInfo = userInfos[account];
        
        uint reward =  (staked * (rewardDistribution - userInfo.userRewardPerTokenStaked)) / rewardPrecision;

        return reward;
    }

}

