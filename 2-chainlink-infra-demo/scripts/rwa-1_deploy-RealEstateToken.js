const { ethers } = require("hardhat");
require('dotenv').config();
const {networkConfig} = require("../helper-hardhat-config")
const colors = require("./utils");

async function main() {
    const realEstatTokenFac = await ethers.getContractFactory("RealEstateToken");

    const ccipRouterAddr = networkConfig[network.config.chainId].router;
    const linkTokenAddr = networkConfig[network.config.chainId].linkToken;
    const curChainSelector = networkConfig[network.config.chainId].chainSelector;
    const functionRouter = networkConfig[network.config.chainId].functionRouter;

    console.log({ccipRouterAddr, linkTokenAddr, curChainSelector, functionRouter});
    console.log(colors.blue("Deploying realEstatToken contract ..."))
    const realEstatToken = await realEstatTokenFac.deploy("",
        ccipRouterAddr, linkTokenAddr, curChainSelector, functionRouter);
    await realEstatToken.waitForDeployment();
    let owner = await realEstatToken.owner();
    console.log(`realEstatToken contract deployed at ${realEstatToken.target}, owner:${owner}`);
}

main().then().catch((error) => {
    console.error(error)
    process.exit(1)
})

/*
$ npx hardhat run scripts/deploy-RealEstateToken.js --network fuji
{
  ccipRouterAddr: '0xF694E193200268f9a4868e4Aa017A0118C9a8177',
  linkTokenAddr: '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846',
  curChainSelector: '14767482510784806043',
  functionRouter: '0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0'
}
Deploying realEstatToken contract ...
realEstatToken contract deployed, at 0x9C406980106d46c21b7953Fd3A5279fE62FF80ea, owner:0xA4a8dcE9F35C75f57dF0449B0543Cd767BeF6305

Assertion failed: !(handle->flags & UV_HANDLE_CLOSING), 
file src\win\async.c, line 76
*/