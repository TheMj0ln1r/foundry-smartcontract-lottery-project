//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
//forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


/** 
 * @title Raffle Lottery Contract
 * @author Mj0ln1r
 * @notice This contract is to create a raffle lottery 
 * @dev Implements Chainlink VRFv2

*/

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffelNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffeleState);

    //enums //type declarations
    enum RaffleState{ 
        OPEN, //0
        CALCULATING //1
        }

 
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // duration of lottery in sec
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // different from chain to chain
    bytes32 private immutable i_keyHash;// see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    uint64 private immutable i_subscriptionId; // from subscription account
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players; // datastructure to store players
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState s_raffleState = RaffleState.OPEN;


    /* Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event ReguestedRaffleWinner(uint256 indexed requestid);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit ;
    }

    function enterRaffle() external payable{
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffelNotOpen();
        }
        s_players.push(payable(msg.sender));
        //events -> makes migration esier, and makes front-end indexing esier
        emit EnteredRaffle(msg.sender);

    }

    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's the time to perform an upkeep
     * The following should be true for this to return true:
     * 1. Time interval passed
     * 2. The raffle is in the open state
     * 3. The contract has ETH
     * 4. (implicit) the subscription is funded with LINK
     */

    function checkUpkeep(
        bytes memory /* checkData*/
        ) public view returns (bool upkeepNeeded, bytes memory /* performDara */){
            // check time interval
            bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval ;
            bool isOpen = RaffleState.OPEN == s_raffleState;
            bool hasBalance = address(this).balance > 0;
            bool hasPlayers = s_players.length > 0;
            upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
            return (upkeepNeeded,"0x00");
        }

    //1. Get a random number
    //2. Use random number to pick player
    //3. Be automatically called
    function performUpkeep(bytes calldata /*perofrmData */) external
    { //pickWinner()
        
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(
                address(this).balance, 
                s_players.length, 
                uint256(s_raffleState) // or we can use RaffleState raffleState
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        //https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number#analyzing-the-contract
         uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash, // gaslane
            i_subscriptionId, // ID from subscription manager
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit ReguestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override{
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        //resetting player
        s_players = new address payable[](0);
        emit PickedWinner(winner);
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle__TransferFailed();
        }

    }   


    /* Getter functions */
    function getEntranceFee() view external returns(uint256){
        return i_entranceFee;
    }
    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }
    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
    function getLengthOfPlayers() external view returns(uint256){
        return s_players.length;
    }
    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}