// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

abstract contract NetworkConstants {
    // VRF Mock Constants
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, NetworkConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 interval;
        uint256 entranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address linkToken;
        // uint256 deployerKey;
        address account;
    }

    NetworkConfig public anvilConfig;
    mapping(uint256 chainId => NetworkConfig config) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 84336802301525136648859092671685784965615578276113286950064373844978618658751,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                // deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
                account: 0xc55FAfFc48A8E35eDB53EEA3d91Ec2dCc7fD3100
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (anvilConfig.vrfCoordinator != address(0)) {
            return anvilConfig;
        } else {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
                    MOCK_BASE_FEE,
                    MOCK_GAS_PRICE,
                    MOCK_WEI_PER_UNIT_LINK
                );
            // uint256 subscriptionId = vrfCoordinatorMock
            //     .createSubscription();
            LinkToken linkToken = new LinkToken();
            vm.stopBroadcast();

            anvilConfig = NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 0,
                linkToken: address(linkToken),
                // deployerKey: ANVIL_DEFAULT_KEY
                account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
            });
            return anvilConfig;
        }
    }
}
