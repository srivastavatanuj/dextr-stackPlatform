//SPDX-License-Identifier:MIT

pragma solidity ^0.8.2;

import "./token.sol";

contract StackingContract {
    struct StackTokenInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 lastRewardCollectTimeStamp;
    }

    address public immutable owner;
    uint256 rewardDuration = 60 * 60;
    uint256 private constant totalSupply = 10000000 * 1e18;
    string private constant name = "Reward Token";
    string private constant symbol = "Rwt";
    mapping(address => uint256) balanceOf;
    ERCToken private ercToken;

    mapping(address => mapping(address => StackTokenInfo)) stackInfo;
    mapping(address => bool) public allowedToken;
    mapping(address => uint256) public rewardInfo;
    mapping(address => uint256) public stackBalance;

    constructor(address _allowedAddress) {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
        ercToken = ERCToken(_allowedAddress);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner is allowed to perform this task"
        );
        _;
    }

    function stack(address _token, uint256 _amount) public {
        require(allowedToken[_token] == true, "token not allowed");
        require(_amount >= 0, "amount should be more than zero");
        require(
            ercToken.balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );
        if (stackInfo[msg.sender][_token].amount != 0) {
            redeemReward(_token);
            stackInfo[msg.sender][_token].amount += _amount;
        } else {
            stackInfo[msg.sender][_token] = StackTokenInfo({
                amount: _amount,
                timestamp: block.timestamp,
                lastRewardCollectTimeStamp: 0
            });
        }

        ercToken.transfer(address(this), _amount);
        stackBalance[_token] += _amount;
    }

    function withdraw(address _token, uint256 _amount) public {
        require(allowedToken[_token] == true, "token not allowed");
        require(
            stackInfo[msg.sender][_token].amount >= _amount,
            "insufficient balance"
        );
        redeemReward(_token);
        payable(msg.sender).transfer(_amount);
        stackBalance[msg.sender] -= _amount;
    }

    function redeemReward(address _token) public {
        StackTokenInfo memory info = stackInfo[msg.sender][_token];
        require(allowedToken[_token] == true, "token not allowed");
        require(info.amount >= 0, "you haven't invested yet");

        uint256 rewardCount = (block.timestamp - info.timestamp) %
            rewardDuration;
        uint256 amountToBePaid = ((info.amount * rewardInfo[_token]) / 100) *
            rewardCount;
        payable(msg.sender).transfer(amountToBePaid);

        info.lastRewardCollectTimeStamp = block.timestamp;
        stackInfo[msg.sender][_token] = info;
    }

    function updateReward(
        address _token,
        uint256 _newRewardPercent
    ) public onlyOwner returns (bool) {
        rewardInfo[_token] = _newRewardPercent;
        return true;
    }

    function manageAllowedToken(
        address _token,
        bool status
    ) public onlyOwner returns (bool) {
        allowedToken[_token] = status;
        return true;
    }

    function updateRewardDuration(
        uint256 _newTimestamp
    ) public onlyOwner returns (bool) {
        rewardDuration = _newTimestamp;
        return true;
    }
}
