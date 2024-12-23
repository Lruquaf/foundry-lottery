// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, NetworkConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 _subId, ) = createSubscription(vrfCoordinator, account);
        return (_subId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console.log("Creating subscription on chain id: ", block.chainid);
        console.log("VRFCoordinator in createSubs function: ", _vrfCoordinator);
        vm.roll(block.number + 2);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        require(subId > 0, "Failed to create subscription");
        vm.stopBroadcast();
        console.log("Your subscription id: ", subId);
        return (subId, _vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, NetworkConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkToken;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subscriptionId,
        address _linkToken,
        address _account
    ) public {
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(_account);
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subscriptionId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(_linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(_linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(_account);
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(
        address _mostRecentDeployed,
        address _vrfCoordinator,
        uint256 _subId,
        address _account
    ) public {
        console.log("Adding consumer contract: ", _mostRecentDeployed);
        console.log("VRF Coordinator: ", _vrfCoordinator);
        console.log("On Chain Id: ", block.chainid);
        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(
            _subId,
            _mostRecentDeployed
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentDeployed);
    }
}
