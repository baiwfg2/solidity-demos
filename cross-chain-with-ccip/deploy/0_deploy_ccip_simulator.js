//const { developmentChains } = require("../helper-hardhat-config")
const colors = require("../scripts/utils");

module.exports = async({getNamedAccounts, deployments}) => {

    //if(developmentChains.includes(network.name)) {
        /* If not wrapped with curly brackets, a very strange error will show up:
        TypeError: from.toLowerCase is not a function
            at getFrom (/mnt/web3/solidity-demos/cross-chain-with-ccip/node_modules/hardhat-deploy/src/helpers.ts:1673:34)
            at fetchIfDifferent (/mnt/web3/solidity-demos/cross-chain-with-ccip/node_modules/hardhat-deploy/src/helpers.ts:838:34)
        */
        const { firstAccount } = await getNamedAccounts()
        const { deploy, log } = deployments
        log(colors.blue("deploy the CCIP local simulator"))
        await deploy("CCIPLocalSimulator", {
            contract: "CCIPLocalSimulator",
            from: firstAccount,
            log: true,
            args: []
        })
        log("CCIP local simulator deployed!")
    // } else {
    //     log("not in local, skip CCIP local")
    // }
}

module.exports.tags = ["all", "test"]