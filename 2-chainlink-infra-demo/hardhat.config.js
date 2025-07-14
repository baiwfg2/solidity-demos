require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy");

require("dotenv").config();
require("./tasks") // 自动找index.js

const { SEPOLIA_RPC_URL, PRIVATE_KEY1 } = process.env;

// https://github.com/smartcontractkit/Web3_tutorial_Chinese/discussions/62
// require("hardhat-deploy-ethers");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  namedAccounts: {
    firstAccount: {
      default: 0
    }
  },
  networks: {
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY1],
      chainId: 11155111,
      blockConfirmations: 6,
      companionNetworks: {
        destChain: "amoy"
      }
    },
    amoy: {
      url: process.env.AMOY_RPC_URL,
      accounts: [PRIVATE_KEY1],
      chainId: 80002,
      blockConfirmations: 6,
      companionNetworks: {
        destChain: "sepolia"
      }
    },
    fuji: {
      url: process.env.FUJI_RPC_URL,
      accounts: [PRIVATE_KEY1],
      chainId: 43113,
      blockConfirmations: 6
    }
  }
};
