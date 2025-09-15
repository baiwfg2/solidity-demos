/* Leading to:

Error HH9: Error while loading Hardhat's configuration.

You probably tried to import the "hardhat" module from your config or a file imported from it.
This is not possible, as Hardhat can't be initialized while its config is being defined.
*/
// const { ethers } = require("hardhat");

require('dotenv').config();

const { task } = require("hardhat/config");

task("issue", "call issue through chainlink function")
    .addParam("amount", "token amount minted")
    .addParam("issueraddr", "Issuer contract address")
    .addOptionalParam("cancelpending", "cancel pending request", false, types.boolean)
    .setAction(async(taskArgs, hre) => {
    const amount = taskArgs.amount;
    const issuerAddr = taskArgs.issueraddr;

    // const { firstAccount } = await getNamedAccounts();
    const [signer] = await ethers.getSigners(); // better to get signer in this way
    console.log(`signer: ${signer.address}`);
    // If the third argument Signer is not given, it will get Contract in the name of hardhat first account
    const issuer = await ethers.getContractAt("Issuer", issuerAddr);

    if (taskArgs.cancelpending) {
        console.log("cancel pending request ...");
        const tx2 = await issuer.cancelPendingRequest();
        await tx2.wait(8);
        console.log("cancel pending done");
        return;
    }
    const tx1 = await issuer.issue(signer.address, amount, process.env.CHAINLINK_FUNCTION_SUBID,
        300000, process.env.FUJI_DONID);
    await tx1.wait(8);
    console.log(`issue waited, tx: ${tx1.hash}`)
})

module.exports = {}

/*
npx hardhat issue --amount 20 --issueraddr 0xcE8C2291733071ecA5439A9F57F8285Cebe24b92 --cancelpending true --network fuji

always got error like:

signer: 0xA4a8dcE9F35C75f57dF0449B0543Cd767BeF6305
cancel pending request
cancel pending done
An unexpected error occurred:

ProviderError: execution reverted
    at HttpProvider.request (node_modules\hardhat\src\internal\core\providers\http.ts:116:21)
    at processTicksAndRejections (node:internal/process/task_queues:105:5)
    at HardhatEthersProvider.estimateGas (node_modules\@nomicfoundation\hardhat-ethers\src\internal\hardhat-ethers-provider.ts:246:27)
    at node_modules\@nomicfoundation\hardhat-ethers\src\signers.ts:335:35
    at async Promise.all (index 0)
    at HardhatEthersSigner._sendUncheckedTransaction (node_modules\@nomicfoundation\hardhat-ethers\src\signers.ts:356:7)
    at HardhatEthersSigner.sendTransaction (node_modules\@nomicfoundation\hardhat-ethers\src\signers.ts:181:18)

Even though --cancelpending not given, above error still occurred
*/
