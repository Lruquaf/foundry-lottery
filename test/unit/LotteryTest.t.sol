// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console2, console} from "forge-std/Test.sol";
import {DeployLottery} from "script/DeployLottery.s.sol";
import {Lottery} from "src/Lottery.sol";
import {HelperConfig, NetworkConstants} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../mock/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";

contract LotteryTest is Test, NetworkConstants {
    event LotteryEnter(address indexed player);

    address public PLAYER_1 = makeAddr("player 1");
    uint256 public PLAYER_STARTING_BALANCE = 10 ether;

    Lottery public lottery;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    LinkToken linkToken;

    function setUp() external {
        DeployLottery lotteryDeployer = new DeployLottery();
        (lottery, helperConfig) = lotteryDeployer.deployLottery();
        vm.deal(PLAYER_1, PLAYER_STARTING_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        linkToken = LinkToken(config.linkToken);
    }

    modifier skipFork() {
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }
        _;
    }

    function test__It_initializes_lottery_state_in_open() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function test__It_reverts_if_player_doesnt_pay_enough() public {
        vm.prank(PLAYER_1);
        vm.expectRevert(Lottery.Lottery__SendMoreToEnterLottery.selector);
        lottery.enterLottery();
    }

    function test__It_saves_player_to_lottery_properly() public {
        vm.prank(PLAYER_1);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit LotteryEnter(PLAYER_1);
        lottery.enterLottery{value: entranceFee}();
        assert(lottery.getNumberOfPlayers() == 1);
        assert(lottery.getPlayer(0) == PLAYER_1);
    }

    modifier enterLottery() {
        vm.prank(PLAYER_1);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function test__It_reverts_if_player_tries_to_enter_when_lottery_state_is_calculating()
        public
        enterLottery
    {
        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        vm.prank(PLAYER_1);
        lottery.enterLottery{value: entranceFee}();
    }

    function test__CheckUpkeep_returns_false_if_there_is_no_balance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test__CheckUpkeep_returns_false_if_lottery_state_is_not_open()
        public
        enterLottery
    {
        lottery.performUpkeep("");
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test__PerformUpkeep_runs_only_if_checkUpkeep_is_true()
        public
        enterLottery
    {
        lottery.performUpkeep("");
    }

    function test__PerformUpkeep_reverts_if_checkUpkeep_is_false() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Lottery.LotteryState lotteryState = lottery.getLotteryState();

        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                lotteryState
            )
        );
        lottery.performUpkeep("");
    }

    function test__PerformUpkeep_updates_lottery_state_and_emit_event() public {
        // Arrange
        vm.prank(PLAYER_1);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Lottery.LotteryState lotteryState = lottery.getLotteryState();
        assert(uint256(requestId) > 0);
        assert(uint256(lotteryState) == 1);
    }

    function test__FulfillRandomWords_can_only_be_called_after_performUpkeep(
        uint256 randomRequestId
    ) public enterLottery skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function test__It_picks_a_winner_sends_the_money_resets_everything()
        public
        enterLottery
        skipFork
    {
        address expectedWinner = address(10);

        uint256 additionalEntrances = 10;

        for (uint256 i = 1; i <= additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            lottery.enterLottery{value: entranceFee}();
        }

        uint256 startingTimestamp = lottery.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        address recentWinner = lottery.getRecentWinner();
        console.log("Expected Winner: ", expectedWinner);
        console.log("Recent Winner: ", recentWinner);
        Lottery.LotteryState lotteryState = lottery.getLotteryState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = lottery.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(lotteryState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}
