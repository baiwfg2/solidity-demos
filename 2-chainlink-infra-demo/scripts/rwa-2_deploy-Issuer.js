
const { ethers } = require("hardhat");
require('dotenv').config();
const {networkConfig} = require("../helper-hardhat-config")
const colors = require("./utils");

async function main() {
    const issuerFac = await ethers.getContractFactory("Issuer");
    const functionRouter = networkConfig[network.config.chainId].functionRouter;

    console.log(colors.blue("Deploying Issuer contract ..."))
    const realEstateAddr = "0x9C406980106d46c21b7953Fd3A5279fE62FF80ea";
    const issuer = await issuerFac.deploy(realEstateAddr, functionRouter);
    await issuer.waitForDeployment();
    console.log(`Issuer contract deployed at ${issuer.target}`);
}

main().then().catch((error) => {
    console.error(error)
    process.exit(1)
})

/*
Deploying Issuer contract ...
Issuer contract deployed at  0xcE8C2291733071ecA5439A9F57F8285Cebe24b92
Assertion failed: !(handle->flags & UV_HANDLE_CLOSING), file src\win\async.c, line 76
*/