// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
// to help with addConsumer contract to get newly deployed contract
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


// doing exactly what the subscription UI is doing to get subscription ID
contract CreateSubscription is Script{
    function createSubscriptionUsingConfig() public returns (uint64){
        HelperConfig helperConfig = new HelperConfig();
        ( ,,address vrfCoordinator,,,,,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator,deployerKey);
    }

    function createSubscription( address vrfCoordinator, uint256 deployerKey ) public returns(uint64){
        console.log("Creating subscription on ChainID: ",block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Sub ID :", subId);
        console.log("Please update subID in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64){
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public{
        HelperConfig helperConfig = new HelperConfig();
        ( ,,address vrfCoordinator,,uint64 subId, ,address link,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        
        fundSubscription(vrfCoordinator,subId,link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator,uint64 subId,address link, uint256 deployerKey) public{
        //run functions that front-end run
        console.log("funding subscription",subId);
        console.log("vrfcoordinator",vrfCoordinator);
        console.log("On chainId,",block.chainid);

        if (block.chainid == 31337){
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId,FUND_AMOUNT);
            vm.stopBroadcast();
        }
        else{
            LinkToken(link).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subId));
        }
    }
    function run() external{
        fundSubscriptionUsingConfig();
    }
}

//5 43

contract AddConsumer is Script{
    function addConsumer(address raffle, address vrfCoordinator,uint64 subId,uint256 deployerKey) public{
        console.log("Adding conusmer contract", raffle);
        console.log("vrfcoordinator", vrfCoordinator);
        console.log("On chainId",block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId,raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public{
        HelperConfig helperConfig = new HelperConfig();
        ( ,,address vrfCoordinator,,uint64 subId, ,address link,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(raffle,vrfCoordinator,subId,deployerKey);
    }
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(raffle);
    }
}