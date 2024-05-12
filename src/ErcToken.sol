//SPDX-License-Identifier:MIT

pragma solidity ^0.8.2;

contract ERCToken {
    uint256 private immutable i_totalSupply;
    string public constant name = "Demo Token";
    string public constant symbol = "Demo";
    uint256 public constant decimals = 8;
    address public immutable owner;

    mapping(address user => uint256 amount) private s_balance;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor(uint256 _supply) {
        i_totalSupply = _supply * 1e18;
        s_balance[msg.sender] = i_totalSupply;
        owner = msg.sender;
    }

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(balanceOf(msg.sender) >= _value, "Insufficient balance");
        require(_to != address(0), "address can't be zero");
        s_balance[msg.sender] -= _value;
        s_balance[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        require(balanceOf(_from) >= _value, "Insufficient balance");
        require(_to != address(0), "address can't be zero");
        s_balance[_from] -= _value;
        s_balance[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balance[_owner];
    }

    function totalSupply() public view returns (uint256) {
        return i_totalSupply;
    }
}
