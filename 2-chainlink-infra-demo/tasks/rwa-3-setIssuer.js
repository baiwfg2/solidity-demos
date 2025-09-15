/* Leading to:

Error HH9: Error while loading Hardhat's configuration.

You probably tried to import the "hardhat" module from your config or a file imported from it.
This is not possible, as Hardhat can't be initialized while its config is being defined.
*/
// const { ethers } = require("hardhat");


const { task } = require("hardhat/config");

task("set-issuer", "set issuer for RealEstateToken contract after realEstateToken and Issuer are all deployed")
    .addParam("tokenaddr", "RealEstate token contract address")
    .addParam("issueraddr", "Issuer contract address")
    .setAction(async(taskArgs, hre) => {
    const reTokenAddr = taskArgs.tokenaddr;
    const issuerAddr = taskArgs.issueraddr;

    // const { firstAccount } = await getNamedAccounts();
    const [signer] = await ethers.getSigners(); // better to get signer in this way
    console.log(`signer: ${signer.address}`);
    // If the third argument Signer is not given, it will get Contract in the name of hardhat first account
    // error : contract runner does not support calling
    // const realEstatToken = await ethers.getContractAt("RealEstateToken",reTokenAddr, firstAccount);
    const realEstatToken = await ethers.getContractAt("RealEstateToken",reTokenAddr);
    const totalSupply = await realEstatToken.totalSupply();

    const tx1 = await realEstatToken.setIssuer(issuerAddr);
    await tx1.wait(6);
    console.log(`token total supply:${totalSupply}, setIssuer done`);
})

module.exports = {}

