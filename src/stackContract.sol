//SPDX-License-Identifier:MIT

pragma solidity ^0.8.2;

import "./ErcToken.sol";
import "forge-std/console.sol";

contract StackingContract {
    struct StackTokenInfo {
        uint256 amount;
        uint256 lastRewardCollectTimeStamp;
    }

    address public immutable owner;
    uint256 public rewardDuration = 30;
    uint256 private constant totalSupply = 10000000 * 1e18;
    string private constant name = "Reward Token";
    string private constant symbol = "Rwt";
    mapping(address => uint256) public balanceOf;
    ERCToken private ercToken;

    mapping(address => mapping(address => StackTokenInfo)) private stackInfo;
    mapping(address => bool) public allowedToken;
    mapping(address => uint256) public rewardInfo;
    mapping(address => uint256) public tokenBalance;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor(address _allowedAddress) {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
        ercToken = ERCToken(_allowedAddress);
        allowedToken[_allowedAddress] = true;
        rewardInfo[_allowedAddress] = 1;
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
        require(_amount > 0, "amount should be more than zero");

        require(
            ercToken.balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );
        StackTokenInfo memory temp = stackInfo[msg.sender][_token];
        if (temp.amount != 0) {
            if (
                temp.lastRewardCollectTimeStamp + block.timestamp >=
                rewardDuration
            ) {
                redeemReward(_token);
            }
            stackInfo[msg.sender][_token].amount += _amount;
        } else {
            stackInfo[msg.sender][_token] = StackTokenInfo({
                amount: _amount,
                lastRewardCollectTimeStamp: block.timestamp
            });
        }

        ercToken.transferFrom(msg.sender, address(this), _amount);
        tokenBalance[_token] += _amount;
    }

    function withdraw(address _token, uint256 _amount) public {
        StackTokenInfo memory temp = stackInfo[msg.sender][_token];
        require(allowedToken[_token] == true, "token not allowed");
        require(temp.amount >= _amount, "insufficient balance");
        if (
            temp.lastRewardCollectTimeStamp + block.timestamp >= rewardDuration
        ) {
            redeemReward(_token);
        }

        ercToken.transferFrom(address(this), msg.sender, _amount);
        stackInfo[msg.sender][_token].amount -= _amount;
        tokenBalance[_token] -= _amount;
    }

    function redeemReward(address _token) public {
        StackTokenInfo memory info = stackInfo[msg.sender][_token];
        require(allowedToken[_token] == true, "token not allowed");
        require(info.amount >= 0, "you haven't invested yet");

        uint256 rewardCount = (block.timestamp -
            info.lastRewardCollectTimeStamp) / rewardDuration;
        uint256 amountToBePaid = ((info.amount * rewardInfo[_token]) / 100) *
            rewardCount;

        transferfrom(owner, msg.sender, amountToBePaid);

        info.lastRewardCollectTimeStamp = block.timestamp;
        stackInfo[msg.sender][_token] = info;
    }

    function transferfrom(address _from, address _to, uint256 _amount) private {
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
        emit Transfer(_from, _to, _amount);
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

    function getStackInfo(
        address user,
        address token
    ) public view returns (StackTokenInfo memory) {
        return stackInfo[user][token];
    }
}
