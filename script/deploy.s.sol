//SPDX-License-Identifier:MIT

pragma solidity ^0.8.2;

import {Script} from "forge-std/Script.sol";
import {ERCToken} from "../src/ErcToken.sol";
import {StackingContract} from "../src/stackContract.sol";

contract Deploy is Script {
    function run() public returns (ERCToken, StackingContract) {
        vm.startBroadcast(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        ERCToken ercToken = new ERCToken(1000);
        StackingContract stack = new StackingContract(address(ercToken));
        vm.stopBroadcast();

        return (ercToken, stack);
    }
}
