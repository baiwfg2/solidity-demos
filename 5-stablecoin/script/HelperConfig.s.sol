// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SOPOLIA_CHAINID = 11155111;
    uint256 public constant ANVIL_CHAINID = 31337;
    uint8 public constant MOCK_DECIMALS = 8;
    int256 public constant MOCK_ETH_PRICE = 4000e8;
    int256 public constant MOCK_BTC_PRICE = 100_000e8;
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, CodeConstants {

    struct NetworkConfig {
        address wethPriceFeed;
        address wbtcPriceFeed;
        address weth;
        address wbtc;
        uint256 deployer;
    }
    // If we only need one config per run, we don't need the mapping, just ust a single NetworkConfig field
    mapping(uint256 chainId => NetworkConfig) private networkCfg;

    constructor() {
        if (block.chainid == ANVIL_CHAINID) {
            // only in anvil can we deploy mock contracts
            networkCfg[ANVIL_CHAINID] = getAnvilConfig();
        } else if (block.chainid == ETH_SOPOLIA_CHAINID) {
            networkCfg[ETH_SOPOLIA_CHAINID] = getSepoliaConfig();
        } else {
            revert("Unsupported network");
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory cfg) {
        cfg = NetworkConfig( {
            // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1&testnetSearch=eth%2Fusd#networks
            wethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            // https://sepolia.etherscan.io/address/0xdd13E55209Fd76AfE204dBda4007C227904f0a81
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            // It doesn't look like wBTC token address ?? Patrick said it's fine if it doesn't work(24:46:52)
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployer: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory cfg) {
        if (networkCfg[ANVIL_CHAINID].wethPriceFeed != address(0)) {
            return networkCfg[ANVIL_CHAINID];
        }
        vm.startBroadcast();
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(MOCK_DECIMALS, MOCK_ETH_PRICE);
        ERC20Mock wethMock = new ERC20Mock();
        MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(MOCK_DECIMALS, MOCK_BTC_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();

        cfg = NetworkConfig({
            wethPriceFeed: address(wethPriceFeed),
            wbtcPriceFeed: address(wbtcPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployer: DEFAULT_ANVIL_PRIVATE_KEY
        });
        networkCfg[ANVIL_CHAINID] = cfg;
    }

     function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        return networkCfg[chainId];
    }
}