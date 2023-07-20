// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
//for testing deployment script
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test{

    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;//for testing deployment script

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;


    address public PLAYER = makeAddr("player");
    uint public STARTING_USER_BALANCE = 10 ether;
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
        
        (entranceFee,
        interval,
        vrfCoordinator,
        keyHash,
        subscriptionId,
        callbackGasLimit,
        link,) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);

    }
    function testEmitsEventOnEntrance() public{
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }    
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function testCantEnterWhenRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number +1 );
        raffle.performUpkeep(""); // now raffle should be in calculating state

        vm.expectRevert(Raffle.Raffle__RaffelNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number +1 );
        raffle.performUpkeep(""); // now raffle should be in calculating state

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

    }
    
    function testCheckUpkeepReturnsFalseIfEnoughTimeHastPassed() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee} ();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        // raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee} ();
        vm.warp(block.timestamp +interval +  1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

    }

    function testperformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPLayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,currentBalance,numPLayers,raffleState));
        raffle.performUpkeep("");
    }
    modifier raffleEnteredAndTimePassed(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed{

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1); // 0 = open, 1 = calculating
    }


    modifier skipFork() { // to skip tests during fork test, cause VRFCoordinatorV2Mock is doing different from MOCK
        if (block.chainid != 31337) {
            return;
        }
        _;
    }



    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        // vm.expectRevert("nonexistent request");

        // VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
        //     1,
        //     address(raffle)
        // );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork{
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i< startingIndex + additionalEntrants; i++){
            address player = address(uint160(i));  //makeAddr("player");
            hoax(player,STARTING_USER_BALANCE);

            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants+1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretended to be a chainlink  vrf to get random number and pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
    }

}