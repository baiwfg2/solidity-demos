require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { SEPOLIA_URL, PRIVATE_KEY1 } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia: {
      url: SEPOLIA_URL,
      accounts: [PRIVATE_KEY1],
    },
  },
};
