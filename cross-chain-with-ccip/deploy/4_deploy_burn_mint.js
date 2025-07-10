//const { network } = require("hardhat")
const colors = require("../scripts/utils")
//const {developmentChains, networkConfig} = require("../helper-hardhat-config")

module.exports = async({getNamedAccounts, deployments}) => {
    const { firstAccount } = await getNamedAccounts()
    const { deploy, log } = deployments
    
    let router
    let linkTokenAddr
    let wnftAddr
    //if(developmentChains.includes(network.name)) {
        const ccipSimulatorTx = await deployments.get("CCIPLocalSimulator")
        const ccipSimulator = await ethers.getContractAt("CCIPLocalSimulator", ccipSimulatorTx.address)
        const ccipConfig = await ccipSimulator.configuration()
        router = ccipConfig.destinationRouter_
        linkTokenAddr = ccipConfig.linkToken_        
    // } else {
    //     router = networkConfig[network.config.chainId].router
    //     linkTokenAddr = networkConfig[network.config.chainId].linkToken
    // }

    const wnftDeployment = await deployments.get("WrappedNFT")
    wnftAddr = wnftDeployment.address

    log(colors.blue("deploying nftPoolBurnAndMint"))
    log(`get the parameters: ${router}, ${linkTokenAddr}, ${wnftAddr}`)
    await deploy("NFTPoolBurnAndMint", {
        contract: "NFTPoolBurnAndMint",
        from: firstAccount,
        log: true,
        args: [router, linkTokenAddr, wnftAddr]
    })
    log("nftPoolBurnAndMint deployed")
}

module.exports.tags = ["all", "destchain"]