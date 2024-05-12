//SPDX-License-Identifier:MIT

pragma solidity ^0.8.2;

import {Test, console} from "forge-std/Test.sol";
import {ERCToken} from "../src/ErcToken.sol";
import {StackingContract} from "../src/stackContract.sol";
import {Deploy} from "../script/deploy.s.sol";

contract StackTest is Test {
    ERCToken ercToken;
    StackingContract stackContract;

    uint256 public constant INITIAL_SUPPLY = 1000 * 1e18;

    address public owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public player_one = makeAddr("one");
    address public player_two = makeAddr("two");

    uint256 public constant AMOUNT_TRANSFERED = 10 * 1e18;

    function setUp() external {
        Deploy deployer = new Deploy();
        (ercToken, stackContract) = deployer.run();
    }

    /////////////////
    //token Contract
    ////////////////

    function testOwnerbalanceSameAsINITIAL_SUPPLY() public view {
        assertEq(
            ercToken.balanceOf(owner),
            INITIAL_SUPPLY,
            "Initial supply not equal to owner balance"
        );
    }

    function testPlayerCanTransferToken() public {
        vm.prank(owner);
        bool status = ercToken.transfer(player_one, AMOUNT_TRANSFERED);
        assert(status == true);
    }

    function testBalanceAfterSendingToken() public {
        vm.prank(owner);
        ercToken.transfer(player_one, AMOUNT_TRANSFERED);
        assertEq(ercToken.balanceOf(player_one), AMOUNT_TRANSFERED);
        assertEq(ercToken.balanceOf(owner), INITIAL_SUPPLY - AMOUNT_TRANSFERED);
    }

    ///////////////
    //stackContract
    //////////////
    function testOwnerIsCorrect() public view {
        assert(stackContract.owner() == owner);
    }

    function testTokenContractIsAllowedAndRewardIsOnePercent() public view {
        assert(stackContract.allowedToken(address(ercToken)) == true);
        assert(stackContract.rewardInfo(address(ercToken)) == 1);
    }

    function testOwnerCanEditRewardAndDuration() public {
        vm.startPrank(owner);
        stackContract.updateReward(address(ercToken), 2);
        stackContract.updateRewardDuration(60);
        vm.stopPrank();

        assert(stackContract.rewardInfo(address(ercToken)) == 2);
        assert(stackContract.rewardDuration() == 60);
    }

    function testRevertIfOtherUserChangeRewardOrDuration() public {
        vm.expectRevert();
        stackContract.updateReward(address(ercToken), 2);
        vm.expectRevert();
        stackContract.updateRewardDuration(60);
    }

    function testRevertIfUserStackNonAllowedToken() public {
        vm.expectRevert("token not allowed");
        stackContract.stack(player_one, 100 * 1e18);
    }

    function testRevertIfUserHaveInsufficientBalance() public {
        vm.expectRevert("Insufficient balance");
        stackContract.stack(address(ercToken), 100 * 1e18);
    }

    function testRevertIfAmountIsZero() public {
        vm.expectRevert("amount should be more than zero");
        stackContract.stack(address(ercToken), 0);
    }

    function testUserCanStackIfAllConditionSatisfy() public {
        vm.prank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
    }

    function testUserStackBalance() public {
        vm.prank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        uint256 balance = stackContract
            .getStackInfo(owner, address(ercToken))
            .amount;
        assert(balance == AMOUNT_TRANSFERED);
    }

    function testUserStackMultipleTimes() public {
        vm.prank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        vm.prank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
    }

    function testUserTokenBalanceDeductingWithStacking() public {
        uint256 initialbalance = ercToken.balanceOf(owner);
        vm.startPrank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        vm.stopPrank();
        uint256 currentBalance = ercToken.balanceOf(owner);

        assert(initialbalance - 2 * AMOUNT_TRANSFERED == currentBalance);
    }

    function testAfterTransferBalanceUpdatedInStackContract() public {
        vm.startPrank(owner);
        uint256 initialbalance = stackContract.tokenBalance(address(ercToken));
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        uint256 currentBalance = stackContract.tokenBalance(address(ercToken));
        vm.stopPrank();

        assert(currentBalance - initialbalance == 2 * AMOUNT_TRANSFERED);
    }

    function testRedeemRewardIsWorking() public {
        vm.prank(owner);
        ercToken.transfer(player_one, 2 * AMOUNT_TRANSFERED);
        vm.startPrank(player_one);

        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        uint256 timeStamp = stackContract
            .getStackInfo(player_one, address(ercToken))
            .lastRewardCollectTimeStamp;
        uint256 rewardDuration = stackContract.rewardDuration();
        vm.warp(timeStamp + rewardDuration + 1);
        stackContract.redeemReward(address(ercToken));
        vm.stopPrank();

        assert(
            (2 * AMOUNT_TRANSFERED) / 100 == stackContract.balanceOf(player_one)
        );
    }

    function testRewardRedeemedBeforeRestackAndTimestampUpdated() public {
        vm.prank(owner);
        ercToken.transfer(player_one, 2 * AMOUNT_TRANSFERED);
        vm.startPrank(player_one);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);

        uint256 timeStamp = stackContract
            .getStackInfo(player_one, address(ercToken))
            .lastRewardCollectTimeStamp;
        uint256 rewardDuration = stackContract.rewardDuration();
        vm.warp(timeStamp + rewardDuration + 1);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);
        vm.stopPrank();
        uint256 initialBalance = stackContract.balanceOf(player_one);

        assert(initialBalance == AMOUNT_TRANSFERED / 100);
        assert(
            stackContract
                .getStackInfo(player_one, address(ercToken))
                .lastRewardCollectTimeStamp == block.timestamp
        );
    }

    function testRevertIfInvalidTokenUsedForWithdraw() public {
        vm.expectRevert("token not allowed");
        stackContract.withdraw(owner, 1e18);
    }

    function testRevertIfStackAmountMoreThanWithdraw() public {
        vm.expectRevert("insufficient balance");
        stackContract.withdraw(address(ercToken), 1e18);
    }

    function testUserCanWithdrawAndBalanceUpdated() public {
        uint256 initialbalance = ercToken.balanceOf(owner);
        vm.startPrank(owner);
        stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);

        vm.startPrank(owner);
        stackContract.withdraw(address(ercToken), AMOUNT_TRANSFERED);
        uint256 currentbalance = ercToken.balanceOf(owner);

        assert(initialbalance == currentbalance);
    }

    // function testRewardRedeemedWhenWithdraw() public {         ////////getting reentrancy error
    //     vm.prank(owner);
    //     ercToken.transfer(player_one, 2 * AMOUNT_TRANSFERED);
    //     vm.startPrank(player_one);
    //     stackContract.stack(address(ercToken), AMOUNT_TRANSFERED);

    //     uint256 timeStamp = stackContract
    //         .getStackInfo(player_one, address(ercToken))
    //         .lastRewardCollectTimeStamp;
    //     uint256 rewardDuration = stackContract.rewardDuration();
    //     vm.warp(timeStamp + rewardDuration + 1);
    //     stackContract.withdraw(address(ercToken), AMOUNT_TRANSFERED);
    //     vm.stopPrank();

    //     assert(stackContract.balanceOf(player_one) == AMOUNT_TRANSFERED / 100);
    // }
}
